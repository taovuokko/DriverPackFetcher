param (
    [string]$ConfigPath = "",
    [string]$ModelName = $null,
    [string]$CsvPath = $null,
    [switch]$IncludeFirmware
)

# Function to get the configuration path
function Get-ConfigPath {
    $appDataPath = [System.Environment]::GetFolderPath('ApplicationData')
    $appFolderPath = Join-Path -Path $appDataPath -ChildPath "DriverPackFetcher"
    $configPath = Join-Path -Path $appFolderPath -ChildPath "config.json"

    if (-not (Test-Path -Path $configPath)) {
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "Resources\config.json"
    }
    return $configPath
}

if (-not $ConfigPath) {
    $ConfigPath = Get-ConfigPath
}

# Read and parse the JSON file
$config = Get-Content -Path $ConfigPath | ConvertFrom-Json

# Retrieve Lenovo settings from the configuration
$lenovoConfig = $config.Lenovo

# Expand environment variables
function Expand-Path {
    param (
        [string]$Path
    )
    return [Environment]::ExpandEnvironmentVariables($Path)
}

# Define the paths using the configuration values
[string]$DownloadPath = Expand-Path($lenovoConfig.DownloadPath)
[string]$NetworkPath = Expand-Path($lenovoConfig.NetworkPath)
[string]$CatalogPath = Expand-Path($lenovoConfig.CatalogPath)
[int]$DaysToRefresh = $lenovoConfig.DaysToRefresh

Write-Host "Download path: $DownloadPath"
Write-Host "Catalog path: $CatalogPath"
Write-Host "Network path: $NetworkPath"
Write-Host "Days to refresh: $DaysToRefresh"
Write-Host "Model name: $ModelName"
Write-Host "CSV path: $CsvPath"
Write-Host "Include firmware: $IncludeFirmware"

function Ensure-Directory {
    param (
        [string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path | Out-Null
            Write-Host "Created directory: $Path"
        } catch {
            Write-Error ("Error creating directory {0}: {1}" -f $Path, $_)
        }
    }
}

function Update-Catalog {
    $uri = "https://download.lenovo.com/cdrt/td/catalogv2.xml"
    Ensure-Directory -Path $DownloadPath
    try {
        if (Test-Path -Path $CatalogPath) {
            $lastModified = [DateTime](Get-Item $CatalogPath).LastWriteTime
            $currentDate = Get-Date
            $hoursDifference = ($currentDate - $lastModified).TotalHours

            $needsUpdate = $hoursDifference -gt ($DaysToRefresh * 24)
        }
        else {
            $needsUpdate = $true
        }

        if ($needsUpdate) {
            Invoke-WebRequest -Uri $uri -OutFile $CatalogPath
            Write-Host "Catalog updated."
        }
        else {
            Write-Host "Using cached catalog."
        }
    }
    catch {
        Write-Error "Error updating catalog: $_"
    }
}

function Compare-Versions {
    param (
        [string]$version1,
        [string]$version2
    )

    $parts1 = $version1 -split '(\d+|\D+)'
    $parts2 = $version2 -split '(\d+|\D+)'

    for ($i = 0; $i -lt [math]::Min($parts1.Length, $parts2.Length); $i++) {
        $part1 = $parts1[$i]
        $part2 = $parts2[$i]

        if ($part1 -match '^\d+$' -and $part2 -match '^\d+$') {
            if ([int]$part1 -lt [int]$part2) {
                return -1
            }
            elseif ([int]$part1 -gt [int]$part2) {
                return 1
            }
        }
        else {
            if ($part1 -lt $part2) {
                return -1
            }
            elseif ($part1 -gt $part2) {
                return 1
            }
        }
    }

    return $parts1.Length - $parts2.Length
}

