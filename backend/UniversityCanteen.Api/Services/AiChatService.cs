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

        // Fetch last 10 messages for context
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

        // Build menu context
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
        var resolvedKey = ResolveApiKey();

        if (!_opts.Enabled || string.IsNullOrWhiteSpace(resolvedKey))
        {
            aiResponse = GenerateFallbackResponse(trimmedMessage);
        }
        else
        {
            aiResponse = await CallOpenRouterAsync(systemPrompt, history, ct);
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

    // OpenRouter uses OpenAI-compatible /chat/completions format
    private async Task<string> CallOpenRouterAsync(
        string systemPrompt,
        IEnumerable<ChatHistoryRow> history,
        CancellationToken ct)
    {
        try
        {
            var client = httpClientFactory.CreateClient("OpenRouter");

            // Build messages array: system first, then conversation history
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

    // Reads from Ai:ApiKey config section first, then falls back to standalone ApiKey env var
    private string ResolveApiKey()
    {
        if (!string.IsNullOrWhiteSpace(_opts.ApiKey))
            return _opts.ApiKey;

        return Environment.GetEnvironmentVariable("ApiKey") ?? string.Empty;
    }

    private static string GenerateFallbackResponse(string userMessage)
    {
        var msg = userMessage.ToLowerInvariant();

        if (msg.Contains("budget") || msg.Contains("cheap") || msg.Contains("under") || msg.Contains("price"))
            return "For budget meals, check out the Budget Meals section on the home screen! There are great options under ₹150.";

        if (msg.Contains("trending") || msg.Contains("popular") || msg.Contains("best") || msg.Contains("famous"))
            return "Check the Trending Now section on the home screen to see the most popular items on campus right now!";

        if (msg.Contains("foodies"))
            return "Foodies canteen has a great variety! Browse their menu in the Canteens section for the full list with prices.";

        if (msg.Contains("chirag") || msg.Contains("tea center"))
            return "Chirag Tea Center is famous for tea and snacks. Visit their menu section in the app!";

        if (msg.Contains("tea post"))
            return "Tea Post has excellent beverages and snacks. Check their full menu in the Canteens section!";

        if (msg.Contains("recommend") || msg.Contains("suggest") || msg.Contains("what") || msg.Contains("tasty"))
            return "Check the 'Recommended For You' section on the home screen for personalised picks based on your order history!";

        return "I'm here to help with food recommendations! Browse our canteens on the home screen or ask about specific items.";
    }

    private static async Task<string> BuildMenuContextAsync(
        System.Data.IDbConnection connection,
        CancellationToken ct)
    {
        var items = (await connection.QueryAsync<MenuContextRow>(new CommandDefinition(
            """
            SELECT
                COALESCE(c.name, 'Unknown') AS CanteenName,
                COALESCE(mi.name, 'Item')   AS ItemName,
                COALESCE(mi.price, 0)        AS Price
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
