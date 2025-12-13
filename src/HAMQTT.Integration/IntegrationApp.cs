using System.Reflection;
using Coravel;
using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.Configuration;
using ToMqttNet;

namespace HAMQTT.Integration;

internal class IntegrationApp(string nodeId, string host, int? port, string username, string password, IntegrationStartup? startup) : IIntegrationApp
{
    private static WebApplication? _app;

    private WebApplicationBuilder CreateBuilder()
    {
        var builder = WebApplication.CreateSlimBuilder();
        builder.Configuration.AddEnvironmentVariables();
        builder.Configuration.AddUserSecrets(Assembly.GetEntryAssembly()!);
        builder.Services.AddMqttConnection().Configure(options =>
        {
            options.NodeId = nodeId;
            options.Server = host;
            options.Port = port ?? 1883;
            options.Username = username;
            options.Password = password;
        });
        builder.Services.AddScheduler();
        return builder;
    }

    public void Run()
    {
        var builder = CreateBuilder();
        startup?.RegisterServices(builder.Services);
        _app = builder.Build();
        _app.UseIntegrations();
        _app.Run();
    }
}