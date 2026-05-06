namespace UniversityCanteen.Api.Configuration;

public sealed class ResendOptions
{
    public const string SectionName = "Resend";

    public string ApiKey { get; init; } = string.Empty;
    public string FromEmail { get; init; } = "onboarding@resend.dev";
    public string FromName { get; init; } = "University Canteen";
    public string ApiBaseUrl { get; init; } = "https://api.resend.com";
}
