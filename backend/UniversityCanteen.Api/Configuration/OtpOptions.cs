namespace UniversityCanteen.Api.Configuration;

public sealed class OtpOptions
{
    public const string SectionName = "Otp";

    public int CodeLength { get; init; } = 6;
    public int ExpiryMinutes { get; init; } = 5;
    public int ResendCooldownSeconds { get; init; } = 30;
    public string EmailSubject { get; init; } = "Your University Canteen OTP";
    public bool ExposeOtpInResponseInDevelopment { get; init; } = true;
    public bool AllowOtpInResponseOnDeliveryFailure { get; init; } = false;
}
