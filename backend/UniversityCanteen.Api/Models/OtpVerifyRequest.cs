namespace UniversityCanteen.Api.Models;

public sealed class OtpVerifyRequest
{
    public string Email { get; set; } = string.Empty;
    public string Otp { get; set; } = string.Empty;
}
