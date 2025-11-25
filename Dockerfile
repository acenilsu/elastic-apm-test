FROM mcr.microsoft.com/dotnet/aspnet:7.0

COPY ./ElasticApmAgentStartupHook.dll /app/ElasticApmAgent/
COPY ./ElasticApmAgentStartupHook.pdb /app/ElasticApmAgent/
COPY ./TestApp/publish /app/TestApp

WORKDIR /app/TestApp

ENV DOTNET_STARTUP_HOOKS=/app/ElasticApmAgent/ElasticApmAgentStartupHook.dll
ENV ELASTIC_APM_SERVER_URLS=http://host.docker.internal:8200
ENV ELASTIC_APM_SERVICE_NAME=TestApp
ENV ELASTIC_APM_LOG_LEVEL=debug

CMD ["dotnet", "TestApp.dll"]