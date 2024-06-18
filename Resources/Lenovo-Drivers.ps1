param (
    [string]$ModelName,
    [string]$DownloadPath,
    [string]$NetworkPath,
    [string]$ConfigPath,
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

function Download-LenovoUpdates {
    param (
        [string]$ModelName,
        [string]$NetworkPath,
        [switch]$IncludeFirmware
    )

    Write-Host "Importing LSUClient module..."
    if (-not (Get-Module -ListAvailable -Name 'LSUClient')) {
        Install-Module -Name 'LSUClient' -Scope CurrentUser -Force -ErrorAction Stop
    }
    Import-Module -Name 'LSUClient' -ErrorAction Stop

    Write-Host "Fetching updates for model $ModelName..."
    $updates = Get-LSUpdate -Model $ModelName -All

    # Filter updates based on IncludeFirmware parameter
    if ($IncludeFirmware) {
        $updates = $updates | Where-Object { $_.Type -eq 'Firmware' -or $_.Type -eq 'BIOS' -or $_.Type -eq 'Driver' }
    } else {
        $updates = $updates | Where-Object { $_.Type -eq 'Driver' }
    }

    if ($updates.Count -eq 0) {
        Write-Host "No updates found for model $ModelName."
        return
    }

    Write-Host "Saving updates to $NetworkPath..."
    $updates | ForEach-Object {
        $packagePath = Join-Path -Path $NetworkPath -ChildPath $_.ID
        Ensure-Directory -Path $packagePath
        Save-LSUpdate -Package $_ -Path $packagePath -ShowProgress -Verbose
    }

    Write-Host "Updates for model $ModelName downloaded and saved successfully."
}

function Load-Config {
    param (
        [string]$ConfigPath
    )
    try {
        $config = Get-Content -Path $ConfigPath | ConvertFrom-Json
        return $config
    } catch {
        Write-Error "Failed to load configuration: $_"
        exit 1
    }
}

# Main script logic
$config = Load-Config -ConfigPath $ConfigPath

$DownloadPath = $config.Lenovo.DownloadPath -replace '%USERPROFILE%', $env:USERPROFILE
$NetworkPath = $config.Lenovo.NetworkPath -replace '%USERPROFILE%', $env:USERPROFILE

Write-Host "Download path: $DownloadPath"
Write-Host "Network path: $NetworkPath"

Ensure-Directory -Path $DownloadPath
Ensure-Directory -Path $NetworkPath

if ($ModelName) {
    $modelDirectoryName = $ModelName -replace '[^\w\-]', '_'
    $finalDownloadPath = Join-Path -Path $NetworkPath -ChildPath $modelDirectoryName
    Ensure-Directory -Path $finalDownloadPath
    Download-LenovoUpdates -ModelName $ModelName -NetworkPath $finalDownloadPath -IncludeFirmware:$IncludeFirmware
} elseif ($CsvPath) {
    $modelNames = Import-Csv -Path $CsvPath | Select-Object -ExpandProperty Model
    foreach ($modelName in $modelNames) {
        $modelDirectoryName = $modelName -replace '[^\w\-]', '_'
        $finalDownloadPath = Join-Path -Path $NetworkPath -ChildPath $modelDirectoryName
        Ensure-Directory -Path $finalDownloadPath
        Download-LenovoUpdates -ModelName $modelName -NetworkPath $finalDownloadPath -IncludeFirmware:$IncludeFirmware
    }
} else {
    Write-Host "Invalid selection. Please provide either a single model name or a CSV file path."
}
