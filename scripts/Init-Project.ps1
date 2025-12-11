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
$EnvFilePath = Join-Path $ProjectRoot "src/.env"
# CHANGED: ha_config is now located in src/
$HaConfigPath = Join-Path $ProjectRoot "src/ha_config"
$RootComposePath = Join-Path $ProjectRoot "src/docker-compose.dev.yml"

Write-Host "🚀 Starting Project Initialization..." -ForegroundColor Cyan

# --- 1. Initialize .env File ---
Write-Host "`n📝 Configuring Environment Variables..." -ForegroundColor Yellow

if (-not (Test-Path $EnvFilePath)) {
    # CHANGED: Write all variables at once with explicit newlines to ensure proper formatting
    $DefaultEnvContent = @"
MQTT_HOST=mosquitto
MQTT_USERNAME=mqtt
MQTT_PASSWORD=password
"@
    $DefaultEnvContent | Set-Content -Path $EnvFilePath
    Write-Host "   ✅ Created .env file at: $EnvFilePath" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  .env file already exists. Skipping." -ForegroundColor Gray
}

# --- 2. Initialize Root Compose (Infrastructure) ---
Write-Host "`n🏗️  Configuring Infrastructure..." -ForegroundColor Yellow

if (-not (Test-Path $RootComposePath)) {
    $RootComposeContent = @"
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
      - "9001:9001"
    # Load .env from same directory (src/)
    env_file:
      - .env
    environment:
      - MQTT_USERNAME
      - MQTT_PASSWORD
    # Dynamically create config and password file on startup
    command: >
      sh -c "echo 'per_listener_settings true' > /mosquitto/config/mosquitto.conf &&
             echo 'listener 1883' >> /mosquitto/config/mosquitto.conf &&
             echo 'allow_anonymous false' >> /mosquitto/config/mosquitto.conf &&
             echo 'password_file /mosquitto/config/passwd' >> /mosquitto/config/mosquitto.conf &&
             touch /mosquitto/config/passwd &&
             mosquitto_passwd -b /mosquitto/config/passwd \$\${MQTT_USERNAME} \$\${MQTT_PASSWORD} &&
             /usr/sbin/mosquitto -c /mosquitto/config/mosquitto.conf"
    networks:
      - hamqtt-integration_network
    volumes:
      - mosquitto_data:/mosquitto/data
      - mosquitto_log:/mosquitto/log

  # Home Assistant (Local Dev)
  homeassistant:
    container_name: homeassistant
    image: "ghcr.io/home-assistant/home-assistant:stable"
    volumes:
      # CHANGED: Map config from src/ha_config (sibling directory)
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

volumes:
  mosquitto_data:
  mosquitto_log:
"@
    $RootComposeContent | Set-Content -Path $RootComposePath
    Write-Host "   ✅ Created root infrastructure compose file: $RootComposePath" -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Root compose file already exists. Skipping." -ForegroundColor Gray
}

# --- 3. Initialize Home Assistant Config ---
Write-Host "`n🏠 Configuring Home Assistant..." -ForegroundColor Yellow
if (-not (Test-Path $HaConfigPath)) {
    New-Item -ItemType Directory -Path $HaConfigPath -Force | Out-Null
    
    $HaYaml = @"
default_config:
tts:
  - platform: google_translate
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

Write-Host "`n✨ Initialization Complete!" -ForegroundColor Cyan
Write-Host "   👉 You can now run 'hamqtt integrations new' to add your first integration." -ForegroundColor Gray