function Extract-File {
    param (
        [string]$File,
        [string]$ExactModelName
    )
    $defaultExtractPath = "C:\DRIVERS\SCCM"
    $destinationPath = Join-Path -Path $NetworkPath -ChildPath $ExactModelName
    try {
        if (-not (Test-Path -Path $File)) {
            throw "File not found: $File"
        }

        # Remove previously extracted folders, if any
        $extractedFolders = @()
        if (Test-Path -Path $defaultExtractPath) {
            $extractedFolders = Get-ChildItem -Path $defaultExtractPath | Where-Object { $_.PSIsContainer }
        }

        # Create destination folder if it doesn't exist
        Ensure-Directory -Path $destinationPath

        $arguments = "/VERYSILENT /EXTRACT=YES"

        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $File
        $startInfo.Arguments = $arguments
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.UseShellExecute = $false

        $process = [System.Diagnostics.Process]::Start($startInfo)
        $process.WaitForExit()

        $output = $process.StandardOutput.ReadToEnd()
        $error = $process.StandardError.ReadToEnd()

        if ($process.ExitCode -eq 0) {
            Write-Host "File extracted to $defaultExtractPath or C:\DRIVERS"
            $newExtractedFolders = Get-ChildItem -Path $defaultExtractPath -Recurse | Where-Object { $_.PSIsContainer -and -not ($_.FullName -in $extractedFolders.FullName) }

            if ($newExtractedFolders.Count -eq 0) {
                $defaultExtractPath = "C:\DRIVERS"
                $newExtractedFolders = Get-ChildItem -Path $defaultExtractPath -Recurse | Where-Object { $_.PSIsContainer -and -not ($_.FullName -in $extractedFolders.FullName) }
            }

            foreach ($folder in $newExtractedFolders) {
                $relativePath = $folder.FullName.Substring($defaultExtractPath.Length).TrimStart('\')
                $destinationSubPath = Join-Path -Path $destinationPath -ChildPath $relativePath
                if (-not (Test-Path -Path $destinationSubPath)) {
                    Copy-Item -Path $folder.FullName -Destination $destinationSubPath -Recurse
                    Write-Host "Folder copied to $destinationSubPath"
                }
                else {
                    Write-Host "Destination path already exists: $destinationSubPath"
                }
            }

            # Remove extracted folders from SCCM folder
            foreach ($folder in $newExtractedFolders) {
                try {
                    if (Test-Path -Path $folder.FullName) {
                        Remove-Item -Path $folder.FullName -Recurse -Force
                        Write-Host "Removed folder: $($folder.FullName)"
                    }
                }
                catch {
                    Write-Error ("Error removing folder: {0} - {1}" -f $folder.FullName, $_)
                }
            }

            # Remove downloaded file
            try {
                if (Test-Path -Path $File) {
                    Remove-Item -Path $File -Force
                    Write-Host "Removed downloaded file: $File"
                }
            }
            catch {
                Write-Error ("Error removing downloaded file: {0} - {1}" -f $File, $_)
            }
        }
        else {
            Write-Error ("Error extracting file: Exit code {0}, Error: {1}" -f $process.ExitCode, $error)
        }
    }
    catch {
        Write-Error ("Error extracting file: {0}" -f $_)
    }
}

function Get-LenovoDriverPack {
    param (
        [string]$ModelName
    )
    try {
        Update-Catalog
        [xml]$catalog = Get-Content -Path $CatalogPath

        Write-Host "Loaded XML catalog, length: $($catalog.OuterXml.Length)"

        $models = $catalog.SelectNodes("//Model[contains(@name, '$ModelName')]")
        $downloadedUrls = @()

        Write-Host "Number of models found: $($models.Count)"

        foreach ($model in $models) {
            $exactModelName = $model.name
            Write-Host "Model name: $exactModelName"
            $driverUrls = $model.SCCM

            $selectedUrl = $null
            $selectedVersion = $null
            $selectedOs = $null

            foreach ($sccm in $driverUrls) {
                $url = $sccm.InnerText
                $os = $sccm.os
                $version = $sccm.version

                if ($os -eq "win11") {
                    if ($selectedOs -ne "win11" -or (Compare-Versions $version $selectedVersion) -gt 0) {
                        $selectedUrl = $url
                        $selectedVersion = $version
                        $selectedOs = $os
                    }
                }
                elseif ($os -eq "win10") {
                    if ($selectedOs -ne "win11" -and ($selectedVersion -eq $null -or (Compare-Versions $version $selectedVersion) -gt 0)) {
                        $selectedUrl = $url
                        $selectedVersion = $version
                        $selectedOs = $os
                    }
                }
            }

            if ($selectedUrl) {
                Write-Host "Found URL: $selectedUrl ($selectedOs $selectedVersion)"
                $fileName = Split-Path -Path $selectedUrl -Leaf
                $destinationPath = Join-Path -Path $DownloadPath -ChildPath $fileName

                # Download file only if it doesn't already exist
                if (-not (Test-Path -Path $destinationPath)) {
                    Write-Host "Downloading $fileName..."

                    # Use Start-BitsTransfer for downloading
                    Start-BitsTransfer -Source $selectedUrl -Destination $destinationPath

                    Write-Host "Driver downloaded successfully to $destinationPath"
                }
                else {
                    Write-Host "File already exists: $destinationPath"
                }

                # Create the model folder and the firmware folder inside it
                $modelNetworkPath = Join-Path -Path $NetworkPath -ChildPath $exactModelName
                $firmwarePath = Join-Path -Path $modelNetworkPath -ChildPath "Firmware"
                Ensure-Directory -Path $modelNetworkPath
                Ensure-Directory -Path $firmwarePath

                # Extract file and copy folder
                Extract-File -File $destinationPath -ExactModelName $exactModelName

                $downloadedUrls += $selectedUrl

                # Store the firmware path for later use
                $global:firmwarePath = $firmwarePath
            }
            else {
                Write-Host "No compatible driver package found for model: $ModelName."
            }
        }

        if ($models.Count -eq 0) {
            Write-Host "No compatible driver package found for model: $ModelName."
        }
    }
    catch {
        Write-Error ("Error retrieving Lenovo driver package for model {0}: {1}" -f $ModelName, $_)
    }
}

function Download-FirmwareUpdates {
    param (
        [string]$ModelName
    )
    try {
        Write-Host "Importing LSUClient module..."
        if (-not (Get-Module -ListAvailable -Name 'LSUClient')) {
            Install-Module -Name 'LSUClient' -Scope CurrentUser -Force -ErrorAction Stop
        }
        Import-Module -Name 'LSUClient' -ErrorAction Stop

        Write-Host "Fetching updates for model $ModelName..."
        $updates = Get-LSUpdate -Model $ModelName -All

        # Suodata vain BIOS päivitykset, jos IncludeFirmware on asetettu
        if ($IncludeFirmware) {
            $updates = $updates | Where-Object { $_.Type -eq 'Firmware' -or $_.Type -eq 'BIOS' }
        } else {
            $updates = $updates | Where-Object { $_.Type -eq 'BIOS' }
        }

        if ($updates.Count -eq 0) {
            Write-Host "No updates found for model $ModelName."
            return
        }

        Write-Host "Saving updates to $global:firmwarePath..."
        $updates | Save-LSUpdate -Path $global:firmwarePath -ShowProgress -Verbose

        Write-Host "Updates for model $ModelName downloaded and saved successfully."
    } catch {
        Write-Error ("Error downloading updates for model {0}: {1}" -f $ModelName, $_)
    }
}

# Main script logic
if ($ModelName) {
    Write-Host "Model name provided: $ModelName"
    Get-LenovoDriverPack -ModelName $ModelName

    if ($IncludeFirmware) {
        Download-FirmwareUpdates -ModelName $ModelName
    }
} elseif ($CsvPath -ne $null -and $CsvPath -ne "") {
    Write-Host "CSV path provided: $CsvPath"
    $modelNames = Import-Csv -Path $CsvPath | Select-Object -ExpandProperty Model
    if ($modelNames.Count -gt 0) {
        foreach ($modelName in $modelNames) {
            if (-not [string]::IsNullOrWhiteSpace($modelName)) {
                Write-Host "Processing model: $modelName"
                Get-LenovoDriverPack -ModelName $modelName

                if ($IncludeFirmware) {
                    Download-FirmwareUpdates -ModelName $modelName
                }
            } else {
                Write-Host "Error: Model name is empty or null."
            }
        }
    } else {
        Write-Host "No models to process."
    }
} else {
    Write-Host "Invalid selection. Please provide either a single model name or a CSV file path."
}
