using System.ComponentModel.DataAnnotations;
using System.Diagnostics.CodeAnalysis;

namespace HAMQTT.Integration;

public class IntegrationAppBuilder
{
    private string? _mqttNodeId;
    private string? _mqttHost;
    private int? _mqttPort;
    private string? _mqttUsername;
    private string? _mqttPassword;
    private IntegrationStartup? _startup;

    public IntegrationAppBuilder WithNodeId(string nodeId)
    {
        _mqttNodeId = nodeId;
        return this;
    }

    public IntegrationAppBuilder WithHost(string host)
    {
        _mqttHost = host;
        return this;
    }

    public IntegrationAppBuilder WithPort(int port)
    {
        _mqttPort = port;
        return this;
    }

    public IntegrationAppBuilder WithCredentials(string username, string password)
    {
        _mqttUsername = username;
        _mqttPassword = password;
        return this;
    }

    public IntegrationAppBuilder WithStartup<TStartup>() where TStartup : IntegrationStartup, new()
    {
        _startup = new TStartup();
        return this;
    }

    private static void Validate([NotNull] object? value, string property)
    {
        if (value == null)
        {
            throw new ValidationException($"{property} must be set!");
        }
    }

    public IIntegrationApp Build()
    {
        Validate(_mqttNodeId, "NodeId");
        Validate(_mqttHost, "Host");
        Validate(_mqttUsername, "Username");
        Validate(_mqttPassword, "Password");

        return new IntegrationApp(_mqttNodeId, _mqttHost, _mqttPort, _mqttUsername, _mqttPassword, _startup);
    }
}