param (
    [string]$option,
    [string]$modelName,
    [string]$csvFilePath = "",
    [string]$downloadPath,
    [string]$networkPath,
    [string]$configPath
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

# Function to ensure a directory exists
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

# Function to expand environment variables in a path
function Expand-EnvironmentVariables {
    param (
        [string]$Path
    )
    return [System.Environment]::ExpandEnvironmentVariables($Path)
}

# Function to download and extract driver
function Download-And-ExtractDriver {
    param (
        [string]$modelName,
        [string]$localPath
    )

    Write-Host "Starting Download-And-ExtractDriver for model: $modelName"
    Write-Host "Local path is: $localPath"

    # Define the path to the pre-extracted XML file and destination folder
    $catalogXMLFile = Join-Path $PSScriptRoot "DriverPackCatalog.xml"
    $downloadFolder = Join-Path $PSScriptRoot "Downloads"
    $destinationFolder = Join-Path $localPath $modelName

    Write-Host "Catalog XML file path: $catalogXMLFile"
    Write-Host "Download folder path: $downloadFolder"
    Write-Host "Destination folder path: $destinationFolder"

    # Check if the XML file exists
    if (-not (Test-Path -Path $catalogXMLFile)) {
        Write-Host "Error: DriverPackCatalog.xml not found."
        exit 1
    }

    # Create download folder if it doesn't exist
    Ensure-Directory -Path $downloadFolder

    # Create destination folder if it doesn't exist
    Ensure-Directory -Path $destinationFolder

    # Parse the XML file
    Write-Host "Parsing DriverPackCatalog.xml..."
    try {
        [xml]$catalogXMLDoc = Get-Content $catalogXMLFile
        Write-Host "Parsed DriverPackCatalog.xml successfully."
    }
    catch {
        Write-Host "Error: Failed to parse DriverPackCatalog.xml. $_"
        exit 1
    }

    # Find the driver package for the specified model, prefer Windows 11, otherwise Windows 10
    Write-Host "Searching for driver package for model: $modelName..."
    $driverPackage = $catalogXMLDoc.DriverPackManifest.DriverPackage | Where-Object {
        ($_.SupportedSystems.Brand.Model.name -eq $modelName) -and 
        ($_.type -eq "win") -and 
        (($_.SupportedOperatingSystems.OperatingSystem.majorVersion -eq "10" -and $_.SupportedOperatingSystems.OperatingSystem.minorVersion -eq "1") -or 
         ($_.SupportedOperatingSystems.OperatingSystem.majorVersion -eq "10" -and $_.SupportedOperatingSystems.OperatingSystem.minorVersion -eq "0"))
    } | Sort-Object {
        if ($_.SupportedOperatingSystems.OperatingSystem.minorVersion -eq "1") {
            return 1
        } else {
            return 2
        }
    } | Select-Object -First 1

    # Check if driver package was found
    if ($null -eq $driverPackage) {
        Write-Host "No driver package found for model: $modelName"
        exit 1
    }
    else {
        Write-Host "Driver package found for model: $modelName"
    }

    # Construct the download link for the driver package
    $baseLocation = $catalogXMLDoc.DriverPackManifest.baseLocation
    $driverPath = $driverPackage.path
    $driverDownloadLink = "http://$baseLocation/$driverPath"

    Write-Host "Driver download link: $driverDownloadLink"

    # Download the driver package
    $driverFileName = [System.IO.Path]::GetFileName($driverDownloadLink)
    $driverDownloadPath = Join-Path $downloadFolder $driverFileName
    Write-Host "Downloading driver package to: $driverDownloadPath..."
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($driverDownloadLink, $driverDownloadPath)
        Write-Host "Driver package downloaded successfully to $driverDownloadPath"
    }
    catch {
        Write-Host "Error: Failed to download driver package. $_"
        exit 1
    }

    # Extract the driver package using 7-Zip
    Write-Host "Extracting driver package to: $destinationFolder..."
    $sevenZipPath = "C:\Program Files\7-Zip\7z.exe"  # Update this to the correct path if necessary
    if (-not (Test-Path -Path $sevenZipPath)) {
        Write-Host "Error: 7-Zip executable not found at $sevenZipPath"
        exit 1
    }

    try {
        Start-Process -FilePath $sevenZipPath -ArgumentList "x `"$driverDownloadPath`" -o`"$destinationFolder`" -y" -NoNewWindow -Wait
        Write-Host "Driver package extracted successfully to $destinationFolder"
    }
    catch {
        Write-Host "Error: Failed to extract driver package using 7-Zip. $_"
        exit 1
    }

    # Check if the extracted folder exists
    if (Test-Path -Path $destinationFolder) {
        Write-Host "Driver package for model $modelName processed successfully."
    }
    else {
        Write-Host "Error: The extracted folder does not exist."
        exit 1
    }
}

# Function to process models from CSV file
function Process-ModelsFromCSV {
    param (
        [string]$csvFilePath,
        [string]$localPath
    )

    Write-Host "Starting Process-ModelsFromCSV"
    Write-Host "CSV file path: $csvFilePath"
    Write-Host "Local path is: $localPath"

    if (-not (Test-Path -Path $csvFilePath)) {
        Write-Host "Error: CSV file not found."
        exit 1
    }

    try {
        $models = Import-Csv -Path $csvFilePath
        foreach ($model in $models) {
            Write-Host "Read model: $($model.Model)"
            if (-not [string]::IsNullOrWhiteSpace($model.Model)) {
                Write-Host "Processing model: $($model.Model)"
                Download-And-ExtractDriver -modelName $model.Model -localPath $localPath
            } else {
                Write-Host "Error: Model name is empty or null."
            }
        }
    }
    catch {
        Write-Host "Error: Failed to process CSV file. $_"
        exit 1
    }
}

# Main script
function Main {
    param (
        [string]$option,
        [string]$modelName,
        [string]$csvFilePath = "",
        [string]$downloadPath,
        [string]$networkPath,
        [string]$configPath
    )

    Write-Host "Starting Main function"
    Write-Host "Option: $option"
    Write-Host "Model name: $modelName"
    Write-Host "CSV file path: $csvFilePath"

    # Read the config file
    $config = Read-Config -configPath $configPath

    # Expand environment variables in paths
    $expandedNetworkPath = Expand-EnvironmentVariables $networkPath

    if ($option -eq "1") {
        Download-And-ExtractDriver -modelName $modelName -localPath $expandedNetworkPath
    }
    elseif ($option -eq "2") {
        Process-ModelsFromCSV -csvFilePath $csvFilePath -localPath $expandedNetworkPath
    }
    else {
        Write-Host "Invalid option. Please select a valid option."
        exit 1
    }
}

# Call the main function with provided arguments
Main -option $option -modelName $modelName -csvFilePath $csvFilePath -downloadPath $downloadPath -networkPath $networkPath -configPath $configPath
