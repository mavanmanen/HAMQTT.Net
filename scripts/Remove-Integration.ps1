<#
.SYNOPSIS
    Automates the removal of a HAMQTT Integration project.
.DESCRIPTION
    Removes reference and deletes directory.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$IntegrationName
)

$ErrorActionPreference = "Stop"

# --- Import Shared Functions & Assert Wrapper ---
. "$PSScriptRoot/Common-Utils.ps1"
Assert-HamqttWrapper

# --- Constants ---
$RootComposePath = Join-Path $ProjectRoot "src/docker-compose.dev.yml"
$SrcPath = Join-Path $ProjectRoot "src"

# --- 1. Identify Paths ---
$ProjectFolderName = "HAMQTT.Integration.${IntegrationName}"
$ProjectRelPath = Join-Path $SrcPath $ProjectFolderName

Write-Host "🗑️  Starting removal for '${IntegrationName}'..." -ForegroundColor Cyan

# --- 2. Update Root Docker Compose (Remove Include) ---
if (Test-Path $RootComposePath) {
    Write-Host "   🔗 Checking root compose file..." -ForegroundColor Yellow
    
    $Content = Get-Content $RootComposePath -Raw
    $IncludeString = "${ProjectFolderName}/docker-compose.dev.yml"
    
    $Lines = $Content -split "`r?`n"
    $NewLines = $Lines | Where-Object { -not ($_ -match [regex]::Escape($IncludeString)) }

    if ($Lines.Count -ne $NewLines.Count) {
        $NewLines -join "`n" | Set-Content -Path $RootComposePath
        Write-Host "   ✅ Removed include reference from ${RootComposePath}" -ForegroundColor Green
    } else {
        Write-Host "   ℹ️  No reference found in ${RootComposePath} (skipping)" -ForegroundColor Gray
    }
} else {
    Write-Warning "   ⚠️  Root compose file not found at ${RootComposePath}"
}

# --- 3. Remove Project Directory ---
if (Test-Path $ProjectRelPath) {
    Write-Host "   📂 Removing project directory..." -ForegroundColor Yellow
    try {
        Remove-Item -Path $ProjectRelPath -Recurse -Force -ErrorAction Stop
        Write-Host "   ✅ Deleted directory: ${ProjectRelPath}" -ForegroundColor Green
    }
    catch {
        Write-Error "   ❌ Failed to delete directory: $_"
    }
} else {
    Write-Host "   ℹ️  Directory not found: ${ProjectRelPath} (skipping)" -ForegroundColor Gray
}

# --- 4. Final Instructions ---
Write-Host "`n✨ Removal Complete!" -ForegroundColor Cyan
Write-Host "   ⚠️  To apply changes and remove the running container, run:" -ForegroundColor Gray
Write-Host "      docker-compose -f src/docker-compose.dev.yml up -d --remove-orphans" -ForegroundColor White