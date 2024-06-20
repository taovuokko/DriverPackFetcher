param (
    [string]$modelName
)

# Function to read config from JSON file
function Read-Config {
    param (
        [string]$configPath
    )
    if (Test-Path -Path $configPath) {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        return $config
    } else {
        throw "Configuration file not found: $configPath"
    }
}

# Ensure required modules are installed
function Ensure-Modules {
    if (-not (Get-Module -ListAvailable -Name HPCMSL)) {
        Write-Host "HPCMSL module not found. Installing..."
        Install-Module -Name HPCMSL -Force -AcceptLicense -Verbose
    } else {
        Write-Host "HPCMSL module is already installed."
    }
}

# Function to download BIOS updates
function Download-BIOSUpdates {
    param (
        [string]$downloadPath
    )

    # Create BIOS folder inside the download path
    $biosFolderPath = Join-Path -Path $downloadPath -ChildPath "BIOS"
    if (-not (Test-Path -Path $biosFolderPath)) {
        New-Item -Path $biosFolderPath -ItemType Directory
    }

    Write-Host "Downloading BIOS updates to: $biosFolderPath"

    try {
        $deviceDetails = Get-HPDeviceDetails -Name $modelName -Like "*"
        if (-not $deviceDetails) {
            throw "Details not found for model: $modelName"
        }

        $systemIds = $deviceDetails.SystemID

        foreach ($systemId in $systemIds) {
            Write-Host "Attempting to download BIOS updates for System ID: $systemId"

            try {
                $updates = Get-SoftpaqList -Platform $systemId -Category "BIOS" -Download -DownloadDirectory $biosFolderPath
                Write-Host "BIOS updates downloaded successfully for System ID: $systemId."
            } catch {
                Write-Error "Failed to download BIOS updates for System ID: $systemId. Error: $_"
            }
        }
    } catch {
        Write-Error "Failed to download BIOS updates: $_"
    }
}

# Main script logic
$config = Read-Config -configPath "config.json"
Ensure-Modules

# Read the folder path from folderInfo.txt
$folderInfoPath = Join-Path -Path $config.General.LocalPath -ChildPath $config.General.FolderInfoFile
if (Test-Path -Path $folderInfoPath) {
    $finalDownloadPath = Get-Content -Path $folderInfoPath -Raw
    Download-BIOSUpdates -downloadPath $finalDownloadPath
} else {
    Write-Error "folderInfo.txt not found in $config.General.LocalPath"
}
