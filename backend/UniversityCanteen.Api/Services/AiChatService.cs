using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Extensions.Options;
using MySqlConnector;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Services;

public sealed class AiChatService(
    IDbConnectionFactory dbConnectionFactory,
    IHttpClientFactory httpClientFactory,
    IOptions<AiOptions> aiOptions,
    ILogger<AiChatService> logger) : IAiChatService
{
    private const string FallbackMessage =
        "Sorry, I could not understand your request. Please try asking about food, orders, wallet, support, or your account.";

    private readonly AiOptions _opts = aiOptions.Value;

    public async Task<ChatReplyResult> SendMessageAsync(
        string sessionId,
        string userMessage,
        int? userId,
        string? userName,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(sessionId) || sessionId.Length > 100)
            return new ChatReplyResult(false, string.Empty, sessionId, DateTime.UtcNow, "Invalid session ID.");

        var trimmedMessage = (userMessage ?? string.Empty).Trim();
        if (trimmedMessage.Length == 0 || trimmedMessage.Length > 1000)
            return new ChatReplyResult(false, string.Empty, sessionId, DateTime.UtcNow, "Message must be 1-1000 characters.");

        var fastReply = TryBuildFastLocalReply(trimmedMessage, userName);
        if (fastReply is not null)
        {
            return fastReply with
            {
                SessionId = sessionId,
                Timestamp = DateTime.UtcNow
            };
        }

        try
        {
            using var connection = dbConnectionFactory.CreateConnection();

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO chatbot_conversations (id, user_id, created_at, updated_at)
                VALUES (@id, @userId, UTC_TIMESTAMP(), UTC_TIMESTAMP())
                ON DUPLICATE KEY UPDATE
                    user_id = COALESCE(@userId, user_id),
                    updated_at = UTC_TIMESTAMP();
                """,
                new { id = sessionId, userId = userId > 0 ? userId : null },
                cancellationToken: ct));

            await connection.ExecuteAsync(new CommandDefinition(
                """
                INSERT INTO chatbot_messages (conversation_id, role, content, created_at)
                VALUES (@conversationId, 'user', @content, UTC_TIMESTAMP());
                """,
                new { conversationId = sessionId, content = trimmedMessage },
                cancellationToken: ct));

            var history = (await connection.QueryAsync<ChatHistoryRow>(new CommandDefinition(
                """
                SELECT role AS Role, content AS Content
                FROM chatbot_messages
                WHERE conversation_id = @sessionId
                ORDER BY id DESC
                LIMIT 11;
                """,
                new { sessionId },
                cancellationToken: ct))).ToList();
            history.Reverse();

            var menuItems = await GetAvailableMenuItemsAsync(connection, ct);
            var canteens = menuItems
                .GroupBy(i => new { i.CanteenId, i.CanteenName, i.CanteenDescription, i.CanteenStatus })
                .Select(g => new CanteenContextRow
                {
                    CanteenId = g.Key.CanteenId,
                    CanteenName = g.Key.CanteenName,
                    CanteenDescription = g.Key.CanteenDescription,
                    CanteenStatus = g.Key.CanteenStatus
                })
                .ToList();

            var localReply = await TryBuildLocalReplyAsync(connection, trimmedMessage, userId, menuItems, canteens, ct);
            if (localReply is not null)
            {
                await SaveAssistantMessageAsync(connection, sessionId, localReply.Response, ct);
                return localReply with { SessionId = sessionId, Timestamp = DateTime.UtcNow };
            }

            string aiResponse;
            var resolvedKey = ResolveApiKey();

            if (!_opts.Enabled || string.IsNullOrWhiteSpace(resolvedKey))
            {
                aiResponse = FallbackMessage;
            }
            else
            {
                var menuContext = BuildMenuContext(menuItems);
                var systemPrompt = $"""
                    You are CampusEatzz Food Assistant - a helpful AI for a university campus food ordering app in India.

                    You help students find food, place orders, understand wallet payments, track orders, and use CampusEatzz.

                    Current available menu:
                    {menuContext}

                    Guidelines:
                    - Keep responses concise (2-4 sentences max unless listing items)
                    - Use Rs. for prices
                    - Mention item name, price, and canteen when recommending
                    - For ordering, tell users to browse the menu or use the canteen section
                    - Be friendly and conversational
                    - Do NOT make up items not listed in the menu above
                    - If the message is not about food, orders, wallet, support, canteen operations, or account help, respond exactly: "{FallbackMessage}"
                    """;

                aiResponse = await CallOpenRouterAsync(systemPrompt, history, ct);
            }

            await SaveAssistantMessageAsync(connection, sessionId, aiResponse, ct);
            return new ChatReplyResult(true, aiResponse, sessionId, DateTime.UtcNow, Intent: "ai_assisted");
        }
        catch (Exception ex) when (IsDatabaseConnectivityFailure(ex))
        {
            logger.LogWarning(ex, "Database unavailable while processing chat message. Returning offline chatbot response.");
            return BuildOfflineReply(trimmedMessage) with
            {
                SessionId = sessionId,
                Timestamp = DateTime.UtcNow
            };
        }
    }

    public async Task<IReadOnlyList<ChatMessageItem>> GetHistoryAsync(
        string sessionId,
        int limit,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(sessionId))
            return [];

        var clampedLimit = Math.Clamp(limit, 1, 100);

        using var connection = dbConnectionFactory.CreateConnection();
        var rows = (await connection.QueryAsync<ChatHistoryRow>(new CommandDefinition(
            """
            SELECT role AS Role, content AS Content, created_at AS CreatedAt
            FROM chatbot_messages
            WHERE conversation_id = @sessionId
            ORDER BY id DESC
            LIMIT @limit;
            """,
            new { sessionId, limit = clampedLimit },
            cancellationToken: ct))).ToList();

        rows.Reverse();
        return rows.Select(r => new ChatMessageItem(r.Role, r.Content, r.CreatedAt)).ToList();
    }

    private async Task<string> CallOpenRouterAsync(
        string systemPrompt,
        IEnumerable<ChatHistoryRow> history,
        CancellationToken ct)
    {
        try
        {
            var client = httpClientFactory.CreateClient("OpenRouter");
            var messages = new List<object>
            {
                new { role = "system", content = systemPrompt }
            };
            messages.AddRange(history.Select(h => new { role = h.Role, content = h.Content }));

            var requestBody = new
            {
                model = _opts.Model,
                max_tokens = _opts.MaxTokens,
                messages
            };

            var json = JsonSerializer.Serialize(requestBody);
            using var content = new StringContent(json, Encoding.UTF8, "application/json");

            using var response = await client.PostAsync("chat/completions", content, ct);
            var responseJson = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("OpenRouter API error {Status}: {Body}", (int)response.StatusCode, responseJson);
                return "I'm having trouble connecting right now. Please try again in a moment.";
            }

            using var doc = JsonDocument.Parse(responseJson);
            var choices = doc.RootElement.GetProperty("choices");
            if (choices.GetArrayLength() > 0)
            {
                return choices[0]
                    .GetProperty("message")
                    .GetProperty("content")
                    .GetString()
                    ?? "I couldn't generate a response. Please try again.";
            }

            return "I couldn't generate a response. Please try again.";
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "OpenRouter API call failed.");
            return "I'm temporarily unavailable. Please try again shortly.";
        }
    }

    private string ResolveApiKey()
    {
        if (!string.IsNullOrWhiteSpace(_opts.ApiKey))
            return _opts.ApiKey;

        return Environment.GetEnvironmentVariable("ApiKey") ?? string.Empty;
    }

    private static ChatReplyResult? TryBuildFastLocalReply(string userMessage, string? userName)
    {
        var intent = DetectIntent(userMessage, Array.Empty<MenuContextRow>(), KnownCanteens);

        if (intent == ChatIntent.Menu)
            return null;
        if (intent == ChatIntent.Profile)
            return null;

        if (intent == ChatIntent.AccountName)
        {
            var displayName = (userName ?? string.Empty).Trim();
            var response = string.IsNullOrWhiteSpace(displayName)
                ? "I could not find your name in the current session. Please make sure you are logged in and try again."
                : $"Your name is {displayName}.";

            return new ChatReplyResult(true, response, string.Empty, DateTime.UtcNow, Intent: "account_name");
        }

        return BuildSystemKnowledgeReply(intent);
    }

    private static ChatReplyResult BuildOfflineReply(string userMessage)
    {
        var intent = DetectIntent(userMessage, Array.Empty<MenuContextRow>(), Array.Empty<CanteenContextRow>());

        if (intent == ChatIntent.Menu)
        {
            return new ChatReplyResult(
                true,
                "I can help with food, but live menu details are temporarily unavailable. Please try again after the connection is restored.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "menu");
        }

        if (intent == ChatIntent.AccountName)
        {
            return new ChatReplyResult(
                true,
                "I cannot fetch your name right now because account data is temporarily unavailable. Please try again after the connection is restored.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "account_name");
        }
        if (intent == ChatIntent.Profile)
        {
            return new ChatReplyResult(
                true,
                "I cannot fetch profile details right now because account data is temporarily unavailable. Please try again after the connection is restored.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "profile");
        }

        var systemAnswer = BuildSystemKnowledgeReply(intent);
        if (systemAnswer is not null)
            return systemAnswer;

        return new ChatReplyResult(true, FallbackMessage, string.Empty, DateTime.UtcNow, Intent: "fallback");
    }

    private static bool IsDatabaseConnectivityFailure(Exception ex)
    {
        for (var current = ex; current is not null; current = current.InnerException)
        {
            if (current is MySqlException or TimeoutException or TaskCanceledException)
                return true;
        }

        return false;
    }

    private static async Task<ChatReplyResult?> TryBuildLocalReplyAsync(
        System.Data.IDbConnection connection,
        string userMessage,
        int? userId,
        IReadOnlyList<MenuContextRow> menuItems,
        IReadOnlyList<CanteenContextRow> canteens,
        CancellationToken ct)
    {
        var intent = DetectIntent(userMessage, menuItems, canteens);

        if (intent == ChatIntent.Menu)
        {
            var canteen = FindMentionedCanteen(userMessage, canteens)
                ?? FindCanteenByMentionedItem(userMessage, menuItems);

            return BuildMenuReply(userMessage, menuItems, canteen);
        }

        if (intent == ChatIntent.AccountName)
        {
            var name = await GetUserDisplayNameAsync(connection, userId, ct);
            var response = string.IsNullOrWhiteSpace(name)
                ? "I could not find your name yet. Please make sure you are logged in and try again."
                : $"Your name is {name}.";

            return new ChatReplyResult(true, response, string.Empty, DateTime.UtcNow, Intent: "account_name");
        }

        if (intent == ChatIntent.Profile)
            return await BuildProfileReplyAsync(connection, userId, ct);

        var systemAnswer = BuildSystemKnowledgeReply(intent);
        if (systemAnswer is not null)
            return systemAnswer;

        return null;
    }

    private static ChatIntent DetectIntent(
        string message,
        IReadOnlyList<MenuContextRow> menuItems,
        IReadOnlyList<CanteenContextRow> canteens)
    {
        var normalized = Normalize(message);

        if (MatchesAny(normalized, ProfileTerms))
            return ChatIntent.Profile;
        if (MatchesAny(normalized, AccountNameTerms))
            return ChatIntent.AccountName;
        if (MatchesAny(normalized, OrderHowToTerms))
            return ChatIntent.PlaceOrderHelp;
        if (MatchesAny(normalized, TrackOrderTerms))
            return ChatIntent.TrackOrderHelp;
        if (MatchesAny(normalized, CancelOrderTerms))
            return ChatIntent.CancelOrderHelp;
        if (MatchesAny(normalized, WalletTerms))
            return ChatIntent.WalletHelp;
        if (MatchesAny(normalized, SupportTerms))
            return ChatIntent.SupportHelp;
        if (MatchesAny(normalized, CanteenPanelTerms))
            return ChatIntent.CanteenPanelHelp;

        if (MatchesAny(normalized, FoodTerms) ||
            menuItems.Any(i => IsFuzzyPhraseMatch(normalized, i.ItemName)) ||
            canteens.Any(c => IsFuzzyPhraseMatch(normalized, c.CanteenName)))
            return ChatIntent.Menu;

        return ChatIntent.Unknown;
    }

    private static ChatReplyResult? BuildSystemKnowledgeReply(ChatIntent intent)
    {
        var response = BuildSystemKnowledgeAnswer(intent);
        return response is null
            ? null
            : new ChatReplyResult(true, response, string.Empty, DateTime.UtcNow, Intent: intent.ToString().ToLowerInvariant());
    }

    private static string? BuildSystemKnowledgeAnswer(ChatIntent intent) => intent switch
    {
        ChatIntent.PlaceOrderHelp =>
            "To place an order:\n1. Open a canteen or menu from the home screen.\n2. Choose your food items and add them to cart.\n3. Review quantity and total in the cart.\n4. Select takeaway or dine-in if available.\n5. Pay with your wallet or available payment option, then confirm the order.",
        ChatIntent.WalletHelp =>
            "Wallet payment is simple:\n1. Recharge your CampusEatzz wallet from the wallet section.\n2. At checkout, choose wallet payment.\n3. The order amount is deducted instantly.\n4. If an eligible order is cancelled or refunded, the amount is credited back to your wallet.",
        ChatIntent.TrackOrderHelp =>
            "To track your order:\n1. Open the Orders section.\n2. Select your latest order.\n3. Check the live status such as placed, accepted, preparing, ready, completed, or cancelled.\n4. You will also receive notifications when the canteen updates the order.",
        ChatIntent.SupportHelp =>
            "For support, use the support/contact option in the app if available, or contact your campus canteen/admin team with your order number, registered email, and issue details. For order issues, include the order reference so the team can help faster.",
        ChatIntent.CanteenPanelHelp =>
            "The canteen panel helps canteen staff manage operations:\n1. View new and active orders.\n2. Accept, prepare, mark ready, complete, or cancel orders.\n3. Manage menu items, prices, availability, and images.\n4. Check reviews, reports, wallet/earnings, and canteen settings.",
        ChatIntent.CancelOrderHelp =>
            "To cancel an order:\n1. Open the Orders section.\n2. Choose the order you want to cancel.\n3. Tap Cancel if the order is still eligible.\n4. Confirm the cancellation. If payment was already made and the order qualifies, the refund is processed to your wallet or payment method.",
        _ => null
    };

    private static ChatReplyResult BuildMenuReply(
        string userMessage,
        IReadOnlyList<MenuContextRow> menuItems,
        CanteenContextRow? canteen)
    {
        var scopedItems = canteen is null
            ? menuItems
            : menuItems.Where(i => i.CanteenId == canteen.CanteenId).ToList();

        if (scopedItems.Count == 0)
        {
            return new ChatReplyResult(
                true,
                "I could not find available items for that request right now.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "menu");
        }

        if (IsCanteenDetailsRequest(userMessage, canteen))
            return BuildCanteenDetailsReply(userMessage, scopedItems, canteen);

        var matchingItems = FilterMenuItems(userMessage, scopedItems);
        var openMenu = IsOpenMenuRequest(userMessage);

        if (matchingItems.Count == 0)
        {
            var cheapest = scopedItems
                .OrderBy(i => i.Price)
                .ThenBy(i => i.ItemName)
                .Take(5)
                .ToList();

            var fallbackItems = string.Join("\n", cheapest.Select((item, index) => $"{index + 1}. {FormatDetailedItem(item)}"));
            var cheapestItem = cheapest[0];

            return new ChatReplyResult(
                true,
                $"I could not find an exact match, but these are close available options:\n{fallbackItems}\nTap Order this to browse the menu.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "menu",
                Action: "show_menu",
                CanteenId: canteen?.CanteenId ?? cheapestItem.CanteenId,
                CanteenName: canteen?.CanteenName ?? cheapestItem.CanteenName);
        }

        var heading = BuildFoodReplyHeading(userMessage, matchingItems.Count);
        var details = string.Join("\n", matchingItems.Take(5).Select((item, index) => $"{index + 1}. {FormatDetailedItem(item)}"));
        var firstItem = matchingItems[0];
        var tail = openMenu
            ? "Tap Order this to open the menu."
            : "Tap Order this if you want to browse and add one to cart.";

        return new ChatReplyResult(
            true,
            $"{heading}\n{details}\n{tail}",
            string.Empty,
            DateTime.UtcNow,
            Intent: "menu",
            Action: "show_menu",
            CanteenId: canteen?.CanteenId ?? firstItem.CanteenId,
            CanteenName: canteen?.CanteenName ?? firstItem.CanteenName);
    }

    private static ChatReplyResult BuildCanteenDetailsReply(
        string userMessage,
        IReadOnlyList<MenuContextRow> menuItems,
        CanteenContextRow? canteen)
    {
        var grouped = menuItems
            .GroupBy(i => new { i.CanteenId, i.CanteenName, i.CanteenDescription, i.CanteenStatus })
            .OrderBy(g => g.Key.CanteenName)
            .ToList();

        if (canteen is not null)
        {
            var items = menuItems
                .OrderBy(i => i.Price)
                .ThenBy(i => i.ItemName)
                .Take(6)
                .ToList();
            var first = items[0];
            var itemSummary = string.Join(", ", items.Select(i => $"{i.ItemName} (Rs. {i.Price:0})"));
            var description = string.IsNullOrWhiteSpace(first.CanteenDescription)
                ? "No description available"
                : first.CanteenDescription;
            var priceRange = $"{items.Min(i => i.Price):0}-{menuItems.Max(i => i.Price):0}";

            return new ChatReplyResult(
                true,
                $"{canteen.CanteenName}: {description}. Status: {first.CanteenStatus}. Available items: {menuItems.Count}. Price range: Rs. {priceRange}. Popular options include {itemSummary}. Tap Order this to open this canteen menu.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "menu",
                Action: "show_menu",
                CanteenId: canteen.CanteenId,
                CanteenName: canteen.CanteenName);
        }

        var canteenSummaries = string.Join("\n", grouped.Select((g, index) =>
        {
            var priceRange = $"{g.Min(i => i.Price):0}-{g.Max(i => i.Price):0}";
            var description = string.IsNullOrWhiteSpace(g.Key.CanteenDescription)
                ? "No description available"
                : g.Key.CanteenDescription;
            return $"{index + 1}. {g.Key.CanteenName}: {description}. Status: {g.Key.CanteenStatus}. {g.Count()} available items, Rs. {priceRange}.";
        }));

        return new ChatReplyResult(
            true,
            $"Here are the canteens I found:\n{canteenSummaries}\nAsk for a canteen by name to see its food options.",
            string.Empty,
            DateTime.UtcNow,
            Intent: "menu");
    }

    private static List<MenuContextRow> FilterMenuItems(
        string userMessage,
        IReadOnlyList<MenuContextRow> scopedItems)
    {
        var normalized = Normalize(userMessage);
        var maxPrice = TryExtractMaxPrice(userMessage);
        IEnumerable<MenuContextRow> query = scopedItems;

        if (maxPrice is not null)
            query = query.Where(i => i.Price <= maxPrice.Value);

        if (MatchesAny(normalized, NonVegetarianTerms))
        {
            query = query.Where(i => !i.IsVegetarian);
        }
        else if (MatchesAny(normalized, VegetarianTerms))
        {
            query = query.Where(i => i.IsVegetarian);
        }

        if (MatchesAny(normalized, SpicyTerms))
            query = query.Where(IsSpicyItem);

        if (MatchesAny(normalized, BeverageTerms))
            query = query.Where(i => IsItemMatch(i, BeverageTerms));

        if (MatchesAny(normalized, DessertTerms))
            query = query.Where(i => IsItemMatch(i, DessertTerms));

        if (MatchesAny(normalized, QuickTerms))
            query = query.Where(i => i.PreparationTime <= 10);

        var directlyMentioned = scopedItems
            .Where(i => IsFuzzyPhraseMatch(normalized, i.ItemName) ||
                        IsFuzzyPhraseMatch(normalized, i.CategoryName))
            .ToList();
        if (directlyMentioned.Count > 0)
        {
            var directIds = directlyMentioned.Select(i => i.ItemName).ToHashSet(StringComparer.OrdinalIgnoreCase);
            query = query.Where(i => directIds.Contains(i.ItemName));
        }

        var results = query
            .OrderBy(i => i.Price)
            .ThenBy(i => i.ItemName)
            .Take(5)
            .ToList();

        if (results.Count == 0 && MatchesAny(normalized, SpicyTerms))
        {
            results = scopedItems
                .Where(i => IsItemMatch(i, SpicyFallbackTerms))
                .OrderBy(i => i.Price)
                .ThenBy(i => i.ItemName)
                .Take(5)
                .ToList();
        }

        if (results.Count == 0 && (IsRecommendationRequest(userMessage) || maxPrice is not null || IsOpenMenuRequest(userMessage)))
        {
            results = scopedItems
                .OrderBy(i => i.Price)
                .ThenBy(i => i.ItemName)
                .Take(5)
                .ToList();
        }

        return results;
    }

    private static string BuildFoodReplyHeading(string userMessage, int count)
    {
        var maxPrice = TryExtractMaxPrice(userMessage);
        if (MatchesAny(Normalize(userMessage), SpicyTerms))
            return $"I found {count} spicy-style option(s):";
        if (maxPrice is not null)
            return $"I found {count} option(s) under Rs. {maxPrice.Value:0}:";
        if (IsRecommendationRequest(userMessage))
            return $"Here are {count} good food suggestion(s):";
        return $"Here are {count} menu detail(s):";
    }

    private static string FormatDetailedItem(MenuContextRow item)
    {
        var veg = item.IsVegetarian ? "Veg" : "Non-veg";
        var spice = string.IsNullOrWhiteSpace(item.SpiceLevel) || item.SpiceLevel == "none"
            ? IsItemMatch(item, SpicyFallbackTerms) ? "spicy-style" : "not spicy"
            : item.SpiceLevel.Replace('_', ' ');
        var prep = item.PreparationTime > 0 ? $"{item.PreparationTime} min" : "prep time not listed";
        var description = string.IsNullOrWhiteSpace(item.Description)
            ? "No description available."
            : item.Description.Trim();

        return $"{item.ItemName} - Rs. {item.Price:0} at {item.CanteenName}. {veg}, {item.CategoryName}, {spice}, {prep}. {description}";
    }

    private static bool IsRecommendationRequest(string message)
    {
        var normalized = Normalize(message);
        return MatchesAny(normalized, RecommendationTerms);
    }

    private static bool IsCanteenDetailsRequest(string message, CanteenContextRow? canteen)
    {
        var normalized = Normalize(message);
        return MatchesAny(normalized, CanteenDetailTerms) &&
               (canteen is not null || !MatchesAny(normalized, FoodPreferenceTerms));
    }

    private static bool IsOpenMenuRequest(string message)
    {
        var normalized = Normalize(message);
        return MatchesAny(normalized, OpenMenuTerms);
    }

    private static bool IsSpicyItem(MenuContextRow item)
    {
        var spice = Normalize(item.SpiceLevel);
        return spice is "mild" or "medium" or "hot" or "extra hot" ||
               IsItemMatch(item, SpicyFallbackTerms);
    }

    private static bool IsItemMatch(MenuContextRow item, IEnumerable<string> terms)
    {
        var haystack = Normalize($"{item.ItemName} {item.Description} {item.CategoryName}");
        return MatchesAny(haystack, terms);
    }

    private static decimal? TryExtractMaxPrice(string message)
    {
        var normalized = Normalize(message);
        var match = Regex.Match(
            normalized,
            @"(?:under|uder|below|within|upto|up to|less than|budget|cheap)\s+(?:rs\s*)?(\d{1,5})",
            RegexOptions.IgnoreCase);

        if (!match.Success)
        {
            match = Regex.Match(
                normalized,
                @"(?:rs\s*)?(\d{1,5})\s*(?:or less|max|maximum|budget)",
                RegexOptions.IgnoreCase);
        }

        return match.Success && decimal.TryParse(match.Groups[1].Value, out var price) && price > 0
            ? price
            : null;
    }

    private static async Task<IReadOnlyList<MenuContextRow>> GetAvailableMenuItemsAsync(
        System.Data.IDbConnection connection,
        CancellationToken ct)
    {
        return (await connection.QueryAsync<MenuContextRow>(new CommandDefinition(
            """
            SELECT
                COALESCE(c.id, 0) AS CanteenId,
                COALESCE(c.name, 'Unknown') AS CanteenName,
                COALESCE(c.description, '') AS CanteenDescription,
                COALESCE(c.status, '') AS CanteenStatus,
                COALESCE(mi.name, 'Item')   AS ItemName,
                COALESCE(mi.description, '') AS Description,
                COALESCE(mi.price, 0)        AS Price,
                COALESCE(mc.name, 'Uncategorized') AS CategoryName,
                COALESCE(mi.is_vegetarian, 0) AS IsVegetarian,
                COALESCE(mi.spice_level, 'none') AS SpiceLevel,
                COALESCE(mi.preparation_time, 0) AS PreparationTime
            FROM menu_items mi
            LEFT JOIN canteens c ON c.id = mi.canteen_id
            LEFT JOIN menu_categories mc ON mc.id = mi.category_id
            WHERE COALESCE(mi.is_available, 1) = 1
              AND COALESCE(mi.is_deleted, 0) = 0
            ORDER BY c.display_order ASC, mi.price ASC;
            """,
            cancellationToken: ct))).ToList();
    }

    private static string BuildMenuContext(IReadOnlyList<MenuContextRow> items)
    {
        if (items.Count == 0)
            return "No menu items currently available.";

        var grouped = items
            .GroupBy(i => i.CanteenName)
            .Select(g =>
            {
                var itemList = string.Join(", ", g.Select(i =>
                    $"{i.ItemName} (Rs. {i.Price:0}, {i.CategoryName}, {i.SpiceLevel}, {(i.IsVegetarian ? "veg" : "non-veg")})"));
                return $"{g.Key}: {itemList}";
            });

        return string.Join("\n", grouped);
    }

    private static async Task SaveAssistantMessageAsync(
        System.Data.IDbConnection connection,
        string sessionId,
        string content,
        CancellationToken ct)
    {
        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO chatbot_messages (conversation_id, role, content, created_at)
            VALUES (@conversationId, 'assistant', @content, UTC_TIMESTAMP());
            """,
            new { conversationId = sessionId, content },
            cancellationToken: ct));
    }

    private static async Task<string?> GetUserDisplayNameAsync(
        System.Data.IDbConnection connection,
        int? userId,
        CancellationToken ct)
    {
        if (userId is null or <= 0)
            return null;

        var user = await connection.QuerySingleOrDefaultAsync<UserNameRow>(new CommandDefinition(
            """
            SELECT
                COALESCE(NULLIF(TRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))), ''), COALESCE(email, ''), COALESCE(university_id, '')) AS Name
            FROM users
            WHERE id = @userId
              AND COALESCE(status, 'active') = 'active'
            LIMIT 1;
            """,
            new { userId },
            cancellationToken: ct));

        return user?.Name.Trim();
    }

    private static async Task<ChatReplyResult> BuildProfileReplyAsync(
        System.Data.IDbConnection connection,
        int? userId,
        CancellationToken ct)
    {
        if (userId is null or <= 0)
        {
            return new ChatReplyResult(
                true,
                "I cannot show profile details because you are not logged in in this chat session.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "profile");
        }

        var universityIdColumn = await connection.QuerySingleOrDefaultAsync<string>(new CommandDefinition(
            """
            SELECT COLUMN_NAME
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = 'users'
              AND COLUMN_NAME IN ('UniversityId', 'university_id')
            ORDER BY CASE WHEN COLUMN_NAME = 'UniversityId' THEN 0 ELSE 1 END
            LIMIT 1;
            """,
            cancellationToken: ct));

        var universityIdExpression = string.IsNullOrWhiteSpace(universityIdColumn)
            ? "''"
            : $"COALESCE({universityIdColumn}, '')";

        var user = await connection.QuerySingleOrDefaultAsync<UserProfileRow>(new CommandDefinition(
            $"""
            SELECT
                COALESCE(NULLIF(TRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))), ''), COALESCE(email, ''), {universityIdExpression}) AS Name,
                COALESCE(email, '') AS Email,
                COALESCE(contact, '') AS Contact,
                COALESCE(department, '') AS Department,
                COALESCE(role, '') AS Role,
                {universityIdExpression} AS UniversityId,
                COALESCE(status, '') AS Status
            FROM users
            WHERE id = @userId
              AND COALESCE(is_deleted, 0) = 0
            LIMIT 1;
            """,
            new { userId },
            cancellationToken: ct));

        if (user is null)
        {
            return new ChatReplyResult(
                true,
                "I could not find your profile details. Please make sure you are logged in and try again.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "profile");
        }

        return new ChatReplyResult(
            true,
            $"Profile details:\nName: {user.Name}\nEmail: {user.Email}\nUniversity ID: {EmptyAsNotListed(user.UniversityId)}\nDepartment: {EmptyAsNotListed(user.Department)}\nRole: {EmptyAsNotListed(user.Role)}\nContact: {EmptyAsNotListed(user.Contact)}\nStatus: {EmptyAsNotListed(user.Status)}",
            string.Empty,
            DateTime.UtcNow,
            Intent: "profile");
    }

    private static string EmptyAsNotListed(string value) =>
        string.IsNullOrWhiteSpace(value) ? "Not listed" : value.Trim();

    private static CanteenContextRow? FindMentionedCanteen(
        string message,
        IReadOnlyList<CanteenContextRow> canteens)
    {
        var normalized = Normalize(message);
        return canteens.FirstOrDefault(c => IsFuzzyPhraseMatch(normalized, c.CanteenName));
    }

    private static CanteenContextRow? FindCanteenByMentionedItem(
        string message,
        IReadOnlyList<MenuContextRow> menuItems)
    {
        var normalized = Normalize(message);
        var item = menuItems.FirstOrDefault(i => IsFuzzyPhraseMatch(normalized, i.ItemName));
        return item is null
            ? null
            : new CanteenContextRow
            {
                CanteenId = item.CanteenId,
                CanteenName = item.CanteenName,
                CanteenDescription = item.CanteenDescription,
                CanteenStatus = item.CanteenStatus
            };
    }

    private static bool MatchesAny(string normalizedMessage, IEnumerable<string> terms) =>
        terms.Any(term => IsFuzzyPhraseMatch(normalizedMessage, term));

    private static bool IsFuzzyPhraseMatch(string normalizedMessage, string phrase)
    {
        var normalizedPhrase = Normalize(phrase);
        if (normalizedPhrase.Length == 0)
            return false;

        if (normalizedMessage.Contains(normalizedPhrase, StringComparison.Ordinal))
            return true;

        var messageTokens = normalizedMessage.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        var phraseTokens = normalizedPhrase.Split(' ', StringSplitOptions.RemoveEmptyEntries);

        return phraseTokens.All(phraseToken =>
            messageTokens.Any(messageToken =>
                messageToken.Equals(phraseToken, StringComparison.Ordinal) ||
                (messageToken.Length >= 3 &&
                    phraseToken.Length >= 3 &&
                    (messageToken.Contains(phraseToken, StringComparison.Ordinal) ||
                     phraseToken.Contains(messageToken, StringComparison.Ordinal))) ||
                (messageToken.Length >= 3 &&
                    phraseToken.Length >= 3 &&
                    LevenshteinDistance(messageToken, phraseToken) <= (phraseToken.Length <= 5 ? 1 : 2))));
    }

    private static string Normalize(string value)
    {
        var lower = value.ToLowerInvariant();
        return Regex.Replace(lower, @"[^a-z0-9\s]", " ").Trim();
    }

    private static int LevenshteinDistance(string a, string b)
    {
        if (a.Length == 0) return b.Length;
        if (b.Length == 0) return a.Length;

        var costs = new int[b.Length + 1];
        for (var j = 0; j <= b.Length; j++)
            costs[j] = j;

        for (var i = 1; i <= a.Length; i++)
        {
            costs[0] = i;
            var previousDiagonal = i - 1;
            for (var j = 1; j <= b.Length; j++)
            {
                var temp = costs[j];
                costs[j] = Math.Min(
                    Math.Min(costs[j] + 1, costs[j - 1] + 1),
                    previousDiagonal + (a[i - 1] == b[j - 1] ? 0 : 1));
                previousDiagonal = temp;
            }
        }

        return costs[b.Length];
    }

    private static readonly string[] FoodTerms =
    [
        "food", "hungry", "hunger", "eat", "eating", "snack", "snacks", "meal", "meals",
        "canteen", "canteen item", "canteen items", "order food", "ordering", "menu", "burger", "pizza",
        "sandwich", "tea", "coffee", "breakfast", "lunch", "dinner", "available food",
        "something to eat", "show food", "show menu", "recommend", "suggest", "tasty",
        "popular", "best", "famous", "budget", "cheap", "price", "available"
    ];

    private static readonly string[] RecommendationTerms =
    [
        "recommend", "recommendation", "suggest", "suggestion", "best", "popular",
        "budget", "cheap", "under", "uder", "below", "within", "less than", "upto", "up to"
    ];

    private static readonly string[] OpenMenuTerms =
    [
        "open menu", "show menu", "go to menu", "menu page", "browse menu", "start order",
        "order this", "order food", "take me to menu"
    ];

    private static readonly string[] CanteenDetailTerms =
    [
        "canteen", "canteens", "outlet", "outlets", "details", "detail", "about",
        "available at", "what is available at", "what's available at"
    ];

    private static readonly string[] FoodPreferenceTerms =
    [
        "food", "item", "items", "meal", "snack", "spicy", "veg", "non veg", "drink",
        "dessert", "cheap", "budget", "under", "recommend", "suggest"
    ];

    private static readonly string[] VegetarianTerms =
    [
        "veg", "vegetarian", "pure veg", "meatless"
    ];

    private static readonly string[] NonVegetarianTerms =
    [
        "non veg", "non vegetarian", "nonveg", "chicken", "fish", "egg", "meat", "pepperoni"
    ];

    private static readonly string[] SpicyTerms =
    [
        "spicy", "hot", "extra hot", "medium spicy", "mild spicy", "masala", "chilli", "chili"
    ];

    private static readonly string[] SpicyFallbackTerms =
    [
        "spicy", "hot", "masala", "chilli", "chili", "pepper", "tikka", "arrabiata",
        "biryani", "nachos", "bbq"
    ];

    private static readonly string[] BeverageTerms =
    [
        "drink", "drinks", "beverage", "beverages", "tea", "coffee", "latte", "mojito",
        "smoothie", "juice"
    ];

    private static readonly string[] DessertTerms =
    [
        "dessert", "desserts", "sweet", "sweets", "brownie", "cheesecake", "jamun", "cake"
    ];

    private static readonly string[] QuickTerms =
    [
        "quick", "fast", "instant", "less time", "under 10 min", "under 10 minutes"
    ];

    private static readonly CanteenContextRow[] KnownCanteens =
    [
        new() { CanteenId = 1, CanteenName = "Chirag Tea Center" },
        new() { CanteenId = 2, CanteenName = "Tea Post" },
        new() { CanteenId = 3, CanteenName = "Foodies" }
    ];

    private static readonly string[] AccountNameTerms =
    [
        "what is my name", "who am i", "tell my name", "my name", "account name"
    ];

    private static readonly string[] ProfileTerms =
    [
        "my profile", "profile details", "profile", "my account", "account details",
        "my email", "my department", "my contact", "my university id"
    ];

    private static readonly string[] OrderHowToTerms =
    [
        "how to place order", "place an order", "how do i order", "how to order", "order process"
    ];

    private static readonly string[] TrackOrderTerms =
    [
        "track order", "track my order", "order status", "where is my order", "live order"
    ];

    private static readonly string[] CancelOrderTerms =
    [
        "cancel order", "cancel my order", "how to cancel", "order cancellation"
    ];

    private static readonly string[] WalletTerms =
    [
        "wallet", "wallet payment", "recharge wallet", "add money", "payment work", "refund"
    ];

    private static readonly string[] SupportTerms =
    [
        "support", "contact support", "help desk", "complaint", "issue", "problem"
    ];

    private static readonly string[] CanteenPanelTerms =
    [
        "canteen panel", "canteen admin", "vendor panel", "manage orders", "manage menu"
    ];

    private enum ChatIntent
    {
        Unknown,
        Menu,
        AccountName,
        Profile,
        PlaceOrderHelp,
        WalletHelp,
        TrackOrderHelp,
        SupportHelp,
        CanteenPanelHelp,
        CancelOrderHelp
    }

    private sealed class ChatHistoryRow
    {
        public string Role { get; init; } = "user";
        public string Content { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class MenuContextRow
    {
        public int CanteenId { get; init; }
        public string CanteenName { get; init; } = string.Empty;
        public string CanteenDescription { get; init; } = string.Empty;
        public string CanteenStatus { get; init; } = string.Empty;
        public string ItemName { get; init; } = string.Empty;
        public string Description { get; init; } = string.Empty;
        public decimal Price { get; init; }
        public string CategoryName { get; init; } = string.Empty;
        public bool IsVegetarian { get; init; }
        public string SpiceLevel { get; init; } = string.Empty;
        public int PreparationTime { get; init; }
    }

    private sealed class CanteenContextRow
    {
        public int CanteenId { get; init; }
        public string CanteenName { get; init; } = string.Empty;
        public string CanteenDescription { get; init; } = string.Empty;
        public string CanteenStatus { get; init; } = string.Empty;
    }

    private sealed class UserNameRow
    {
        public string Name { get; init; } = string.Empty;
    }

    private sealed class UserProfileRow
    {
        public string Name { get; init; } = string.Empty;
        public string Email { get; init; } = string.Empty;
        public string Contact { get; init; } = string.Empty;
        public string Department { get; init; } = string.Empty;
        public string Role { get; init; } = string.Empty;
        public string UniversityId { get; init; } = string.Empty;
        public string Status { get; init; } = string.Empty;
    }
}
