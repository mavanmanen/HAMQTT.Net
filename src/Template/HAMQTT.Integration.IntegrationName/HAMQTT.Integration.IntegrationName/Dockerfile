FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS base
USER $APP_UID
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

ARG GITHUB_USERNAME
ARG GITHUB_PAT

RUN dotnet nuget add source "https://nuget.pkg.github.com/mavanmanen/index.json" \
    --name "github-mavanmanen" \
    --store-password-in-clear-text \
    --username "$GITHUB_USERNAME" \
    --password "$GITHUB_PAT"

COPY ["HAMQTT.Integration.IntegrationName/HAMQTT.Integration.IntegrationName.csproj", "HAMQTT.Integration.IntegrationName/"]
RUN dotnet restore "HAMQTT.Integration.IntegrationName/HAMQTT.Integration.IntegrationName.csproj"
COPY . .
WORKDIR "/src/HAMQTT.Integration.IntegrationName"
RUN dotnet build "./HAMQTT.Integration.IntegrationName.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./HAMQTT.Integration.IntegrationName.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "HAMQTT.Integration.IntegrationName.dll"]
