<#
.SYNOPSIS
    Scaffolds a fresh HAMQTT project repository.
.DESCRIPTION
    Generates the root infrastructure Docker Compose file.
#>

$ErrorActionPreference = "Stop"

# --- Import Shared Functions & Assert Wrapper ---
. "$PSScriptRoot/Common-Utils.ps1"
Assert-HamqttWrapper

# --- Constants ---
$SrcPath = Join-Path $ProjectRoot "src"
$EnvFilePath = Join-Path $ProjectRoot "src/.env"
$HaConfigPath = Join-Path $ProjectRoot "src/ha_config"
$RootComposePath = Join-Path $ProjectRoot "src/docker-compose.dev.yml"

Write-Host "🚀 Starting Project Initialization..." -ForegroundColor Cyan

# --- 0. Ensure Source Directory Exists ---
if (-not (Test-Path $SrcPath)) {
    New-Item -ItemType Directory -Path $SrcPath -Force | Out-Null
    Write-Host "   📂 Created source directory: src/" -ForegroundColor Gray
}

# --- 1. Create .NET Solution File ---
Write-Host "`n📄 Configuring Solution..." -ForegroundColor Yellow

# Check if a .sln already exists
$ExistingSln = Get-ChildItem -Path $SrcPath -Filter "*.sln" | Select-Object -First 1

if ($ExistingSln) {
    Write-Host "   ℹ️  Solution file already exists: $($ExistingSln.Name). Skipping." -ForegroundColor Gray
} else {
    # Default name = Current Directory Name
    $DefaultName = Split-Path $ProjectRoot -Leaf
    
    Write-Host "   Enter a name for the solution file (Default: $DefaultName)" -ForegroundColor Cyan
    $SlnNameInput = Read-Host "   > Name"

    if ([string]::IsNullOrWhiteSpace($SlnNameInput)) {
        $SlnName = $DefaultName
    } else {
        $SlnName = $SlnNameInput
    }

    try {
        dotnet new sln -n $SlnName -o $SrcPath | Out-Null
        Write-Host "   ✅ Created solution: $SlnName.sln" -ForegroundColor Green
    } catch {
        Write-Error "   ❌ Failed to create solution file: $_"
    }
}

# --- 2. Configure Credentials & .env ---
Write-Host "`n🔑 Configuring Credentials..." -ForegroundColor Yellow

# 2a. Load existing .env if present
$EnvContent = @{}
if (Test-Path $EnvFilePath) {
    Get-Content $EnvFilePath | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") { $EnvContent[$matches[1]] = $matches[2] }
    }
}

# 2b. Default Values
if (-not $EnvContent.ContainsKey("MQTT_HOST")) { $EnvContent["MQTT_HOST"] = "mosquitto" }
if (-not $EnvContent.ContainsKey("MQTT_USERNAME")) { $EnvContent["MQTT_USERNAME"] = "mqtt" }
if (-not $EnvContent.ContainsKey("MQTT_PASSWORD")) { $EnvContent["MQTT_PASSWORD"] = "password" }

# 2c. Prompt for GitHub Credentials (Required for NuGet & Docker Build)
if (-not $EnvContent.ContainsKey("GITHUB_USERNAME") -or [string]::IsNullOrWhiteSpace($EnvContent["GITHUB_USERNAME"])) {
    Write-Host "   👤 GitHub Username is required for package access." -ForegroundColor Cyan
    $UserInput = Read-Host "   > Username"
    if (-not [string]::IsNullOrWhiteSpace($UserInput)) { $EnvContent["GITHUB_USERNAME"] = $UserInput }
}

if (-not $EnvContent.ContainsKey("GITHUB_PAT") -or [string]::IsNullOrWhiteSpace($EnvContent["GITHUB_PAT"])) {
    Write-Host "   🔑 GitHub Personal Access Token (PAT) is required." -ForegroundColor Cyan
    Write-Host "      (Permissions required: read:packages)" -ForegroundColor Gray
    $PatInput = Read-Host "   > PAT"
    if (-not [string]::IsNullOrWhiteSpace($PatInput)) { $EnvContent["GITHUB_PAT"] = $PatInput }
}

