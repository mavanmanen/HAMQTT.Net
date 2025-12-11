namespace HAMQTT.Integration.IntegrationName;

public class Startup : IntegrationStartup
{
    public override void RegisterServices(IServiceCollection services)
    {
        services.AddIntegration<IntegrationNameIntegration>();
    }
}