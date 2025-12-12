<#
.SYNOPSIS
    Contains shared helper functions and path definitions.
#>

# --- Global Path Definitions ---
# Calculate the repo root relative to THIS file (which is inside /scripts)
$Global:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

# --- Shared Functions ---

function Assert-HamqttWrapper {
    <#
    .SYNOPSIS
        Ensures the script is running under the context of the main hamqtt wrapper.
    #>
    if (-not $Global:HAMQTT_WRAPPER_ACTIVE) {
        Write-Warning "⛔ Direct execution is not allowed."
        Write-Host "   Please use the 'hamqtt' wrapper command." -ForegroundColor Gray
        exit 1
    }
}

function Get-KebabCase {
    param ([string]$InputString)
    
    if ([string]::IsNullOrWhiteSpace($InputString)) { return $InputString }

    # CRITICAL: Use -creplace (Case-Sensitive) so [a-z] doesn't match [A-Z].
    
    # 1. Handle Acronyms (e.g., XMLParser -> XML-Parser)
    #    Matches an Uppercase followed by Uppercase+Lowercase
    $s = $InputString -creplace '([A-Z])([A-Z][a-z])', '$1-$2'

    # 2. Handle PascalCase (e.g., SolarEdge -> Solar-Edge)
    #    Matches a Lowercase followed by an Uppercase
    $s = $s -creplace '([a-z])([A-Z])', '$1-$2'

    return $s.ToLower()
}

function Get-CleanIntegrationName {
    <#
    .SYNOPSIS
        Removes the 'HAMQTT.Integration.' prefix from a folder name.
    #>
    param ([string]$FolderName)
    return $FolderName -replace "^HAMQTT\.Integration\.", ""
}

function Set-EnvVariable {
    param (
        [string]$Path,
        [string]$Key,
        [string]$Value
    )
    if (-not (Test-Path $Path)) { New-Item -Path $Path -ItemType File -Force | Out-Null }
    
    $Content = Get-Content -Path $Path -ErrorAction SilentlyContinue
    if ($null -eq $Content) { $Content = @() }
    
    $Pattern = "^${Key}\s*="
    if ($Content -match $Pattern) {
        $Content = $Content | ForEach-Object { if ($_ -match $Pattern) { "${Key}=${Value}" } else { $_ } }
    } else {
        $Content += "${Key}=${Value}"
    }
    $Content | Set-Content -Path $Path
}

function Get-IntegrationServiceBlock {
    param ($KebabName, $ProjectFolderName)
    
    # Returns the YAML string for the service definition
    # Indented by 2 spaces to match 'services:' children
    return @"
  hamqtt-integration-${KebabName}:
    build:
      context: .
      args:
        - GITHUB_USERNAME=${GITHUB_USERNAME}
        - GITHUB_PAT=${GITHUB_PAT}
    env_file:
      - .env
      - ../.env
    environment:
      - MQTT_HOST
      - MQTT_USERNAME
      - MQTT_PASSWORD
    restart: unless-stopped
    networks:
      - hamqtt-integration_network
    depends_on:
      - mosquitto
"@
}

function New-IntegrationComposeFile {
    <#
    .SYNOPSIS
        Generates a fresh docker-compose.dev.yml file.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$IntegrationName,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    $KebabName = Get-KebabCase $IntegrationName
    $ProjectFolderName = "HAMQTT.Integration.${IntegrationName}"

    $ServiceBlock = Get-IntegrationServiceBlock -KebabName $KebabName -ProjectFolderName $ProjectFolderName

    $ComposeContent = @"
services:
$ServiceBlock
"@

    $ComposeContent | Set-Content -Path $OutputPath
}

function Update-IntegrationServiceInCompose {
    <#
    .SYNOPSIS
        Updates ONLY the hamqtt-integration service definition within an existing file.
        Preserves other manually added services.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$IntegrationName,

        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $KebabName = Get-KebabCase $IntegrationName
    $ProjectFolderName = "HAMQTT.Integration.${IntegrationName}"
    $ServiceName = "hamqtt-integration-${KebabName}"

    $CurrentContent = Get-Content -Path $FilePath -Raw
    $NewServiceBlock = Get-IntegrationServiceBlock -KebabName $KebabName -ProjectFolderName $ProjectFolderName

    # Regex breakdown:
    # (?ms)        : Multi-line and Single-line mode (dot matches newline)
    # ^\s{2}       : Start of line with exactly 2 spaces (indentation of a service)
    # SERVICE_NAME : The specific service key we want to replace
    # :            : The colon after the key
    # .*?          : Non-greedy match of the service body
    # (?=...)      : Lookahead (stop matching when...)
    # ^\s{2}\S     : ...we find the start of the NEXT service (2 spaces + non-whitespace)
    # |            : OR
    # \Z           : ...we reach the End of File
    
    $Regex = "(?ms)^\s{2}${ServiceName}:.*?(?=^\s{2}\S|\Z)"

    if ($CurrentContent -match $Regex) {
        $UpdatedContent = $CurrentContent -replace $Regex, $NewServiceBlock
        $UpdatedContent | Set-Content -Path $FilePath
        return $true # Updated
    } else {
        # Edge Case: The file exists but this specific service key isn't found (maybe renamed?)
        # In this case, we append it to the services block if possible, or warn.
        if ($CurrentContent -match "^services:") {
             $UpdatedContent = $CurrentContent -replace "^services:", "services:`n${NewServiceBlock}"
             $UpdatedContent | Set-Content -Path $FilePath
             return $true # Injected
        }
        return $false # Could not locate service or services block
    }
}