using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using UniversityCanteen.Api.Configuration;

namespace UniversityCanteen.Api.Services;

public sealed class ResendOtpEmailSender(
    HttpClient httpClient,
    IOptions<ResendOptions> resendOptions,
    IOptions<OtpOptions> otpOptions,
    ILogger<ResendOtpEmailSender> logger) : IOtpEmailSender
{
    private readonly HttpClient _httpClient = httpClient;
    private readonly ResendOptions _resendOptions = resendOptions.Value;
    private readonly OtpOptions _otpOptions = otpOptions.Value;

    public async Task SendOtpAsync(
        string toEmail,
        string recipientName,
        string otp,
        DateTime expiryUtc,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var apiKey = ResolveApiKey();
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            throw new InvalidOperationException(
                "Resend API key is missing. Configure Resend:ApiKey or RESEND_API_KEY.");
        }

        var fromEmail = (_resendOptions.FromEmail ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(fromEmail))
        {
            throw new InvalidOperationException("Resend FromEmail is missing. Configure Resend:FromEmail.");
        }

        var to = (toEmail ?? string.Empty).Trim();
        if (string.IsNullOrWhiteSpace(to))
        {
            throw new InvalidOperationException("Recipient email is required for OTP delivery.");
        }

        var subject = string.IsNullOrWhiteSpace(_otpOptions.EmailSubject)
            ? "Your University Canteen OTP"
            : _otpOptions.EmailSubject.Trim();

        var payload = new
        {
            from = BuildFromField((_resendOptions.FromName ?? string.Empty).Trim(), fromEmail),
            to = new[] { to },
            subject,
            html = BuildHtmlBody(recipientName, otp, expiryUtc),
            text = BuildTextBody(recipientName, otp, expiryUtc)
        };

        using var request = new HttpRequestMessage(HttpMethod.Post, "emails");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
        request.Content = new StringContent(
            JsonSerializer.Serialize(payload),
            Encoding.UTF8,
            "application/json");

        using var response = await _httpClient.SendAsync(request, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            logger.LogWarning(
                "Resend OTP delivery failed for {Email}. Status: {StatusCode}. Body: {Body}",
                to,
                (int)response.StatusCode,
                responseBody);

            throw new InvalidOperationException("Unable to deliver OTP email right now. Please try again shortly.");
        }

        logger.LogInformation("OTP email delivered to {Email} via Resend.", to);
    }

    private string ResolveApiKey()
    {
        var configuredKey = (_resendOptions.ApiKey ?? string.Empty).Trim();
        if (!string.IsNullOrWhiteSpace(configuredKey))
        {
            return configuredKey;
        }

        var key = Environment.GetEnvironmentVariable("RESEND_API_KEY")
            ?? Environment.GetEnvironmentVariable("Resend__ApiKey")
            ?? Environment.GetEnvironmentVariable("RESEND_APIKEY")
            ?? string.Empty;

        return key.Trim();
    }

    private static string BuildFromField(string fromName, string fromEmail)
    {
        return string.IsNullOrWhiteSpace(fromName)
            ? fromEmail
            : $"{fromName} <{fromEmail}>";
    }

    private static string BuildTextBody(string recipientName, string otp, DateTime expiryUtc)
    {
        var name = string.IsNullOrWhiteSpace(recipientName) ? "User" : recipientName.Trim();
        var expiryText = expiryUtc.ToLocalTime().ToString("dd MMM yyyy hh:mm tt");
        return $"Hello {name},\n\nYour CampusEatzz OTP is: {otp}\nValid until: {expiryText}\n\nDo not share this OTP with anyone.";
    }

    private static string BuildHtmlBody(string recipientName, string otp, DateTime expiryUtc)
    {
        var name = string.IsNullOrWhiteSpace(recipientName) ? "User" : recipientName;
        var expiryText = expiryUtc.ToLocalTime().ToString("dd MMM yyyy hh:mm tt");

        return $"""
            <div style="margin:0;padding:24px;background:#f4f8ff;font-family:Segoe UI,Arial,sans-serif;color:#0f172a;">
                <div style="max-width:620px;margin:0 auto;">
                    <div style="background:linear-gradient(135deg,#0f274f,#1f4ea3);border-radius:16px 16px 0 0;padding:18px 22px;color:#ffffff;">
                        <h2 style="margin:0;font-size:24px;">CampusEatzz Secure Login</h2>
                        <p style="margin:6px 0 0 0;font-size:13px;opacity:0.9;">One-Time Password Verification</p>
                    </div>

                    <div style="background:#ffffff;border:1px solid #d7e3fb;border-top:none;border-radius:0 0 16px 16px;padding:24px;">
                        <p style="margin:0 0 12px 0;font-size:14px;">Hello <strong>{WebUtility.HtmlEncode(name)}</strong>,</p>
                        <p style="margin:0 0 14px 0;font-size:14px;color:#334155;">Use the OTP below to continue your CampusEatzz login.</p>

                        <div style="margin:0 0 14px 0;display:inline-block;padding:12px 18px;background:#eef4ff;border:1px solid #c7d8fb;border-radius:12px;">
                            <span style="font-size:30px;font-weight:800;letter-spacing:8px;color:#1f4ea3;">{WebUtility.HtmlEncode(otp)}</span>
                        </div>

                        <div style="margin:0 0 14px 0;padding:10px 12px;background:#f8fafc;border-left:4px solid #1f4ea3;border-radius:8px;">
                            <p style="margin:0;font-size:13px;color:#475569;">
                                This OTP is valid until <strong>{WebUtility.HtmlEncode(expiryText)}</strong>.
                            </p>
                        </div>

                        <p style="margin:0 0 6px 0;font-size:13px;color:#475569;">Security tips:</p>
                        <ul style="margin:0 0 10px 16px;padding:0;color:#475569;font-size:13px;line-height:1.5;">
                            <li>Never share this OTP with anyone.</li>
                            <li>CampusEatzz team will never ask for OTP by call or chat.</li>
                        </ul>

                        <p style="margin:0;font-size:12px;color:#64748b;">If you did not request this login, you can safely ignore this email.</p>
                    </div>
                </div>
            </div>
            """;
    }
}
