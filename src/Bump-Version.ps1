param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

$ProjectFiles = @(
    "HAMQTT.CLI/HAMQTT.CLI.csproj";
    "HAMQTT.Integration/HAMQTT.Integration.csproj";
    "HAMQTT.Integration.Template.csproj"
)

if ([string]::IsNullOrEmpty($Version)) {
    $ReferenceFile = Join-Path $PSScriptRoot "HAMQTT.Integration/HAMQTT.Integration.csproj"
    if (Test-Path $ReferenceFile) {
        $Content = Get-Content $ReferenceFile -Raw
        if ($Content -match "<Version>(?<v>\d+\.\d+\.\d+)(?<suffix>.*)?</Version>") {
            $CurrentVersion = $Matches['v']
            $Suffix = $Matches['suffix']
            
            $Parts = $CurrentVersion -split '\.'
            $Major = [int]$Parts[0]
            $Minor = [int]$Parts[1]
            $Patch = [int]$Parts[2]
            
            $Patch++
            
            $Version = "$Major.$Minor.$Patch$Suffix"
            Write-Host "Auto-detected current version: $CurrentVersion. Bumping to: $Version" -ForegroundColor Gray
        } else {
            Write-Error "Could not detect current version from $ReferenceFile"
            exit 1
        }
    } else {
        Write-Error "Reference file not found: $ReferenceFile"
        exit 1
    }
}

if ($Version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$') {
    Write-Error "Invalid SemVer version string: $Version"
    exit 1
}

Write-Host "Bumping version to $Version..." -ForegroundColor Cyan

$PathsToAdd = @()

foreach ($RelPath in $ProjectFiles) {
    $FullPath = Join-Path $PSScriptRoot $RelPath
    
    if (Test-Path $FullPath) {
        Write-Host "   Updating $RelPath" -ForegroundColor Yellow
        $Content = Get-Content $FullPath -Raw
        
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
    Write-Host "Committing changes..." -ForegroundColor Cyan
    
    git add $PathsToAdd
    
    git commit -m "Bump version to $Version"
    
    $Tag = "v$Version"
    Write-Host "Tagging version $Tag..." -ForegroundColor Cyan
    git tag $Tag
    
    Write-Host "Version bumped to $Version (Tag: $Tag) successfully!" -ForegroundColor Green

    $Push = Read-Host "Do you want to push changes and tags to remote? (y/N)"
    if ($Push -eq 'y' -or $Push -eq 'Y') {
        Write-Host "Pushing to remote..." -ForegroundColor Cyan
        git push
        git push --tags
        Write-Host "Pushed successfully." -ForegroundColor Green
    } else {
        Write-Host "Changes committed locally but not pushed." -ForegroundColor Gray
    }
} else {
    Write-Warning "No files were updated. Nothing to commit."
}
