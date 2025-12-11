FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
USER $APP_UID
WORKDIR /app

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["HAMQTT.Integration.Template/HAMQTT.Integration.Template.csproj", "HAMQTT.Integration.Template/"]
COPY ["HAMQTT.Integration/HAMQTT.Integration.csproj", "HAMQTT.Integration/"]
RUN dotnet restore "HAMQTT.Integration.Template/HAMQTT.Integration.Template.csproj"
COPY . .
WORKDIR "/src/HAMQTT.Integration.Template"
RUN dotnet build "./HAMQTT.Integration.Template.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./HAMQTT.Integration.Template.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "HAMQTT.Integration.Template.dll"]
