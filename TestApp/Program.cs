using Elastic.Apm.NetCoreAll;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.UseAllElasticApm(builder.Configuration);

app.MapGet("/", () => "Hello World!");

app.Run();
