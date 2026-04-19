namespace UniversityCanteen.Api.Services;

public interface IOtpEmailSender
{
    Task SendOtpAsync(
        string toEmail,
        string recipientName,
        string otp,
        DateTime expiryUtc,
        CancellationToken cancellationToken);
}
