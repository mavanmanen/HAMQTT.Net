<#
.SYNOPSIS
    Main CLI entry point for the HAMQTT utility.
.EXAMPLE
    .\hamqtt.ps1 init
    .\hamqtt.ps1 integrations new SolarEdge
    .\hamqtt.ps1 integrations list
    .\hamqtt.ps1 integrations remove SolarEdge
    .\hamqtt.ps1 integrations update
    .\hamqtt.ps1 deploy
#>
param(
    [Parameter(Position=0)]
    [string]$Context,

    [Parameter(Position=1)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"
$ScriptsDir = Join-Path $PSScriptRoot "scripts"

# --- Security Flag ---
# signals to child scripts that they are running under the wrapper
$Global:HAMQTT_WRAPPER_ACTIVE = $true

# --- Helper: Print Usage ---
function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  hamqtt init                           (Initialize fresh project)" -ForegroundColor Gray
    Write-Host "  hamqtt integrations list              (List all integrations & status)" -ForegroundColor Gray
    Write-Host "  hamqtt integrations new <name>        (Create new integration)" -ForegroundColor Gray
    Write-Host "  hamqtt integrations remove <name>     (Remove integration)" -ForegroundColor Gray
    Write-Host "  hamqtt integrations update            (Sync compose with folders)" -ForegroundColor Gray
    Write-Host "  hamqtt deploy                         (Build production compose)" -ForegroundColor Gray
}

# --- Normalize Input ---
if ([string]::IsNullOrWhiteSpace($Context)) {
    Show-Usage
    exit
}

$Context = $Context.ToLower()

# --- Router Logic ---
switch ($Context) {
    "init" {
        Write-Host "▶ Running Initialization..." -ForegroundColor Cyan
        & "$ScriptsDir/Init-Project.ps1"
    }

    "deploy" {
        Write-Host "▶ Running Deployment..." -ForegroundColor Cyan
        & "$ScriptsDir/Deploy-Integrations.ps1"
    }

    "integrations" {
        switch ($Command) {
            "list" {
                & "$ScriptsDir/List-Integrations.ps1"
            }
            "new" {
                if (-not $ExtraArgs) { 
                    Write-Error "Missing parameter: Integration Name. (e.g., 'hamqtt integrations new SolarEdge')" 
                }
                & "$ScriptsDir/New-Integration.ps1" -IntegrationName $ExtraArgs[0]
            }
            "remove" {
                if (-not $ExtraArgs) { 
                    Write-Error "Missing parameter: Integration Name. (e.g., 'hamqtt integrations remove SolarEdge')" 
                }
                & "$ScriptsDir/Remove-Integration.ps1" -IntegrationName $ExtraArgs[0]
            }
            "update" {
                & "$ScriptsDir/Update-Integrations.ps1"
            }
            "deploy" {
                # Alias for 'hamqtt deploy'
                & "$ScriptsDir/Deploy-Integrations.ps1"
            }
            Default {
                Write-Warning "Unknown command '$Command' for context 'integrations'."
                Show-Usage
            }
        }
    }

    Default {
        Write-Warning "Unknown command '$Context'."
        Show-Usage
    }
}