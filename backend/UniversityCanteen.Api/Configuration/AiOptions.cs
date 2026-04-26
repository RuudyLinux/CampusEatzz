namespace UniversityCanteen.Api.Configuration;

public sealed class AiOptions
{
    public const string SectionName = "Ai";
    public string ApiKey { get; init; } = string.Empty;
    public string Model { get; init; } = "meta-llama/llama-3.1-8b-instruct:free";
    public string BaseUrl { get; init; } = "https://openrouter.ai/api/v1/";
    public int MaxTokens { get; init; } = 800;
    public bool Enabled { get; init; } = true;
}
