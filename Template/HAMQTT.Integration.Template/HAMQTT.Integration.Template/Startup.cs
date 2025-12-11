namespace HAMQTT.Integration.Template;

public class Startup : IntegrationStartup
{
    public override void RegisterServices(IServiceCollection services)
    {
        services.AddIntegration<IntegrationNameIntegration>();
    }
}