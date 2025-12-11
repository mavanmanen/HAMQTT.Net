<#
.SYNOPSIS
    Automates the creation of a HAMQTT Integration project.
.DESCRIPTION
    Creates new project and links to Docker Compose.
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$IntegrationName,

    [Parameter(Mandatory=$false)]
    [switch]$UpdateTemplate
)

$ErrorActionPreference = "Stop"

# --- Import Shared Functions & Assert Wrapper ---
. "$PSScriptRoot/Common-Utils.ps1"
Assert-HamqttWrapper

# --- Constants ---
$TemplatePath = Join-Path $ProjectRoot "templates/Hamqtt.Integration.Template"
$RootComposePath = Join-Path $ProjectRoot "src/docker-compose.dev.yml"
$SrcPath = Join-Path $ProjectRoot "src"

# --- 1. Setup Variables ---
$ProjectFolderName = "HAMQTT.Integration.${IntegrationName}"
$ProjectRelPath = Join-Path $SrcPath $ProjectFolderName

Write-Host "🚀 Starting setup for '${ProjectFolderName}'..." -ForegroundColor Cyan

# --- 2. Template Management ---
Write-Host "`n📦 Checking Template Status..." -ForegroundColor Yellow
$list = dotnet new list --columns short-name | Out-String
if ($list -match "hamqtt-integration") {
    if ($UpdateTemplate) {
        Write-Host "   Updating template..." -ForegroundColor Gray
        dotnet new install $TemplatePath --force | Out-Null
    } else {
        Write-Host "   ✅ Template already installed." -ForegroundColor Green
    }
} else {
    dotnet new install $TemplatePath | Out-Null
    Write-Host "   ✅ Template installed." -ForegroundColor Green
}

# --- 3. Run dotnet new ---
Write-Host "`n🔨 Generating Project..." -ForegroundColor Yellow
$RootLocation = Get-Location

try {
    if (-not (Test-Path $SrcPath)) { New-Item -ItemType Directory -Path $SrcPath | Out-Null }
    Set-Location $SrcPath

    dotnet new hamqtt-integration `
        --integration-name $IntegrationName `
        --force

    if ($LASTEXITCODE -ne 0) { throw "dotnet new failed" }
}
catch {
    Write-Error "Failed to generate project: ${_}"
    Set-Location $RootLocation
    exit 1
}
finally {
    Set-Location $RootLocation
}
Write-Host "   ✅ Project generated at: ${ProjectRelPath}" -ForegroundColor Green

# --- 4. Create Project-Level Docker Compose ---
Write-Host "`n🐳 Creating Project Docker Compose..." -ForegroundColor Yellow

$ComposePath = Join-Path $ProjectRelPath "docker-compose.dev.yml"

# Call Shared Function
New-IntegrationComposeFile -IntegrationName $IntegrationName -OutputPath $ComposePath

Write-Host "   ✅ Created: ${ComposePath}" -ForegroundColor Green

# --- 5. Update Root Docker Compose (Includes) ---
Write-Host "`n🔗 Registering Integration in Root Docker Compose..." -ForegroundColor Yellow

if (Test-Path $RootComposePath) {
    $RootContent = Get-Content $RootComposePath -Raw
    $IncludeLine = "  - ${ProjectFolderName}/docker-compose.dev.yml"

    if ($RootContent -notmatch [regex]::Escape($IncludeLine)) {
        if ($RootContent -match "(?m)^include:\s*$") {
            $NewContent = $RootContent -replace "(?m)^include:\s*$", "include:`n${IncludeLine}"
            $NewContent | Set-Content -Path $RootComposePath
            Write-Host "   ✅ Added reference to root compose file." -ForegroundColor Green
        }
        elseif ($RootContent -match "(?m)^include:") {
            $Lines = Get-Content $RootComposePath
            $IncludeIndex = $Lines | Select-String -Pattern "^include:" -Line | Select-Object -ExpandProperty LineNumber
            
            $Lines = [System.Collections.Generic.List[string]]$Lines
            $Lines.Insert($IncludeIndex, $IncludeLine)
            $Lines | Set-Content -Path $RootComposePath
            Write-Host "   ✅ Appended reference to existing include list." -ForegroundColor Green
        }
        else {
            Write-Warning "   ⚠️  Could not find 'include:' section in root compose file. Please add manually."
        }
    } else {
        Write-Host "   ℹ️  Reference already exists in root compose file." -ForegroundColor Gray
    }
} else {
    Write-Warning "   ⚠️  Root compose file not found at ${RootComposePath}. Run Initialize-Project.ps1 first."
}

Write-Host "`n✨ Setup Complete! Run 'docker-compose -f src/docker-compose.dev.yml up -d' to start." -ForegroundColor Cyan