FROM mcr.microsoft.com/dotnet/aspnet-alpine:10.0 AS base
USER $APP_UID
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk-alpine:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["HAMQTT.Integration.Oxxio/HAMQTT.Integration.Oxxio.csproj", "HAMQTT.Integration.Oxxio/"]
COPY ["HAMQTT.Integration/HAMQTT.Integration.csproj", "HAMQTT.Integration/"]
RUN dotnet restore "HAMQTT.Integration.Oxxio/HAMQTT.Integration.Oxxio.csproj"
COPY . .
WORKDIR "/src/HAMQTT.Integration.Oxxio"
RUN dotnet build "./HAMQTT.Integration.Oxxio.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./HAMQTT.Integration.Oxxio.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "HAMQTT.Integration.Oxxio.dll"]
