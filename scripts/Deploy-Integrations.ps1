<#
.SYNOPSIS
    Generates a production-ready single docker-compose file.
#>

param (
    # Defaults to the repository root
    [string]$OutputDirectory,
    [string]$ImageBaseUrl = "ghcr.io/mavanmanen/hamqtt"
)

$ErrorActionPreference = "Stop"

# --- Import Shared Functions & Assert Wrapper ---
. "$PSScriptRoot/Common-Utils.ps1"
Assert-HamqttWrapper

# --- Constants ---
if ([string]::IsNullOrEmpty($OutputDirectory)) {
    $OutputDirectory = $ProjectRoot
}

$SrcPath = Join-Path $ProjectRoot "src"

# --- 1. Prepare Output Directory ---
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}
Write-Host "🚀 Starting deployment generation in '$OutputDirectory'..." -ForegroundColor Cyan

# --- 2. Generate Production .env (Conditional) ---
$TargetEnvPath = Join-Path $OutputDirectory ".env"

if (-not (Test-Path $TargetEnvPath)) {
    $EnvContent = @"
MQTT_HOST=
MQTT_USERNAME=
MQTT_PASSWORD=
"@
    $EnvContent | Set-Content -Path $TargetEnvPath
    Write-Host "   ✅ Generated new .env template." -ForegroundColor Green
} else {
    Write-Host "   ℹ️  Existing .env found. Skipping update to preserve credentials." -ForegroundColor Gray
}

# --- 3. Scan for Integrations ---
Write-Host "   🔍 Scanning 'src' for integrations..." -ForegroundColor Yellow
$Integrations = Get-ChildItem -Path $SrcPath -Directory -Filter "HAMQTT.Integration.*"

if ($Integrations.Count -eq 0) {
    Write-Warning "   ⚠️  No integrations found in src/ folder."
}

# --- 4. Build Docker Compose Content ---
$ServicesYaml = ""

foreach ($dir in $Integrations) {
    # Ignore the base library project
    if ($dir.Name -eq "HAMQTT.Integration") { continue }

    # Skip if not a valid project (must have a compose file)
    $ProjectComposePath = Join-Path $dir.FullName "docker-compose.dev.yml"
    if (-not (Test-Path $ProjectComposePath)) {
        continue
    }

    # Use shared function to get clean name
    $CleanName = Get-CleanIntegrationName $dir.Name
    $KebabName = Get-KebabCase $CleanName
    $ImageUrl = "${ImageBaseUrl}/${KebabName}:latest"

    Write-Host "      Found: $CleanName -> Image: $ImageUrl" -ForegroundColor Gray

    $ServicesYaml += @"
  hamqtt-integration-${KebabName}:
    image: ${ImageUrl}
    restart: unless-stopped
    network_mode: bridge
    env_file:
      - .env

"@
}

# --- 5. Assemble Final File ---
$FinalCompose = @"
version: '3.8'

services:
$ServicesYaml
"@

$TargetComposePath = Join-Path $OutputDirectory "docker-compose.yml"
$FinalCompose | Set-Content -Path $TargetComposePath
Write-Host "   ✅ Generated docker-compose.yml." -ForegroundColor Green

Write-Host "`n✨ Deployment files ready in '$OutputDirectory'!" -ForegroundColor Cyan