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
                .GroupBy(i => new { i.CanteenId, i.CanteenName })
                .Select(g => new CanteenContextRow { CanteenId = g.Key.CanteenId, CanteenName = g.Key.CanteenName })
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
        {
            var canteen = FindMentionedCanteen(userMessage, KnownCanteens);
            var target = string.IsNullOrWhiteSpace(canteen?.CanteenName)
                ? "the food menu"
                : $"{canteen.CanteenName} menu";

            return new ChatReplyResult(
                true,
                $"Sure, opening {target}. You can browse items, add food to cart, and place your order from there.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "menu",
                Action: "show_menu",
                CanteenId: canteen is { CanteenId: > 0 } ? canteen.CanteenId : null,
                CanteenName: canteen?.CanteenName);
        }

        if (intent == ChatIntent.AccountName)
        {
            var displayName = (userName ?? string.Empty).Trim();
            var response = string.IsNullOrWhiteSpace(displayName)
                ? "I could not find your name in the current session. Please make sure you are logged in and try again."
                : $"Your name is {displayName}.";

            return new ChatReplyResult(true, response, string.Empty, DateTime.UtcNow, Intent: "account_name");
        }

        var systemAnswer = BuildSystemKnowledgeAnswer(intent);
        if (systemAnswer is not null)
            return new ChatReplyResult(true, systemAnswer, string.Empty, DateTime.UtcNow, Intent: intent.ToString().ToLowerInvariant());

        return new ChatReplyResult(true, FallbackMessage, string.Empty, DateTime.UtcNow, Intent: "fallback");
    }

    private static ChatReplyResult BuildOfflineReply(string userMessage)
    {
        var intent = DetectIntent(userMessage, Array.Empty<MenuContextRow>(), Array.Empty<CanteenContextRow>());

        if (intent == ChatIntent.Menu)
        {
            return new ChatReplyResult(
                true,
                "Sure, I can help with food. Opening the menu now. If it does not load, please check the database or network connection.",
                string.Empty,
                DateTime.UtcNow,
                Intent: "menu",
                Action: "show_menu");
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

        var systemAnswer = BuildSystemKnowledgeAnswer(intent);
        if (systemAnswer is not null)
        {
            return new ChatReplyResult(
                true,
                systemAnswer,
                string.Empty,
                DateTime.UtcNow,
                Intent: intent.ToString().ToLowerInvariant());
        }

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
            var response = BuildMenuResponse(menuItems, canteen);

            return new ChatReplyResult(
                true,
                response,
                string.Empty,
                DateTime.UtcNow,
                Intent: "menu",
                Action: "show_menu",
                CanteenId: canteen?.CanteenId,
                CanteenName: canteen?.CanteenName);
        }

        if (intent == ChatIntent.AccountName)
        {
            var name = await GetUserDisplayNameAsync(connection, userId, ct);
            var response = string.IsNullOrWhiteSpace(name)
                ? "I could not find your name yet. Please make sure you are logged in and try again."
                : $"Your name is {name}.";

            return new ChatReplyResult(true, response, string.Empty, DateTime.UtcNow, Intent: "account_name");
        }

        var systemAnswer = BuildSystemKnowledgeAnswer(intent);
        if (systemAnswer is not null)
            return new ChatReplyResult(true, systemAnswer, string.Empty, DateTime.UtcNow, Intent: intent.ToString().ToLowerInvariant());

        return null;
    }

    private static ChatIntent DetectIntent(
        string message,
        IReadOnlyList<MenuContextRow> menuItems,
        IReadOnlyList<CanteenContextRow> canteens)
    {
        var normalized = Normalize(message);

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

    private static string BuildMenuResponse(
        IReadOnlyList<MenuContextRow> menuItems,
        CanteenContextRow? canteen)
    {
        var scopedItems = canteen is null
            ? menuItems
            : menuItems.Where(i => i.CanteenId == canteen.CanteenId).ToList();

        if (scopedItems.Count == 0)
            return "I can open the menu for you, but no available items were found right now.";

        var sample = string.Join(", ", scopedItems.Take(6).Select(i => $"{i.ItemName} (Rs. {i.Price:0})"));
        var target = canteen is null ? "the food menu" : $"{canteen.CanteenName} menu";
        return $"Sure, opening {target}. Some available items are: {sample}.";
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
                COALESCE(mi.name, 'Item')   AS ItemName,
                COALESCE(mi.price, 0)        AS Price
            FROM menu_items mi
            LEFT JOIN canteens c ON c.id = mi.canteen_id
            WHERE COALESCE(mi.is_available, 1) = 1
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
                var itemList = string.Join(", ", g.Select(i => $"{i.ItemName} (Rs. {i.Price:0})"));
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
            : new CanteenContextRow { CanteenId = item.CanteenId, CanteenName = item.CanteenName };
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
        public string ItemName { get; init; } = string.Empty;
        public decimal Price { get; init; }
    }

    private sealed class CanteenContextRow
    {
        public int CanteenId { get; init; }
        public string CanteenName { get; init; } = string.Empty;
    }

    private sealed class UserNameRow
    {
        public string Name { get; init; } = string.Empty;
    }
}
