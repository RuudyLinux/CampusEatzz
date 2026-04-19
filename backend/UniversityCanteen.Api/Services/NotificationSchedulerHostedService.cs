namespace UniversityCanteen.Api.Services;

public sealed class NotificationSchedulerHostedService(
    IServiceProvider serviceProvider,
    ILogger<NotificationSchedulerHostedService> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = serviceProvider.CreateScope();
                var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();
                var processed = await notificationService.DispatchDueScheduledAsync(stoppingToken);
                if (processed > 0)
                {
                    logger.LogInformation("Processed {Count} scheduled notifications.", processed);
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Scheduled notification dispatcher failed.");
            }

            try
            {
                await Task.Delay(TimeSpan.FromSeconds(45), stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
        }
    }
}
