namespace UniversityCanteen.Api.Configuration;

public sealed class AiOptions
{
    public const string SectionName = "Ai";
    public string AnthropicApiKey { get; init; } = string.Empty;
    public string Model { get; init; } = "claude-haiku-4-5-20251001";
    public int MaxTokens { get; init; } = 800;
    public bool Enabled { get; init; } = true;
}
