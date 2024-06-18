param (
    [string]$ModelName,
    [string]$DownloadPath,
    [string]$NetworkPath,
    [string]$CsvPath = $null,
    [switch]$IncludeFirmware,
    [string]$ConfigPath
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

# Load configuration
$config = Read-Config -configPath $ConfigPath

# Define supported Windows versions globally
$windows11Versions = @("23h2", "22h2", "21h2")
$windows10Versions = @("21h2", "21h1", "20h2", "2009", "2004", "1909", "1903", "1809")

# Function to ensure PowerShell 7 is installed
function Ensure-PowerShell7 {
    $pwshPath = $config.HP.PowerShellExe
    if (-not (Test-Path $pwshPath)) {
        Write-Host "PowerShell 7 is not installed. Installing PowerShell 7..."
        winget install --id Microsoft.Powershell --source winget
    } else {
        Write-Host "PowerShell 7 is already installed."
    }
    return $pwshPath
}

# Function to check and install/update PowerShellGet module
function Check-And-Install-PowerShellGet {
    $currentVersion = (Get-Module -ListAvailable -Name PowerShellGet | Select-Object -First 1 -ExpandProperty Version) -as [Version]
    $requiredVersion = [Version]"2.0"

    if ($currentVersion -lt $requiredVersion) {
        Write-Host "Updating PowerShellGet module..."
        Install-PackageProvider -Name NuGet -Force -Verbose
        Install-Module -Name PowerShellGet -Force -Verbose
        Import-Module -Name PowerShellGet -Force -Verbose
    } else {
        Write-Host "PowerShellGet module is up to date."
    }
}

# Function to check and install HPCMSL module
function Check-And-Install-HPCMSL {
    if (-not (Get-Module -ListAvailable -Name HPCMSL)) {
        Write-Host "HPCMSL module not found. Installing..."
        Install-Module -Name HPCMSL -Force -AcceptLicense -Verbose
    } else {
        Write-Host "HPCMSL module is already installed."
    }
}

# Function to get HP device platform IDs
function Get-HPPlatformIds {
    param (
        [string]$modelName
    )

    try {
        $deviceDetails = Get-HPDeviceDetails -Name $modelName -Like "*"
        if (-not $deviceDetails) {
            throw "Details not found for model: $modelName"
        }

        $platformIds = $deviceDetails.SystemID

        if (-not $platformIds) {
            throw "Platform IDs not found for model: $modelName"
        }

        return $platformIds
    } catch {
        Write-Error $_.Exception.Message
        throw
    }
}

# Function to get latest supported OS version for the platform
function Get-LatestOSVersion {
    param (
        [array]$platformIds,
        [string]$localPath
    )

    try {
        Write-Output "Searching for supported OS versions for platform IDs: $($platformIds -join ', ')..."

        $osOptions = @(
            @{ OS = "win11"; Versions = $windows11Versions },
            @{ OS = "win10"; Versions = $windows10Versions }
        )

        foreach ($platformId in $platformIds) {
            foreach ($osOption in $osOptions) {
                $os = $osOption.OS
                $versions = $osOption.Versions

                foreach ($version in $versions) {
                    Write-Output "Trying OS version: $version for $os on platform ID: $platformId"

                    try {
                        Write-Host "Creating driver pack for platform ID: $platformId, OS: $os, Version: $version"

                        New-HPDriverPack -Platform $platformId -OS $os -OSVer $version -Path $localPath

                        # Rename folder with model name
                        $downloadedFolderPath = Join-Path $localPath "DP$platformId"
                        $newFolderPath = Join-Path $localPath "$ModelName (DP$platformId)"

                        if (Test-Path $downloadedFolderPath) {
                            Rename-Item -Path $downloadedFolderPath -NewName $newFolderPath -Force
                            Write-Host "Folder renamed to: $newFolderPath"
                        } else {
                            Write-Error "Downloaded folder not found: $downloadedFolderPath"
                        }

                        return $newFolderPath  # Return the new folder path if successful
                    } catch {
                        Write-Error $_.Exception.Message
                        Write-Host "Failed to create driver pack for OS version: $version"
                    }
                }
            }
        }

        throw "No suitable OS version found for platform IDs: $($platformIds -join ', ')."
    } catch {
        Write-Error $_.Exception.Message
        throw
    }
}

# Function to download BIOS updates
function Download-BIOSUpdates {
    param (
        [string]$modelName,
        [string]$localPath,
        [string]$driverPackPath
    )

    # Create BIOS folder inside the download path
    $biosFolderPath = Join-Path -Path $localPath -ChildPath "BIOS"
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

                # Move the BIOS folder to the driver pack path
                $destinationBiosPath = Join-Path -Path $driverPackPath -ChildPath "BIOS"
                if (Test-Path -Path $biosFolderPath) {
                    Move-Item -Path $biosFolderPath -Destination $destinationBiosPath -Force
                    Write-Host "BIOS folder moved to: $destinationBiosPath"
                } else {
                    Write-Error "BIOS folder not found at: $biosFolderPath"
                }
            } catch {
                Write-Error "Failed to download BIOS updates for System ID: $systemId. Error: $_"
            }
        }
    } catch {
        Write-Error "Failed to download BIOS updates: $_"
    }
}

# Function to process models from CSV file
function Process-ModelsFromCSV {
    param (
        [string]$csvPath,
        [string]$localPath,
        [switch]$includeFirmware
    )

    try {
        Write-Host "Reading CSV file: $csvPath"
        $models = Import-Csv -Path $csvPath | Select-Object -ExpandProperty Model

        if ($models.Count -eq 0) {
            Write-Host "No models found in CSV file."
            return
        }

        foreach ($model in $models) {
            Write-Host "Processing model: $model"
            $platformIds = Get-HPPlatformIds -modelName $model
            $driverPackPath = Get-LatestOSVersion -platformIds $platformIds -localPath $localPath

            if ($includeFirmware) {
                Download-BIOSUpdates -modelName $model -localPath $localPath -driverPackPath $driverPackPath
            }
        }
    } catch {
        Write-Error "Failed to process models from CSV: $_"
    }
}

# Main script logic
Ensure-PowerShell7
Check-And-Install-PowerShellGet
Check-And-Install-HPCMSL

$localPath = $config.HP.LocalPath

if ($CsvPath) {
    Process-ModelsFromCSV -csvPath $CsvPath -localPath $localPath -includeFirmware:$IncludeFirmware
} else {
    $platformIds = Get-HPPlatformIds -modelName $ModelName
    $driverPackPath = Get-LatestOSVersion -platformIds $platformIds -localPath $localPath

    if ($IncludeFirmware) {
        Download-BIOSUpdates -modelName $ModelName -localPath $localPath -driverPackPath $driverPackPath
    }
}
