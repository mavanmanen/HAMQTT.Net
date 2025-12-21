using System.Text.Json;
using Coravel.Invocable;
using HomeAssistantDiscoveryNet;
using MQTTnet;
using MQTTnet.Protocol;
using ToMqttNet;

namespace HAMQTT.Integration;

public abstract class Integration(IMqttConnectionService mqtt)
{
    protected abstract bool RunOnStartup { get; }

    protected virtual MqttDeviceDiscoveryConfig? GetDeviceDiscoveryConfig() => null;

    private static readonly JsonSerializerOptions JsonSerializerOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        WriteIndented = false
    };

    protected async Task PublishAsync<T>(string topic, T payload) =>
        await mqtt.PublishAsync(new MqttApplicationMessageBuilder()
            .WithTopic(topic)
            .WithPayload(JsonSerializer.Serialize(payload, JsonSerializerOptions))
            .WithQualityOfServiceLevel(MqttQualityOfServiceLevel.AtLeastOnce)
            .Build());

    internal async Task PublishDiscoveryDocumentAsync()
    {
        var deviceConfig = GetDeviceDiscoveryConfig();
        if (deviceConfig == null)
        {
            return;
        }

        var uniqueIdProperty = typeof(MqttDiscoveryConfig).GetProperty("UniqueId")!;

        foreach (var (key, obj) in deviceConfig.Components)
        {
            uniqueIdProperty.SetValue(obj, key);
        }

        await mqtt.PublishDiscoveryDocument(deviceConfig);

        if (this is CronIntegration cronIntegration && RunOnStartup)
        {
            await cronIntegration.Invoke();
        }
    }
}

public abstract class CronIntegration(IMqttConnectionService mqtt) : Integration(mqtt), IInvocable
{
    public abstract string CronExpression { get; }
    public abstract Task Invoke();
}

public abstract class MqttIntegration(IMqttConnectionService mqtt) : Integration(mqtt)
{
    public abstract string Topic { get; }
    public abstract Task Invoke(MqttApplicationMessage messageApplicationMessage);
}