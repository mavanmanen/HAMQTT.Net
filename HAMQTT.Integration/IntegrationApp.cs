using Coravel;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using ToMqttNet;

namespace HAMQTT.Integration;

public static class IntegrationApp
{
    private static  WebApplication? _app;

    private static WebApplicationBuilder CreateBuilder()
    {
        var builder = WebApplication.CreateSlimBuilder();
        builder.Configuration.AddEnvironmentVariables();
        builder.Services.AddMqttConnection().Configure(options =>
        {
            options.NodeId = builder.Configuration["MQTT_NODE_ID"]!;
            options.Server = builder.Configuration["MQTT_HOST"];
            options.Port = builder.Configuration.GetValue<int?>("MQTT_PORT") ?? 1883;
            options.Username = builder.Configuration["MQTT_USERNAME"];
            options.Password = builder.Configuration["MQTT_PASSWORD"];
        });
        builder.Services.AddScheduler();
        return builder;
    }

    private static void Run(WebApplicationBuilder builder)
    {
        _app = builder.Build();
        _app.UseIntegrations();
        _app.Run();
    }
    
    public static void Run()
    {
        var builder = CreateBuilder();
        Run(builder);
    }

    public static void Run<TStartup>() where TStartup : IntegrationStartup, new()
    {
        var builder = CreateBuilder();
        new TStartup().RegisterServices(builder.Services);
        Run(builder);
    }
}