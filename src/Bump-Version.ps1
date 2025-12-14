param(
    [Parameter(Mandatory=$true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

# Basic SemVer validation
if ($Version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$') {
    Write-Error "Invalid SemVer version string: $Version"
    exit 1
}

$ProjectFiles = @(
    "HAMQTT.CLI/HAMQTT.CLI.csproj",
    "HAMQTT.Integration/HAMQTT.Integration.csproj",
    "HAMQTT.Integration.Template.csproj"
)

Write-Host "Bumping version to $Version..." -ForegroundColor Cyan

$PathsToAdd = @()

foreach ($RelPath in $ProjectFiles) {
    $FullPath = Join-Path $PSScriptRoot $RelPath
    
    if (Test-Path $FullPath) {
        Write-Host "   Updating $RelPath" -ForegroundColor Yellow
        $Content = Get-Content $FullPath -Raw
        
        # Regex update for <Version> tag
        if ($Content -match "<Version>.*?</Version>") {
            $NewContent = $Content -replace "<Version>.*?</Version>", "<Version>$Version</Version>"
            $NewContent | Set-Content $FullPath
            $PathsToAdd += $RelPath
        } else {
            Write-Warning "<Version> tag not found in $RelPath"
        }
    } else {
        Write-Warning "File not found: $FullPath"
    }
}

if ($PathsToAdd.Count -gt 0) {
    Write-Host "`nCommitting changes..." -ForegroundColor Cyan
    
    # Git Add
    git add $PathsToAdd
    
    # Git Commit
    git commit -m "Bump version to $Version"
    
    # Git Tag
    $Tag = "v$Version"
    Write-Host "Tagging version $Tag..." -ForegroundColor Cyan
    git tag $Tag
    
    Write-Host "`nVersion bumped to $Version (Tag: $Tag) successfully!" -ForegroundColor Green
} else {
    Write-Warning "No files were updated. Nothing to commit."
}