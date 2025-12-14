#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Internal entry point for the HAMQTT.CLI tool.
    This is now called by the .NET Wrapper, not directly by the user.
#>
param(
    [Parameter(Position = 0)]
    [string]$Context,

    [Parameter(Position = 1)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
# Resolve scripts relative to this file (which lives in the tool install dir now)
$ScriptsDir = Join-Path $PSScriptRoot "scripts"

# --- Argument Parsing ---
$ProjectRootArg = $null
$CleanedExtraArgs = @()

if ($ExtraArgs) {
    for ($i = 0; $i -lt $ExtraArgs.Count; $i++) {
        $arg = $ExtraArgs[$i]
        if ($arg -eq "--root" -or $arg -eq "-ProjectRoot") {
            if ($i + 1 -lt $ExtraArgs.Count) {
                $ProjectRootArg = $ExtraArgs[$i + 1]
                $i++ # Skip next arg
            } else {
                Write-Error "Missing value for --root argument."
                exit 1
            }
        } else {
            $CleanedExtraArgs += $arg
        }
    }
}
$ExtraArgs = $CleanedExtraArgs

# --- Helper: Print Usage ---
function Show-Usage
{
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  hamqtt init                           (Initialize fresh project)" -ForegroundColor Gray
    Write-Host "  hamqtt run dev [--bare]               (Start local dev env)" -ForegroundColor Gray
    Write-Host "  hamqtt update                         (Update this tool)" -ForegroundColor Gray
    Write-Host "  hamqtt template [install|update]      (Manage templates)" -ForegroundColor Gray
    Write-Host "  hamqtt integrations [new|list|remove] (Manage integrations)" -ForegroundColor Gray
}

if ( [string]::IsNullOrWhiteSpace($Context))
{
    Show-Usage
    exit
}

$Context = $Context.ToLower()

switch ($Context)
{
    "init" {
        & "$ScriptsDir/Init-Project.ps1" -ProjectRoot $ProjectRootArg
    }

    "run" {
        if ($Command -eq "dev")
        {
            if ($ProjectRootArg) {
                $ProjectRoot = (Resolve-Path $ProjectRootArg).Path
            } else {
                $ProjectRoot = Get-Location
            }
            $ComposeFile = Join-Path $ProjectRoot "docker-compose.dev.yml"
            $BareMode = $ExtraArgs -contains "--bare"

            if (-not (Test-Path $ComposeFile))
            {
                Write-Error "Dev compose file not found at $ComposeFile. Run 'hamqtt init' first."
            }

            Write-Host "🚀 Starting Local Development Environment..." -ForegroundColor Cyan
            try
            {
                if ($BareMode)
                {
                    Write-Host "   ℹ️  Running in BARE mode." -ForegroundColor Yellow
                    docker compose -f $ComposeFile up -d --remove-orphans mosquitto homeassistant
                }
                else
                {
                    docker compose -f $ComposeFile up --build -d --remove-orphans
                }
                Write-Host "   ✅ Environment started." -ForegroundColor Green
            }
            catch
            {
                Write-Error "   ❌ Failed: $_"
            }
        }
        else
        {
            Write-Warning "Unknown command '$Command'. Use 'dev'."
        }
    }

    "update" {
        # The tool handles its own updates via NuGet now
        Write-Host "📦 To update HAMQTT, please run:" -ForegroundColor Cyan
        Write-Host "   dotnet tool update -g HAMQTT.CLI" -ForegroundColor Yellow

        # Also auto-update templates
        Write-Host "`n📦 Updating templates..." -ForegroundColor Cyan
        dotnet new update
    }

    "template" {
        $PackageId = "HAMQTT.Integration.Template"
        $ShortName = "hamqtt-integration"

        switch ($Command)
        {
            "install" {
                Write-Host "📦 Checking template status..." -ForegroundColor Cyan
                $List = dotnet new list | Out-String

                if ($List -match $ShortName)
                {
                    Write-Host "   ✅ Template '$PackageId' is already installed." -ForegroundColor Green
                }
                else
                {
                    Write-Host "   Installing template from NuGet..." -ForegroundColor Cyan
                    dotnet new install $PackageId
                }
            }
            "update" {
                Write-Host "📦 Updating templates..." -ForegroundColor Cyan
                dotnet new update
            }
            "remove" {
                dWrite-Host "🗑️ Removing template..." -ForegroundColor Cyan
                dotnet new uninstall $PackageId
            }
            Default {
                Write-Warning "Unknown command '$Command'. Use install, update, or remove."
            }
        }
    }

    "integrations" {
        switch ($Command)
        {
            "list" {
                & "$ScriptsDir/List-Integrations.ps1" -ProjectRoot $ProjectRootArg
            }
            "new" {
                $Name = if ($ExtraArgs)
                {
                    $ExtraArgs[0]
                }
                else
                {
                    $null
                }
                & "$ScriptsDir/New-Integration.ps1" -IntegrationName $Name -ProjectRoot $ProjectRootArg
            }
            "remove" {
                $IntName = $null
                $FolderName = $null
                
                # Parse args
                for ($i = 0; $i -lt $ExtraArgs.Count; $i++) {
                    $arg = $ExtraArgs[$i]
                    if ($arg -eq "-ProjectFolderName" -or $arg -eq "--project-folder-name") {
                        if ($i + 1 -lt $ExtraArgs.Count) {
                            $FolderName = $ExtraArgs[$i + 1]
                            $i++
                        }
                    }
                    elseif ($arg -notlike "-*") {
                        $IntName = $arg
                    }
                }

                & "$ScriptsDir/Remove-Integration.ps1" -IntegrationName $IntName -ProjectFolderName $FolderName -ProjectRoot $ProjectRootArg
            }
            "update" {
                & "$ScriptsDir/Update-Integrations.ps1" -ProjectRoot $ProjectRootArg
            }
            "deploy" {
                $MqttHost = $null
                $MqttUsername = $null
                $MqttPassword = $null

                # Parse args
                for ($i = 0; $i -lt $ExtraArgs.Count; $i++) {
                    $arg = $ExtraArgs[$i]
                    if ($arg -eq "--mqtt-host") {
                        if ($i + 1 -lt $ExtraArgs.Count) {
                            $MqttHost = $ExtraArgs[$i + 1]
                            $i++
                        }
                    }
                    elseif ($arg -eq "--mqtt-username") {
                        if ($i + 1 -lt $ExtraArgs.Count) {
                            $MqttUsername = $ExtraArgs[$i + 1]
                            $i++
                        }
                    }
                    elseif ($arg -eq "--mqtt-password") {
                        if ($i + 1 -lt $ExtraArgs.Count) {
                            $MqttPassword = $ExtraArgs[$i + 1]
                            $i++
                        }
                    }
                }

                & "$ScriptsDir/Deploy-Integrations.ps1" -ProjectRoot $ProjectRootArg -MqttHost $MqttHost -MqttUsername $MqttUsername -MqttPassword $MqttPassword
            }
            Default {
                Show-Usage
            }
        }
    }

    Default {
        Show-Usage
    }
}