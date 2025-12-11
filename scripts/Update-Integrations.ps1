<#
.SYNOPSIS
    Synchronizes the root docker-compose.dev.yml with the actual integration folders on disk.
.DESCRIPTION
    Scans src/ for integrations. 
    1. If docker-compose.dev.yml is MISSING, it creates it.
    2. If docker-compose.dev.yml EXISTS, it UPDATES the main integration definition 
       (preserving manual sidecars/databases).
    3. Rebuilds the 'include:' section of the root compose file.
#>

$ErrorActionPreference = "Stop"

# --- Import Shared Functions & Assert Wrapper ---
. "$PSScriptRoot/Common-Utils.ps1"
Assert-HamqttWrapper

# --- Constants ---
$RootComposePath = Join-Path $ProjectRoot "src/docker-compose.dev.yml"
$SrcPath = Join-Path $ProjectRoot "src"

Write-Host "🚀 Starting Integration Synchronization..." -ForegroundColor Cyan

# --- 1. Scan Disk for Actual Integrations ---
Write-Host "   🔍 Scanning '$SrcPath' for projects..." -ForegroundColor Yellow
if (-not (Test-Path $SrcPath)) {
    Write-Error "   ❌ Source directory not found at $SrcPath"
}

$IntegrationDirs = Get-ChildItem -Path $SrcPath -Directory -Filter "HAMQTT.Integration.*"
$FoundProjects = @()

foreach ($dir in $IntegrationDirs) {
    # Ignore the base library project
    if ($dir.Name -eq "HAMQTT.Integration") { continue }

    $ComposePath = Join-Path $dir.FullName "docker-compose.dev.yml"
    
    # Use shared function to get clean name
    $CleanName = Get-CleanIntegrationName $dir.Name

    if (-not (Test-Path $ComposePath)) {
        # --- CASE A: File Missing (Regenerate) ---
        Write-Host "   ⚠️  Missing docker-compose.dev.yml for '$($dir.Name)'." -ForegroundColor Yellow
        Write-Host "      🛠️  Regenerating file..." -ForegroundColor Gray
        try {
            New-IntegrationComposeFile -IntegrationName $CleanName -OutputPath $ComposePath
            Write-Host "      ✅ Created file: $ComposePath" -ForegroundColor Green
        } catch {
            Write-Error "      ❌ Failed to create file: $_"
            continue
        }
    } else {
        # --- CASE B: File Exists (Surgical Update) ---
        # We want to update the definition of the main service, but keep any manual additions
        try {
            $DidUpdate = Update-IntegrationServiceInCompose -IntegrationName $CleanName -FilePath $ComposePath
            if ($DidUpdate) {
                Write-Host "      ✅ Updated service definition in: $ComposePath" -ForegroundColor Gray
            } else {
                Write-Warning "      ⚠️  Could not find service definition to update in: $ComposePath"
            }
        } catch {
             Write-Error "      ❌ Failed to update file: $_"
        }
    }

    # If we are here, the file exists
    $FoundProjects += $dir.Name
}

Write-Host "      Found $($FoundProjects.Count) valid integration(s)." -ForegroundColor Gray

# --- 2. Read and Parse Root Compose File ---
if (-not (Test-Path $RootComposePath)) {
    Write-Warning "   ⚠️  Root compose file not found at $RootComposePath. Please run Initialize-Project.ps1."
    exit
}

$Content = Get-Content -Path $RootComposePath -Raw

# --- 3. Reconstruct the 'include' Section ---
Write-Host "   🔄 Updating 'include' section..." -ForegroundColor Yellow

if ($FoundProjects.Count -gt 0) {
    $NewIncludeBlock = "include:"
    foreach ($ProjectName in $FoundProjects) {
        $NewIncludeBlock += "`n  - ${ProjectName}/docker-compose.dev.yml"
    }
    # IMPORTANT: Add trailing newline to separate from 'services:' block
    $NewIncludeBlock += "`n"
} else {
    # If no projects, remove the include block entirely
    $NewIncludeBlock = "" 
}

$Regex = "(?ms)^include:.*?(?=^services:)"

if ($Content -match $Regex) {
    $NewContent = $Content -replace $Regex, $NewIncludeBlock
    $NewContent | Set-Content -Path $RootComposePath
    Write-Host "   ✅ Docker Compose updated successfully." -ForegroundColor Green
} else {
    # Only inject if we actually have includes
    if ($NewIncludeBlock -ne "") {
        if ($Content -match "^services:") {
            # Inject before services, ensuring we have a newline separator
            $NewContent = $Content -replace "^services:", "${NewIncludeBlock}`nservices:"
            $NewContent | Set-Content -Path $RootComposePath
            Write-Host "   ✅ 'include' section missing; injected successfully." -ForegroundColor Green
        } else {
            Write-Error "   ❌ Could not locate 'services:' block in docker-compose.dev.yml. File may be corrupt."
        }
    } else {
        Write-Host "   ℹ️  No integrations to include." -ForegroundColor Gray
    }
}

# --- 4. Final Status ---
Write-Host "`n✨ Synchronization Complete!" -ForegroundColor Cyan
if ($FoundProjects.Count -gt 0) {
    Write-Host "   Active Integrations:" -ForegroundColor Gray
    $FoundProjects | ForEach-Object { Write-Host "    - $_" -ForegroundColor White }
} else {
    Write-Host "   (No active integrations found)" -ForegroundColor Gray
}

Write-Host "`n   👉 To apply changes, run: docker-compose -f src/docker-compose.dev.yml up -d --remove-orphans" -ForegroundColor Gray