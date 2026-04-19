namespace UniversityCanteen.Api.Models;

public sealed class AuthLoginApiRequest
{
    public string LoginType { get; set; } = "user";
    public string Identifier { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public sealed class AdminLoginApiRequest
{
    public string Identifier { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public sealed class UserLoginApiRequest
{
    public string Identifier { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public sealed class RefreshTokenApiRequest
{
    public string RefreshToken { get; set; } = string.Empty;
}

public sealed class LogoutApiRequest
{
    public string? RefreshToken { get; set; }
}