# 2d. Configure Local NuGet Source
if ($EnvContent["GITHUB_USERNAME"] -and $EnvContent["GITHUB_PAT"]) {
    $SourceName = "github-mavanmanen"
    $SourceUrl = "https://nuget.pkg.github.com/mavanmanen/index.json"
    
    Write-Host "   📦 Configuring local NuGet source '$SourceName'..." -ForegroundColor Gray
    try {
        # Check if source exists
        $SourceList = dotnet nuget list source | Out-String
        if ($SourceList -match $SourceName) {
             # Update existing
             dotnet nuget update source $SourceName `
                --username $EnvContent["GITHUB_USERNAME"] `
                --password $EnvContent["GITHUB_PAT"] `
                --store-password-in-clear-text | Out-Null
             Write-Host "      ✅ Updated existing NuGet source." -ForegroundColor Green
        } else {
             # Add new
             dotnet nuget add source $SourceUrl `
                --name $SourceName `
                --username $EnvContent["GITHUB_USERNAME"] `
                --password $EnvContent["GITHUB_PAT"] `
                --store-password-in-clear-text | Out-Null
             Write-Host "      ✅ Added new NuGet source." -ForegroundColor Green
        }
    } catch {
        Write-Warning "      ⚠️  Failed to configure NuGet source: $_"
    }
}

# 2e. Save .env file
$FinalEnvContent = $EnvContent.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
$FinalEnvContent | Set-Content -Path $EnvFilePath
Write-Host "   ✅ Environment variables saved to: $EnvFilePath" -ForegroundColor Green


# --- 3. Initialize Root Compose (Infrastructure) ---
Write-Host "`n🏗️  Configuring Infrastructure..." -ForegroundColor Yellow

if (-not (Test-Path $RootComposePath)) {
    $RootComposeContent = @'
# Location: src/docker-compose.dev.yml
# This file manages the shared infrastructure (Mosquitto, Home Assistant) and includes integrations.

include:
  # New-Integration.ps1 will append new projects here

services:
  # The Shared MQTT Broker
  mosquitto:
    image: eclipse-mosquitto:2
    container_name: mqtt_broker
    restart: unless-stopped
    ports:
      - "1883:1883"
    # Load .env from same directory (src/)
    env_file:
      - .env
    # Dynamically create config and password file on startup
    command: >
      sh -c "echo 'per_listener_settings true' > /mosquitto/config/mosquitto.conf &&
             echo 'listener 1883' >> /mosquitto/config/mosquitto.conf &&
             echo 'allow_anonymous false' >> /mosquitto/config/mosquitto.conf &&
             echo 'password_file /mosquitto/config/passwd' >> /mosquitto/config/mosquitto.conf &&
             touch /mosquitto/config/passwd &&
             chmod 0700 /mosquitto/config/passwd &&
             mosquitto_passwd -b /mosquitto/config/passwd ${MQTT_USERNAME} ${MQTT_PASSWORD} &&
             /usr/sbin/mosquitto -c /mosquitto/config/mosquitto.conf"
    networks:
      - hamqtt-integration_network

  # Home Assistant (Local Dev)
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      # Map config from src/ha_config (sibling directory)
      - ./ha_config:/config
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    ports:
      - "8123:8123"
    networks:
      - hamqtt-integration_network
    depends_on:
      - mosquitto

networks:
  hamqtt-integration_network:
    name: hamqtt-integration_network
    driver: bridge
'@
    $RootComposeContent | Set-Content -Path $RootComposePath
    Write-Host "   ✅ Created root infrastructure compose file: $RootComposePath" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Root compose file already exists. Skipping." -ForegroundColor Gray
}

# --- 4. Initialize Home Assistant Config ---
Write-Host "`n🏠 Configuring Home Assistant..." -ForegroundColor Yellow
if (-not (Test-Path $HaConfigPath)) {
    New-Item -ItemType Directory -Path $HaConfigPath -Force | Out-Null
    
    $HaYaml = @"
default_config:

homeassistant:
  auth_providers:
    - type: homeassistant # Keep the default Home Assistant authentication provider
    - type: trusted_networks
      trusted_networks:
        - 192.168.1.0/24 # Example: Allow all devices on the 192.168.1.x subnet
        - 172.17.0.0/16  # Docker default bridge network
        - 172.18.0.0/16  # Additional Docker networks if needed
        - 127.0.0.1      # Always include localhost
        - ::1            # Include IPv6 localhost if applicable
      allow_bypass_login: true

group: !include groups.yaml
automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
"@
    $HaYaml | Set-Content -Path (Join-Path $HaConfigPath "configuration.yaml")
    "" | Set-Content -Path (Join-Path $HaConfigPath "automations.yaml")
    "" | Set-Content -Path (Join-Path $HaConfigPath "scripts.yaml")
    "" | Set-Content -Path (Join-Path $HaConfigPath "scenes.yaml")
    "" | Set-Content -Path (Join-Path $HaConfigPath "groups.yaml")
    
    Write-Host "   ✅ Created default Home Assistant configuration in src/ha_config." -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Home Assistant config already exists. Skipping." -ForegroundColor Gray
}

# --- 5. Install Template ---
Write-Host "`n📦 Verifying Template..." -ForegroundColor Yellow

# Delegate template installation logic to the main wrapper
$HamqttScript = Join-Path $ProjectRoot "hamqtt.ps1"
& $HamqttScript template install

Write-Host "`n✨ Initialization Complete!" -ForegroundColor Cyan
Write-Host "   👉 You can now run 'hamqtt integrations new' to add your first integration." -ForegroundColor Gray