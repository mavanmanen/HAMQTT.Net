using Coravel;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using ToMqttNet;

namespace HAMQTT.Integration;

public static class Extensions
{
    public static void AddIntegration<T>(this IServiceCollection services) where T : Integration
    {
        services.AddSingleton<Integration, T>();
        services.AddTransient<T>();
    }
    
    public static void UseIntegrations(this WebApplication app)
    {
        var mqtt = app.Services.GetRequiredService<IMqttConnectionService>();
        var integrations = app.Services.GetServices<Integration>().ToList();

        mqtt.OnConnectAsync += async _ =>
        {
            foreach (var integration in integrations)
            {
                await integration.PublishDiscoveryDocumentAsync();
                
                app.Services.UseScheduler(scheduler =>
                    scheduler.ScheduleInvocableType(integration.GetType()).Cron(integration.CronExpression)).LogScheduledTaskProgress();
            }
        };
    }
}