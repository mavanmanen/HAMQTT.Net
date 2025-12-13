<#
.SYNOPSIS
    Automates the removal of a HAMQTT Integration project.
.DESCRIPTION
    Removes reference and deletes directory.
#>

param (
# Changed to False to allow custom interactive prompt
    [Parameter(Mandatory = $false)]
    [string]$IntegrationName
)

$ErrorActionPreference = "Stop"

# --- Import Shared Functions & Assert Wrapper ---
. "$PSScriptRoot/Common-Utils.ps1"

# --- Constants ---
$RootComposePath = Join-Path $ProjectRoot "docker-compose.dev.yml"

# --- Interactive Mode ---
if ( [string]::IsNullOrWhiteSpace($IntegrationName))
{
    if (-not (Test-Path $ProjectRoot))
    {
        Write-Error "Source directory not found."
        exit 1
    }

    # Get list of integrations (excluding base project)
    $Integrations = Get-ChildItem -Path $ProjectRoot -Directory -Filter "HAMQTT.Integration.*" |
            Where-Object { $_.Name -ne "HAMQTT.Integration" }

    if ($Integrations.Count -eq 0)
    {
        Write-Warning "No integrations found to remove."
        exit 0
    }

    Write-Host "🗑️  Select an integration to remove:" -ForegroundColor Cyan

    $Map = @{ }
    $Index = 1

    foreach ($dir in $Integrations)
    {
        $CleanName = Get-CleanIntegrationName $dir.Name
        Write-Host "   [$Index] $CleanName"
        $Map[$Index] = $CleanName
        $Index++
    }

    $Selection = Read-Host "`n   > Enter number or name"

    # Validate Selection
    if ($Selection -match "^\d+$" -and $Map.ContainsKey([int]$Selection))
    {
        # User entered a valid number
        $IntegrationName = $Map[[int]$Selection]
    }
    elseif ($Integrations | Where-Object { (Get-CleanIntegrationName $_.Name) -eq $Selection })
    {
        # User entered a valid name
        $IntegrationName = $Selection
    }
    else
    {
        Write-Error "Invalid selection."
        exit 1
    }

    Write-Host "   Selected: $IntegrationName" -ForegroundColor Gray
}

# --- 1. Identify Paths ---
$ProjectFolderName = "HAMQTT.Integration.${IntegrationName}"
$ProjectRelPath = Join-Path $ProjectRoot $ProjectFolderName

Write-Host "🗑️  Starting removal for '${IntegrationName}'..." -ForegroundColor Cyan

# --- 2. Update Root Docker Compose (Remove Include) ---
if (Test-Path $RootComposePath)
{
    Write-Host "   🔗 Checking root compose file..." -ForegroundColor Yellow

    $Content = Get-Content $RootComposePath -Raw
    $IncludeString = "${ProjectFolderName}/docker-compose.dev.yml"

    $Lines = $Content -split "`r?`n"
    $NewLines = $Lines | Where-Object { -not ($_ -match [regex]::Escape($IncludeString)) }

    if ($Lines.Count -ne $NewLines.Count)
    {
        $NewLines -join "`n" | Set-Content -Path $RootComposePath
        Write-Host "   ✅ Removed include reference from ${RootComposePath}" -ForegroundColor Green
    }
    else
    {
        Write-Host "   ℹ️  No reference found in ${RootComposePath} (skipping)" -ForegroundColor Gray
    }
}
else
{
    Write-Warning "   ⚠️  Root compose file not found at ${RootComposePath}"
}

# --- 3. Remove Project Directory ---
if (Test-Path $ProjectRelPath)
{
    Write-Host "   📂 Removing project directory..." -ForegroundColor Yellow
    try
    {
        Remove-Item -Path $ProjectRelPath -Recurse -Force -ErrorAction Stop
        Write-Host "   ✅ Deleted directory: ${ProjectRelPath}" -ForegroundColor Green
    }
    catch
    {
        Write-Error "   ❌ Failed to delete directory: $_"
    }
}
else
{
    Write-Host "   ℹ️  Directory not found: ${ProjectRelPath} (skipping)" -ForegroundColor Gray
}

# --- 4. Final Instructions ---
Write-Host "`n✨ Removal Complete!" -ForegroundColor Cyan
Write-Host "   ⚠️  To apply changes and remove the running container, run:" -ForegroundColor Gray
Write-Host "      docker-compose -f docker-compose.dev.yml up -d --remove-orphans" -ForegroundColor White