using HAMQTT.Integration;
using IntegrationName;

var host = Environment.GetEnvironmentVariable("MQTT_HOST");
var username = Environment.GetEnvironmentVariable("MQTT_USERNAME");
var password = Environment.GetEnvironmentVariable("MQTT_PASSWORD");
var nodeId = Environment.GetEnvironmentVariable("MQTT_NODE_ID");

var builder = new IntegrationAppBuilder()
    .WithHost(host)
    .WithNodeId(nodeId)
    .WithCredentials(username, password)
    .WithStartup<Startup>();

var app = builder.Build();
app.Run();