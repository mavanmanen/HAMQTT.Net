#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Main CLI entry point for the HAMQTT utility.
.EXAMPLE
    .\hamqtt.ps1
    .\hamqtt.ps1 init
    .\hamqtt.ps1 run dev
    .\hamqtt.ps1 update
    .\hamqtt.ps1 clean
    .\hamqtt.ps1 template install
    .\hamqtt.ps1 integrations new
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

# --- CONSTANTS ---
# The strict list of core files that constitute the toolchain
$CoreSafelist = @(
    "scripts",
    "hamqtt",
    "hamqtt.bat",
    "hamqtt.ps1"
)

# --- BOOTSTRAP LOGIC ---
# If no command provided AND the scripts directory is missing, assume we need to pull the repo.
if ([string]::IsNullOrWhiteSpace($Context) -and -not (Test-Path $ScriptsDir)) {
    Write-Host "⚠️  Current directory appears uninitialized (missing 'scripts' folder)." -ForegroundColor Yellow
    Write-Host "   Do you want to clone the HAMQTT repository here?" -ForegroundColor Cyan
    
    $Response = Read-Host "   [y/N] (Default: No)"
    
    if ($Response.Trim().ToLower() -eq 'y') {
        # Check for Git
        if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
            Write-Error "❌ Git is not installed or not in PATH. Please install Git to continue."
            exit 1
        }

        Write-Host "`n📦 Cloning repository..." -ForegroundColor Cyan
        $RepoUrl = "https://github.com/mavanmanen/HAMQTT"
        $TempDir = Join-Path $PSScriptRoot "_hamqtt_temp_clone"

        try {
            # 1. Clone to temp dir
            git clone $RepoUrl $TempDir
            if ($LASTEXITCODE -ne 0) { throw "Git clone failed." }

            # 2. Copy ONLY Safelisted Items to root
            Write-Host "   📂 Setting up toolchain..." -ForegroundColor Gray
            
            foreach ($ItemName in $CoreSafelist) {
                $Source = Join-Path $TempDir $ItemName
                $Destination = Join-Path $PSScriptRoot $ItemName

                if (Test-Path $Source) {
                    # Recursively copy directory or file
                    Copy-Item -Path $Source -Destination $Destination -Recurse -Force
                    Write-Host "      ✅ Initialized: $ItemName" -ForegroundColor Green
                } else {
                    Write-Warning "      ⚠️  Missing from source: $ItemName"
                }
            }

            # 3. Unix Permissions Fix (if on Linux/Mac)
            if ($IsLinux -or $IsMacOS) {
                try {
                    $WrapperPath = Join-Path $PSScriptRoot "hamqtt"
                    if (Test-Path $WrapperPath) {
                        chmod +x $WrapperPath
                    }
                } catch { 
                    # Ignore permission errors on bootstrap
                }
            }

            # 4. Cleanup
            Remove-Item -Path $TempDir -Recurse -Force
            
            Write-Host "   ✅ Setup complete." -ForegroundColor Green
            
            # 5. Auto-trigger init
            $Context = "init"
            $ScriptsDir = Join-Path $PSScriptRoot "scripts"
        }
        catch {
            Write-Error "Bootstrap failed: $_"
            if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
            exit 1
        }
    }
}

# --- CLEANUP LOGIC ---
# Removes old script versions left behind during self-updates (safeguard cleanup)
$OldScript = Join-Path $PSScriptRoot "hamqtt.ps1.old"
if (Test-Path $OldScript) {
    try { 
        Remove-Item -Path $OldScript -Force -ErrorAction SilentlyContinue 
    } catch {
        # Ignore if still locked (rare)
    }
}

