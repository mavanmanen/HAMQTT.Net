<#
.SYNOPSIS
    Lists all HAMQTT Integration projects and their deployment status.
.DESCRIPTION
    Scans and compares dev/prod compose files.
#>

$ErrorActionPreference = "Stop"

# --- Import Shared Functions & Assert Wrapper ---
. "$PSScriptRoot/Common-Utils.ps1"

# --- Constants ---
$DevComposePath = Join-Path $ProjectRoot "docker-compose.dev.yml"
$ProdComposePath = Join-Path $ProjectRoot "docker-compose.yml"

# --- 1. Gather Data ---
if (-not (Test-Path $ProjectRoot))
{
    Write-Warning "Source directory not found at $ProjectRoot"
    return
}

$Integrations = Get-ChildItem -Path $ProjectRoot -Directory -Filter "HAMQTT.Integration.*"

if ($Integrations.Count -eq 0)
{
    Write-Host "No integrations found on disk." -ForegroundColor Gray
    return
}

# --- 2. Parse Dev Compose (Includes) ---
$DevIncludes = @()
if (Test-Path $DevComposePath)
{
    $DevContent = Get-Content $DevComposePath -Raw
    if ($DevContent -match "(?ms)^include:\s*(.*?)(^services:|\Z)")
    {
        $DevIncludes = $matches[1] -split "`r?`n" | Where-Object { $_.Trim().StartsWith("-") }
    }
}

# --- 3. Parse Prod Compose (Services) ---
$ProdServices = @()
if (Test-Path $ProdComposePath)
{
    # CHANGED: Removed -Raw to read as array of lines.
    # This ensures the regex ^ anchor matches the start of every line, not just the start of the file.
    $ProdContent = Get-Content $ProdComposePath
    $ProdServices = $ProdContent | Select-String -Pattern "^\s+hamqtt-integration-([a-zA-Z0-9-]+):" | ForEach-Object { $_.Matches.Groups[1].Value }
}

# --- 4. Build Status Table ---
$StatusList = @()

foreach ($dir in $Integrations)
{
    # Ignore the base library project
    if ($dir.Name -eq "HAMQTT.Integration")
    {
        continue
    }

    # Use shared function to get clean name
    $CleanName = Get-CleanIntegrationName $dir.Name
    $KebabName = Get-KebabCase $CleanName

    # Check Dev Status
    # We check if the expected line exists in the root compose file.
    # We do NOT skip if the local file is missing; we simply report it as not configured (Orphaned).
    $ExpectedIncludePart = "${dir.Name}/docker-compose.dev.yml"
    $IsDev = $false

    foreach ($inc in $DevIncludes)
    {
        if ($inc -match [regex]::Escape($ExpectedIncludePart))
        {
            $IsDev = $true;
            break
        }
    }

    # Check Prod Status
    $IsProd = $ProdServices -contains $KebabName

    # Determine Status Label
    $Status = "Active"
    if (-not $IsDev)
    {
        $Status = "ORPHANED"
    }

    # Optional: You can indicate file missing in the "Dev Configured" column if desired,
    # but based on your request, we treat it standardly.
    $DisplayDev = if ($IsDev)
    {
        "Yes"
    }
    else
    {
        "NO"
    }

    # If the file is actually missing on disk, we might want to flag that slightly in the NO status
    if (-not (Test-Path (Join-Path $dir.FullName "docker-compose.dev.yml")))
    {
        if (-not $IsDev)
        {
            $DisplayDev = "No"
        }
    }

    $StatusList += [PSCustomObject]@{
        "Integration Name" = $CleanName
        "Dev Configured" = $DisplayDev
        "Prod Deployed" = if ($IsProd)
        {
            "Yes"
        }
        else
        {
            "No"
        }
        "Status" = $Status
    }
}

# --- 5. Output ---
Write-Host "`n📊 Integration Status Report" -ForegroundColor Cyan
$StatusList | Format-Table -AutoSize

if ($StatusList | Where-Object { $_.Status -eq "ORPHANED" })
{
    Write-Host "⚠️  Orphaned integrations detected!" -ForegroundColor Yellow
    Write-Host "   Run 'hamqtt integrations update' to register them automatically." -ForegroundColor Gray
}