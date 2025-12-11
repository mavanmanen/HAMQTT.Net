using HomeAssistantDiscoveryNet;
using ToMqttNet;

namespace HAMQTT.Integration.IntegrationName;

internal sealed class IntegrationNameIntegration(IMqttConnectionService mqtt) : Integration(mqtt)
{
    private const string StateTopic = "integration-name/state";

    public override string CronExpression => "0 * * * *";
    protected override bool RunOnStartup => true;

    protected override MqttDeviceDiscoveryConfig GetDeviceDiscoveryConfig()
    {
        var config = new MqttDeviceDiscoveryConfig
        {
            Device = new MqttDiscoveryDevice
            {
                Name = "IntegrationName",
                Identifiers = ["mavanmanen_integration_name"],
                Manufacturer = "mavanmanen"
            },
            Origin = new MqttDiscoveryConfigOrigin
            {
                Name = "HAMQTT.Integration.IntegrationName"
            },
            StateTopic = StateTopic
        };

        return config;
    }

    public override async Task Invoke()
    {

    }
}