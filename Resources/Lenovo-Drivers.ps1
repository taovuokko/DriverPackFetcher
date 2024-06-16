param (
    [string]$DownloadPath = "$env:USERPROFILE\Downloads\.Lenovo",
    [string]$CatalogPath = "$env:USERPROFILE\Downloads\.Lenovo\LenovoDriverPackCatalog.xml",
    [string]$NetworkPath = "$env:USERPROFILE\Documents\LocalLenovo",
    [int]$DaysToRefresh = 40,
    [string]$ModelName = $null,
    [string]$CsvPath = $null
)

Write-Host "Download path: $DownloadPath"
Write-Host "Catalog path: $CatalogPath"
Write-Host "Network path: $NetworkPath"
Write-Host "Days to refresh: $DaysToRefresh"

function Ensure-Directory {
    param (
        [string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path | Out-Null
            Write-Host "Created directory: $Path"
        } catch {
            Write-Error "Error creating directory $Path: $_"
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
        [string]$ModelName,
        [string]$ExactModelName
    )
    $defaultExtractPath = "C:\DRIVERS\SCCM"
    $destinationPath = Join-Path -Path $NetworkPath -ChildPath $ExactModelName
    $infoFilePath = Join-Path -Path $NetworkPath -ChildPath "last_extracted_directory.txt"
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
                $destinationSubPath = Join-Path -Path $destinationPath -ChildPath $folder.Name
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
                    Remove-Item -Path $folder.FullName -Recurse -Force
                    Write-Host "Removed folder: $($folder.FullName)"
                }
                catch {
                    Write-Error "Error removing folder: $($folder.FullName) - $_"
                }
            }

            # Write the path to the info file
            $destinationPath | Out-File -FilePath $infoFilePath -Force

            # Remove downloaded file
            try {
                Remove-Item -Path $File -Force
                Write-Host "Removed downloaded file: $File"
            }
            catch {
                Write-Error "Error removing downloaded file: $File - $_"
            }
        }
        else {
            Write-Error "Error extracting file: Exit code $($process.ExitCode), Error: $error"
        }
    }
    catch {
        Write-Error "Error extracting file: $_"
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

                # Extract file and copy folder
                Extract-File -File $destinationPath -ModelName $ModelName -ExactModelName $exactModelName

                $downloadedUrls += $selectedUrl
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
        Write-Error "Error retrieving Lenovo driver package for model ${ModelName}: $_"
    }
}

function Get-ModelNamesFromCsv {
    param (
        [string]$CsvPath
    )
    try {
        Write-Host "Reading CSV file: $CsvPath"
        $modelNames = Import-Csv -Path $CsvPath | Select-Object -ExpandProperty Model
        Write-Host "Models found in CSV: $($modelNames -join ', ')"
        return $modelNames
    } catch {
        Write-Error "Error reading CSV file: $_"
        return @()  # Return an empty array if there's an error
    }
}

# Main script logic
Ensure-Directory -Path $NetworkPath

if ($ModelName) {
    Write-Host "Model name provided: $ModelName"
    Get-LenovoDriverPack -ModelName $ModelName
} elseif ($CsvPath -ne $null -and $CsvPath -ne "") {
    Write-Host "CSV path provided: $CsvPath"
    $modelNames = Get-ModelNamesFromCsv -CsvPath $CsvPath
    if ($modelNames.Count -gt 0) {
        foreach ($modelName in $modelNames) {
            if (-not [string]::IsNullOrWhiteSpace($modelName)) {
                Write-Host "Processing model: $modelName"
                Get-LenovoDriverPack -ModelName $modelName
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