# --- Helper: Print Usage ---
function Show-Usage {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  hamqtt                                (Run in empty folder to clone repo)" -ForegroundColor Gray
    Write-Host "  hamqtt init                           (Initialize fresh project & install template)" -ForegroundColor Gray
    Write-Host "  hamqtt run dev                        (Start local development environment)" -ForegroundColor Gray
    Write-Host "  hamqtt update                         (Update core scripts/libs from master)" -ForegroundColor Gray
    Write-Host "  hamqtt clean                          (Remove temp files & production artifacts)" -ForegroundColor Gray
    Write-Host "  hamqtt template [install|update|remove] (Manage dotnet templates)" -ForegroundColor Gray
    Write-Host "  hamqtt integrations list              (List all integrations & status)" -ForegroundColor Gray
    Write-Host "  hamqtt integrations new [name]        (Create new integration)" -ForegroundColor Gray
    Write-Host "  hamqtt integrations remove [name]     (Remove integration)" -ForegroundColor Gray
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

    "run" {
        switch ($Command) {
            "dev" {
                $ComposeFile = Join-Path $PSScriptRoot "src/docker-compose.dev.yml"
                
                if (-not (Test-Path $ComposeFile)) {
                    Write-Error "Dev compose file not found at $ComposeFile. Please run 'hamqtt init' first."
                }

                Write-Host "🚀 Starting Local Development Environment..." -ForegroundColor Cyan
                
                # Check for docker-compose
                if (-not (Get-Command "docker-compose" -ErrorAction SilentlyContinue)) {
                    Write-Error "❌ docker-compose is not installed or not in PATH."
                }

                try {
                    # Run docker-compose up detached
                    docker-compose -f $ComposeFile up -d --remove-orphans
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "   ✅ Development environment started." -ForegroundColor Green
                    } else {
                         throw "Docker compose returned exit code $LASTEXITCODE"
                    }
                } catch {
                    Write-Error "   ❌ Failed to start environment: $_"
                }
            }
            Default {
                Write-Warning "Unknown command '$Command'. Use 'dev'."
            }
        }
    }

    "clean" {
        Write-Host "▶ Running Cleanup..." -ForegroundColor Cyan
        & "$ScriptsDir/Clean-Project.ps1"
    }

    "update" {
        Write-Host "⚠️  This will update core HAMQTT files from the latest master." -ForegroundColor Yellow
        Write-Host "   User integrations and configuration will remain untouched." -ForegroundColor Gray
        Write-Host "   Are you sure you want to continue?" -ForegroundColor Cyan
        
        $Response = Read-Host "   [y/N] (Default: No)"
        
        if ($Response.Trim().ToLower() -eq 'y') {
            Write-Host "`n📦 Downloading latest version..." -ForegroundColor Cyan
            
            $RepoUrl = "https://github.com/mavanmanen/HAMQTT"
            $TempDir = Join-Path $PSScriptRoot "_hamqtt_update_temp"

            try {
                if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue }

                # 1. Clone to temp dir
                git clone $RepoUrl $TempDir
                if ($LASTEXITCODE -ne 0) { throw "Git clone failed." }

                # 2. Copy Safelisted Items
                Write-Host "   🔄 Updating files..." -ForegroundColor Gray
                
                foreach ($ItemPath in $CoreSafelist) {
                    $Source = Join-Path $TempDir $ItemPath
                    $DestFullPath = Join-Path $PSScriptRoot $ItemPath
                    $DestParent = Split-Path $DestFullPath -Parent

                    if (Test-Path $Source) {
                        # Ensure destination directory exists
                        if (-not (Test-Path $DestParent)) {
                            New-Item -ItemType Directory -Path $DestParent -Force | Out-Null
                        }

                        # --- Safeguard for Self-Update (Locked Files) ---
                        if ($ItemPath -eq "hamqtt.ps1") {
                            $BackupPath = "$DestFullPath.old"
                            # Cleanup potential leftover from previous run (if not locked anymore)
                            if (Test-Path $BackupPath) { 
                                Remove-Item -Path $BackupPath -Force -ErrorAction SilentlyContinue 
                            }
                            
                            # Rename running script to release lock for the new file
                            try {
                                Rename-Item -Path $DestFullPath -NewName "$($ItemPath).old" -Force -ErrorAction Stop
                                Write-Host "      ℹ️  Renamed locked file to allow update: $ItemPath" -ForegroundColor DarkGray
                            } catch {
                                Write-Warning "      ⚠️  Could not rename $ItemPath. Update might fail if file is locked."
                            }
                        }
                        # ------------------------------------------------

                        # Copy (Force allows overwriting)
                        Copy-Item -Path $Source -Destination $DestParent -Recurse -Force
                        Write-Host "      ✅ Updated: $ItemPath" -ForegroundColor Green
                    } else {
                        Write-Host "      ⚠️  Skipped (Not found in remote): $ItemPath" -ForegroundColor DarkGray
                    }
                }

                # 3. Unix Permissions Fix
                if ($IsLinux -or $IsMacOS) {
                    try {
                        $WrapperPath = Join-Path $PSScriptRoot "hamqtt"
                        if (Test-Path $WrapperPath) {
                            chmod +x $WrapperPath
                            Write-Host "      ✅ Restored executable permissions for 'hamqtt'" -ForegroundColor Green
                        }
                    } catch { 
                         Write-Warning "      ⚠️  Could not set +x on 'hamqtt' wrapper."
                    }
                }

                # 4. Auto-Update Template
                Write-Host "`n📦 Checking for template updates..." -ForegroundColor Cyan
                
                dotnet new update
                
                Write-Host "   ✅ Template update check complete." -ForegroundColor Green

                # 5. Cleanup
                Remove-Item -Path $TempDir -Recurse -Force
                Write-Host "`n✨ Core update complete!" -ForegroundColor Cyan

            } catch {
                Write-Error "Update failed: $_"
                if (Test-Path $TempDir) { Remove-Item -Path $TempDir -Recurse -Force }
                exit 1
            }
        } else {
            Write-Host "   Cancelled." -ForegroundColor Gray
        }
    }

    "deploy" {
        Write-Host "▶ Running Deployment..." -ForegroundColor Cyan
        & "$ScriptsDir/Deploy-Integrations.ps1"
    }

    "template" {
        $PackageId = "HAMQTT.Integration.Template"
        $ShortName = "hamqtt-integration" # Short name as defined in the template config

        switch ($Command) {
            "install" {
                Write-Host "📦 Checking template status..." -ForegroundColor Cyan
                $List = dotnet new list | Out-String
                
                if ($List -match $ShortName) {
                     Write-Host "   ✅ Template '$PackageId' is already installed." -ForegroundColor Green
                } else {
                     Write-Host "   Installing template from NuGet..." -ForegroundColor Cyan
                     # CHANGED: Removed --nuget-source
                     dotnet new install $PackageId --ignore-failed-sources
                }
            }
            "update" {
                Write-Host "📦 Updating templates..." -ForegroundColor Cyan
                # CHANGED: Removed --nuget-source. 'dotnet new update' checks all configured sources.
                dotnet new update
            }
            "remove" {
                Write-Host "🗑️ Removing template..." -ForegroundColor Cyan
                dotnet new uninstall $PackageId
            }
            Default {
                Write-Warning "Unknown command '$Command'. Use install, update, or remove."
            }
        }
    }

    "integrations" {
        switch ($Command) {
            "list" {
                & "$ScriptsDir/List-Integrations.ps1"
            }
            "new" {
                $Name = if ($ExtraArgs) { $ExtraArgs[0] } else { $null }
                & "$ScriptsDir/New-Integration.ps1" -IntegrationName $Name
            }
            "remove" {
                $Name = if ($ExtraArgs) { $ExtraArgs[0] } else { $null }
                & "$ScriptsDir/Remove-Integration.ps1" -IntegrationName $Name
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