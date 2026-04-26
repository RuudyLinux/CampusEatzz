using System.Text;
using System.Text.Json;
using Dapper;
using Microsoft.Extensions.Options;
using UniversityCanteen.Api.Configuration;
using UniversityCanteen.Api.Data;

namespace UniversityCanteen.Api.Services;

public sealed class AiChatService(
    IDbConnectionFactory dbConnectionFactory,
    IHttpClientFactory httpClientFactory,
    IOptions<AiOptions> aiOptions,
    ILogger<AiChatService> logger) : IAiChatService
{
    private readonly AiOptions _opts = aiOptions.Value;

    public async Task<ChatReplyResult> SendMessageAsync(
        string sessionId,
        string userMessage,
        int? userId,
        CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(sessionId) || sessionId.Length > 100)
            return new ChatReplyResult(false, string.Empty, sessionId, DateTime.UtcNow, "Invalid session ID.");

        var trimmedMessage = (userMessage ?? string.Empty).Trim();
        if (trimmedMessage.Length == 0 || trimmedMessage.Length > 1000)
            return new ChatReplyResult(false, string.Empty, sessionId, DateTime.UtcNow, "Message must be 1-1000 characters.");

        using var connection = dbConnectionFactory.CreateConnection();

        // Ensure conversation row exists
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

        // Persist user message
        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO chatbot_messages (conversation_id, role, content, created_at)
            VALUES (@conversationId, 'user', @content, UTC_TIMESTAMP());
            """,
            new { conversationId = sessionId, content = trimmedMessage },
            cancellationToken: ct));

        // Fetch last 10 messages for conversation context (excluding the one just inserted)
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

        // Reverse so oldest first; last item is the user message just saved
        history.Reverse();
        var messages = history.Select(h => new { role = h.Role, content = h.Content }).ToList();

        // Build menu context for AI
        var menuContext = await BuildMenuContextAsync(connection, ct);

        var systemPrompt = $"""
            You are CampusEatzz Food Assistant — a helpful AI for a university campus food ordering app in India.

            You help students find food, get recommendations, and navigate the menu.

            Current available menu:
            {menuContext}

            Guidelines:
            - Keep responses concise (2-4 sentences max unless listing items)
            - Use ₹ for prices
            - Mention item name, price, and canteen when recommending
            - For ordering, tell users to browse the menu or use the canteen section
            - Be friendly and conversational
            - Do NOT make up items not listed in the menu above
            - If asked about something unrelated to food/canteen, politely redirect
            """;

        string aiResponse;

        if (!_opts.Enabled || string.IsNullOrWhiteSpace(_opts.AnthropicApiKey))
        {
            aiResponse = GenerateFallbackResponse(trimmedMessage, menuContext);
        }
        else
        {
            aiResponse = await CallAnthropicAsync(systemPrompt, messages, ct);
        }

        // Persist AI response
        await connection.ExecuteAsync(new CommandDefinition(
            """
            INSERT INTO chatbot_messages (conversation_id, role, content, created_at)
            VALUES (@conversationId, 'assistant', @content, UTC_TIMESTAMP());
            """,
            new { conversationId = sessionId, content = aiResponse },
            cancellationToken: ct));

        return new ChatReplyResult(true, aiResponse, sessionId, DateTime.UtcNow);
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

    private async Task<string> CallAnthropicAsync(
        string systemPrompt,
        IEnumerable<object> messages,
        CancellationToken ct)
    {
        try
        {
            var client = httpClientFactory.CreateClient("Anthropic");

            var requestBody = new
            {
                model = _opts.Model,
                max_tokens = _opts.MaxTokens,
                system = systemPrompt,
                messages
            };

            var json = JsonSerializer.Serialize(requestBody);
            using var content = new StringContent(json, Encoding.UTF8, "application/json");

            using var response = await client.PostAsync("v1/messages", content, ct);
            var responseJson = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning("Anthropic API error {Status}: {Body}", (int)response.StatusCode, responseJson);
                return "I'm having trouble connecting right now. Please try again in a moment.";
            }

            using var doc = JsonDocument.Parse(responseJson);
            var contentArr = doc.RootElement.GetProperty("content");
            if (contentArr.GetArrayLength() > 0)
            {
                return contentArr[0].GetProperty("text").GetString()
                    ?? "I couldn't generate a response. Please try again.";
            }

            return "I couldn't generate a response. Please try again.";
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Anthropic API call failed.");
            return "I'm temporarily unavailable. Please try again shortly.";
        }
    }

    private static string GenerateFallbackResponse(string userMessage, string menuContext)
    {
        var msg = userMessage.ToLowerInvariant();

        if (msg.Contains("budget") || msg.Contains("cheap") || msg.Contains("₹") || msg.Contains("price"))
            return "For budget meals, check out the menu items filtered by price. You can browse each canteen to find affordable options!";

        if (msg.Contains("trending") || msg.Contains("popular") || msg.Contains("best"))
            return "Our trending section on the home screen shows the most popular items. Check it out to see what's popular right now!";

        if (msg.Contains("foodies"))
            return "Foodies canteen offers a variety of meals. Browse the Foodies menu in the Canteens section for the full list!";

        if (msg.Contains("chirag") || msg.Contains("tea center"))
            return "Chirag Tea Center is known for great tea and snacks. Check their menu in the Canteens section!";

        if (msg.Contains("tea post"))
            return "Tea Post has excellent beverages. Browse their menu to see all options and prices!";

        return "I'm here to help with food recommendations! Browse our canteens on the home screen or ask me about specific items.";
    }

    private static async Task<string> BuildMenuContextAsync(
        System.Data.IDbConnection connection,
        CancellationToken ct)
    {
        var items = (await connection.QueryAsync<MenuContextRow>(new CommandDefinition(
            """
            SELECT
                COALESCE(c.name, 'Unknown') AS CanteenName,
                COALESCE(mi.name, 'Item') AS ItemName,
                COALESCE(mi.price, 0) AS Price
            FROM menu_items mi
            LEFT JOIN canteens c ON c.id = mi.canteen_id
            WHERE COALESCE(mi.is_available, 1) = 1
            ORDER BY c.display_order ASC, mi.price ASC;
            """,
            cancellationToken: ct))).ToList();

        if (items.Count == 0)
            return "No menu items currently available.";

        var grouped = items
            .GroupBy(i => i.CanteenName)
            .Select(g =>
            {
                var itemList = string.Join(", ", g.Select(i => $"{i.ItemName} (₹{i.Price:0})"));
                return $"{g.Key}: {itemList}";
            });

        return string.Join("\n", grouped);
    }

    private sealed class ChatHistoryRow
    {
        public string Role { get; init; } = "user";
        public string Content { get; init; } = string.Empty;
        public DateTime CreatedAt { get; init; }
    }

    private sealed class MenuContextRow
    {
        public string CanteenName { get; init; } = string.Empty;
        public string ItemName { get; init; } = string.Empty;
        public decimal Price { get; init; }
    }
}
