namespace UniversityCanteen.Api.Configuration;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    public string Secret { get; set; } = string.Empty;
    public string Issuer { get; set; } = "UniversityCanteen";
    public string Audience { get; set; } = "UniversityCanteenApp";
    public int ExpiryHours { get; set; } = 12;
    public int RefreshTokenDays { get; set; } = 7;
}
