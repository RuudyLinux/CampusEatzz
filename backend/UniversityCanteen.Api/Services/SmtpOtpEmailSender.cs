using System.Net;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.Extensions.Options;
using MimeKit;
using UniversityCanteen.Api.Configuration;

namespace UniversityCanteen.Api.Services;

public sealed class SmtpOtpEmailSender(
    IOptions<SmtpOptions> smtpOptions,
    IOptions<OtpOptions> otpOptions,
    ILogger<SmtpOtpEmailSender> logger) : IOtpEmailSender
{
    private static readonly TimeSpan SmtpAttemptTimeout = TimeSpan.FromSeconds(8);
    private readonly SmtpOptions _smtpOptions = smtpOptions.Value;
    private readonly OtpOptions _otpOptions = otpOptions.Value;

    public async Task SendOtpAsync(
        string toEmail,
        string recipientName,
        string otp,
        DateTime expiryUtc,
        CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();

        ValidateOptions();

        var host = (_smtpOptions.Host ?? string.Empty).Trim();
        var userName = (_smtpOptions.UserName ?? string.Empty).Trim();
        var appPassword = new string((_smtpOptions.Password ?? string.Empty)
            .Where(ch => !char.IsWhiteSpace(ch))
            .ToArray());
        var endpoints = BuildEndpoints(host, _smtpOptions.Port, _smtpOptions.EnableSsl);
        Exception? lastException = null;

        foreach (var endpoint in endpoints)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try
            {
                using var linkedCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                linkedCts.CancelAfter(SmtpAttemptTimeout);

                using var client = new SmtpClient();
                client.Timeout = (int)SmtpAttemptTimeout.TotalMilliseconds;
                client.CheckCertificateRevocation = false;

                var message = BuildMessage(toEmail, recipientName, otp, expiryUtc);
                var socketOption = ResolveSocketOption(endpoint.Port, endpoint.EnableSsl);

                await client.ConnectAsync(endpoint.Host, endpoint.Port, socketOption, linkedCts.Token);
                await client.AuthenticateAsync(userName, appPassword, linkedCts.Token);
                await client.SendAsync(message, linkedCts.Token);
                await client.DisconnectAsync(true, linkedCts.Token);

                logger.LogInformation(
                    "OTP email delivered to {Email} via {Host}:{Port} ({SocketOption})",
                    toEmail,
                    endpoint.Host,
                    endpoint.Port,
                    socketOption);

                return;
            }
            catch (OperationCanceledException ex) when (!cancellationToken.IsCancellationRequested)
            {
                lastException = ex;
                logger.LogWarning(
                    ex,
                    "SMTP delivery attempt timed out for {Email} via {Host}:{Port}.",
                    toEmail,
                    endpoint.Host,
                    endpoint.Port);
            }
            catch (Exception ex)
            {
                lastException = ex;
                logger.LogWarning(
                    ex,
                    "SMTP delivery attempt failed for {Email} via {Host}:{Port}.",
                    toEmail,
                    endpoint.Host,
                    endpoint.Port);
            }
        }

        logger.LogError(lastException, "SMTP delivery failed after all attempts for {Email}", toEmail);
        throw new InvalidOperationException("Unable to deliver OTP email right now. Please try again shortly.");
    }

    private void ValidateOptions()
    {
        if (string.IsNullOrWhiteSpace(_smtpOptions.Host) ||
            string.IsNullOrWhiteSpace(_smtpOptions.UserName) ||
            string.IsNullOrWhiteSpace(_smtpOptions.Password) ||
            string.IsNullOrWhiteSpace(_smtpOptions.FromEmail))
        {
            throw new InvalidOperationException(
                "SMTP settings are incomplete. Configure Smtp:Host, UserName, Password, and FromEmail in appsettings.");
        }
    }

    private MimeMessage BuildMessage(string toEmail, string recipientName, string otp, DateTime expiryUtc)
    {
        var message = new MimeMessage();
        message.From.Add(new MailboxAddress(_smtpOptions.FromName, _smtpOptions.FromEmail));
        message.To.Add(MailboxAddress.Parse(toEmail));
        message.Subject = string.IsNullOrWhiteSpace(_otpOptions.EmailSubject)
            ? "Your University Canteen OTP"
            : _otpOptions.EmailSubject;
        message.Body = new BodyBuilder
        {
            HtmlBody = BuildHtmlBody(recipientName, otp, expiryUtc),
        }.ToMessageBody();
        return message;
    }

    private static List<SmtpEndpoint> BuildEndpoints(string host, int port, bool enableSsl)
    {
        var endpoints = new List<SmtpEndpoint>();

        void Add(string h, int p, bool ssl)
        {
            if (string.IsNullOrWhiteSpace(h) || p <= 0)
            {
                return;
            }

            if (endpoints.Any(item =>
                string.Equals(item.Host, h, StringComparison.OrdinalIgnoreCase)
                && item.Port == p
                && item.EnableSsl == ssl))
            {
                return;
            }

            endpoints.Add(new SmtpEndpoint(h, p, ssl));
        }

        Add(host, port, enableSsl);

        // Gmail-specific fallback: try both STARTTLS(587) and implicit TLS(465).
        if (string.Equals(host, "smtp.gmail.com", StringComparison.OrdinalIgnoreCase))
        {
            Add(host, 587, true);
            Add(host, 465, true);
        }

        return endpoints;
    }

    private static SecureSocketOptions ResolveSocketOption(int port, bool enableSsl)
    {
        if (!enableSsl)
        {
            return SecureSocketOptions.None;
        }

        if (port == 465)
        {
            return SecureSocketOptions.SslOnConnect;
        }

        if (port == 587)
        {
            return SecureSocketOptions.StartTls;
        }

        return SecureSocketOptions.Auto;
    }

    private sealed record SmtpEndpoint(string Host, int Port, bool EnableSsl);

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
