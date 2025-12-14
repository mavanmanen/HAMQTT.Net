<#
.SYNOPSIS
    Generates a production-ready single docker-compose file.
#>

param (
# Defaults to the repository root
    [string]$OutputDirectory,
    [string]$ImageBaseUrl = "ghcr.io/mavanmanen/hamqtt.net",
    [string]$ProjectRoot,

    [Parameter(Mandatory = $false)]
    [string]$MqttHost,

    [Parameter(Mandatory = $false)]
    [string]$MqttUsername,

    [Parameter(Mandatory = $false)]
    [string]$MqttPassword
)

$ErrorActionPreference = "Stop"

# --- Import Shared Functions & Assert Wrapper ---
. "$PSScriptRoot/Common-Utils.ps1"

# --- Prompt for Credentials if Missing ---
if ([string]::IsNullOrWhiteSpace($MqttHost)) {
    $MqttHost = Read-Host "Enter MQTT Host"
}

if ([string]::IsNullOrWhiteSpace($MqttUsername)) {
    $MqttUsername = Read-Host "Enter MQTT Username"
}

if ([string]::IsNullOrWhiteSpace($MqttPassword)) {
    $MqttPassword = Read-Host -AsSecureString "Enter MQTT Password"
    $MqttPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($MqttPassword))
}

# --- Constants ---
if ( [string]::IsNullOrEmpty($OutputDirectory))
{
    $OutputDirectory = $ProjectRoot
}

# --- 1. Prepare Output Directory ---
if (-not (Test-Path $OutputDirectory))
{
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
Write-Host "🚀 Starting deployment generation in '$OutputDirectory'..." -ForegroundColor Cyan

# --- 3. Scan for Integrations ---
Write-Host "   🔍 Scanning for integrations..." -ForegroundColor Yellow
$Integrations = Get-ChildItem -Path $ProjectRoot -Directory -Filter "HAMQTT.Integration.*"

if ($Integrations.Count -eq 0)
{
    Write-Warning "   ⚠️  No integrations found."
}

# --- 4. Build Docker Compose Content ---
$ServicesYaml = ""

foreach ($dir in $Integrations)
{
    # Ignore the base library project
    if ($dir.Name -eq "HAMQTT.Integration")
    {
        continue
    }

    # Skip if not a valid project (must have a compose file)
    $ProjectComposePath = Join-Path $dir.FullName "docker-compose.dev.yml"
    if (-not (Test-Path $ProjectComposePath))
    {
        continue
    }

    # Use regex anchor ^ and escape the dots \. to correctly remove the prefix
    $CleanName = $dir.Name -replace "^HAMQTT\.Integration\.", ""
    $KebabName = Get-KebabCase $CleanName
    $ImageUrl = "${ImageBaseUrl}/${KebabName}:latest"

    Write-Host "      Found: $CleanName -> Image: $ImageUrl" -ForegroundColor Gray

    $ServicesYaml += @"
  hamqtt-integration-${KebabName}:
    container_name: hamqtt-integration-${KebabName}
    image: ${ImageUrl}
    restart: unless-stopped
    network_mode: bridge
    environment:
      <<: *environment
"@

    $envFilePath = Join-Path $dir.FullName ".env"
    $envFileContent = Get-Content -Path $envFilePath -ErrorAction SilentlyContinue
    foreach($line in $envFileContent)
    {
        $ServicesYaml += "`r`n      " + ($line -replace "=", ": ")
    }
}

# --- 5. Assemble Final File ---
$FinalCompose = @"
version: '3.8'

x-env: &environment
  MQTT_HOST: ${MqttHost}
  MQTT_USERNAME: ${MqttUsername}
  MQTT_PASSWORD: ${MqttPassword}

services:
$ServicesYaml
"@

$TargetComposePath = Join-Path $OutputDirectory "docker-compose.yml"
$FinalCompose | Set-Content -Path $TargetComposePath
Write-Host "   ✅ Generated docker-compose.yml." -ForegroundColor Green

Write-Host "`n✨ Deployment files ready in '$OutputDirectory'!" -ForegroundColor Cyan