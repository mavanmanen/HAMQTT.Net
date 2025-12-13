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

# Flag to signal we are running safely
$Global:HAMQTT_WRAPPER_ACTIVE = $true

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
        & "$ScriptsDir/Init-Project.ps1"
    }

    "run" {
        if ($Command -eq "dev")
        {
            # We assume the user is running this IN their project root
            $ProjectRoot = Get-Location
            $ComposeFile = Join-Path $ProjectRoot "src/docker-compose.dev.yml"
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
                    docker-compose -f $ComposeFile up -d --remove-orphans mosquitto homeassistant
                }
                else
                {
                    docker-compose -f $ComposeFile up -d --remove-orphans
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
                & "$ScriptsDir/List-Integrations.ps1"
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
                & "$ScriptsDir/New-Integration.ps1" -IntegrationName $Name
            }
            "remove" {
                $Name = if ($ExtraArgs)
                {
                    $ExtraArgs[0]
                }
                else
                {
                    $null
                }
                & "$ScriptsDir/Remove-Integration.ps1" -IntegrationName $Name
            }
            "update" {
                & "$ScriptsDir/Update-Integrations.ps1"
            }
            "deploy" {
                & "$ScriptsDir/Deploy-Integrations.ps1"
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