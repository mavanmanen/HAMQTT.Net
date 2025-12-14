using HAMQTT.Integration;

namespace IntegrationName;

public class Startup : IntegrationStartup
{
    public override void RegisterServices(IServiceCollection services)
    {
        services.AddIntegration<IntegrationNameIntegration>();
    }
}