param (
    [string]$ModelName,
    [string]$DownloadPath,
    [string]$NetworkPath,
    [string]$CsvPath = $null,
    [switch]$IncludeFirmware
)

function Ensure-Directory {
    param (
        [string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path | Out-Null
            Write-Host "Created directory: $Path"
        } catch {
            Write-Error "Error creating directory ${Path}: $_"
        }
    }
}

function Download-FirmwareUpdates {
    param (
        [string]$ModelName,
        [string]$InfoFilePath
    )
    try {
        Write-Host "Importing LSUClient module..."
        if (-not (Get-Module -ListAvailable -Name 'LSUClient')) {
            Install-Module -Name 'LSUClient' -Scope CurrentUser -Force -ErrorAction Stop
        }
        Import-Module -Name 'LSUClient' -ErrorAction Stop

        if (-not (Test-Path -Path $InfoFilePath)) {
            throw "Info file not found: $InfoFilePath"
        }

        $FinalNetworkPath = Get-Content -Path $InfoFilePath
        Ensure-Directory -Path $FinalNetworkPath

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

        Write-Host "Saving updates to $FinalNetworkPath..."
        $updates | Save-LSUpdate -Path $FinalNetworkPath -ShowProgress -Verbose

        Write-Host "Updates for model $ModelName downloaded and saved successfully."
    } catch {
        Write-Error "Error downloading updates for model ${ModelName}: $_"
    }
}

if ($CsvPath) {
    $modelNames = Import-Csv -Path $CsvPath | Select-Object -ExpandProperty Model
    foreach ($modelName in $modelNames) {
        Download-FirmwareUpdates -ModelName $modelName -InfoFilePath "$NetworkPath\last_extracted_directory.txt"
    }
} else {
    Download-FirmwareUpdates -ModelName $ModelName -InfoFilePath "$NetworkPath\last_extracted_directory.txt"
}
