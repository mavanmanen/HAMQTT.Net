using Microsoft.Extensions.DependencyInjection;

namespace HAMQTT.Integration;

public abstract class IntegrationStartup
{
    public abstract void RegisterServices(IServiceCollection services);
}