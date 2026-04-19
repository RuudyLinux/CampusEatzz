using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Options;
using UniversityCanteen.Api.Configuration;
using LocalFcmOptions = UniversityCanteen.Api.Configuration.FcmOptions;

namespace UniversityCanteen.Api.Services;

public sealed class FirebaseFcmPushSender(
    IOptions<LocalFcmOptions> fcmOptions,
    IWebHostEnvironment environment,
    ILogger<FirebaseFcmPushSender> logger) : IFcmPushSender
{
    private readonly LocalFcmOptions _options = fcmOptions.Value;
    private readonly SemaphoreSlim _initLock = new(1, 1);

    private FirebaseApp? _firebaseApp;
    private bool _initAttempted;
    private string? _disabledReason;

    public async Task<FcmSendResult> SendToTokensAsync(
        string title,
        string body,
        IReadOnlyDictionary<string, string> data,
        IReadOnlyCollection<string> tokens,
        CancellationToken cancellationToken)
    {
        if (tokens.Count == 0)
        {
            return FcmSendResult.Empty();
        }

        await EnsureInitializedAsync(cancellationToken);

        if (_firebaseApp is null)
        {
            return FcmSendResult.Disabled(_disabledReason ?? "FCM is not configured.");
        }

        try
        {
            var message = new MulticastMessage
            {
                Tokens = tokens.Distinct(StringComparer.Ordinal).ToList(),
                Notification = new Notification
                {
                    Title = title,
                    Body = body,
                },
                Data = data.ToDictionary(kv => kv.Key, kv => kv.Value, StringComparer.Ordinal),
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        ChannelId = string.IsNullOrWhiteSpace(_options.AndroidChannelId)
                            ? "campuseatzz_updates"
                            : _options.AndroidChannelId.Trim(),
                        ClickAction = "FLUTTER_NOTIFICATION_CLICK"
                    }
                },
                Apns = new ApnsConfig
                {
                    Aps = new Aps
                    {
                        Sound = "default"
                    }
                }
            };

            var response = await FirebaseMessaging.GetMessaging(_firebaseApp)
                .SendEachForMulticastAsync(message, cancellationToken);

            return new FcmSendResult
            {
                Enabled = true,
                SuccessCount = response.SuccessCount,
                FailureCount = response.FailureCount,
                Error = response.FailureCount > 0
                    ? "One or more devices failed to receive the notification."
                    : null
            };
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "FCM send failed for {TokenCount} tokens.", tokens.Count);
            return new FcmSendResult
            {
                Enabled = true,
                SuccessCount = 0,
                FailureCount = tokens.Count,
                Error = ex.Message
            };
        }
    }

    private async Task EnsureInitializedAsync(CancellationToken cancellationToken)
    {
        if (_initAttempted)
        {
            return;
        }

        await _initLock.WaitAsync(cancellationToken);
        try
        {
            if (_initAttempted)
            {
                return;
            }

            _initAttempted = true;

            if (!_options.Enabled)
            {
                _disabledReason = "FCM is disabled in configuration.";
                logger.LogWarning("FCM notifications are disabled. Set Fcm:Enabled=true to enable push delivery.");
                return;
            }

            var configuredPath = (_options.ServiceAccountJsonPath ?? string.Empty).Trim();
            if (string.IsNullOrWhiteSpace(configuredPath))
            {
                _disabledReason = "Fcm:ServiceAccountJsonPath is missing.";
                logger.LogWarning("FCM service account path is missing. Push notifications will be stored but not delivered.");
                return;
            }

            var resolvedPath = Path.IsPathRooted(configuredPath)
                ? configuredPath
                : Path.Combine(environment.ContentRootPath, configuredPath);

            if (!File.Exists(resolvedPath))
            {
                _disabledReason = $"FCM service account file not found: {resolvedPath}";
                logger.LogWarning("FCM service account file not found at {Path}.", resolvedPath);
                return;
            }

            FirebaseApp? existingApp = null;
            try
            {
                existingApp = FirebaseApp.DefaultInstance;
            }
            catch
            {
                existingApp = null;
            }

            if (existingApp is not null)
            {
                _firebaseApp = existingApp;
                logger.LogInformation("Using existing default Firebase app instance for push notifications.");
                return;
            }

            var credential = GoogleCredential.FromFile(resolvedPath);
            _firebaseApp = FirebaseApp.Create(new AppOptions
            {
                Credential = credential,
                ProjectId = string.IsNullOrWhiteSpace(_options.ProjectId) ? null : _options.ProjectId.Trim()
            });

            logger.LogInformation("FCM push sender initialized successfully.");
        }
        catch (Exception ex)
        {
            _disabledReason = ex.Message;
            logger.LogError(ex, "Failed to initialize FCM push sender.");
        }
        finally
        {
            _initLock.Release();
        }
    }
}
