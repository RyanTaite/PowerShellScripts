# Set error action preference to "Stop" to break on any error
$ErrorActionPreference = "Stop"

# Folder path to search for image files
$folderPath = "C:\Path\To\Your\Folder"

# Specify the path for the file to store unrecognized file names
$unrecognizedFilePath = "C:\Path\To\Your\Folder\UnrecognizedFiles.txt"

# Function to parse date from file name
function Get-DateFromFileName {
    param([string]$fileName, [string]$format)
    try {
        [System.DateTime]::ParseExact($fileName, $format, $null)
    }
    catch {
        Write-Host "Error parsing date from file name: $fileName. Format: $format"
        $unrecognizedFiles += $_.FullName
    }
}

# Function to update "Date Taken" property
function Update-DateTakenProperty {
    param([string]$filePath, [datetime]$newDate)
    try {
        [System.IO.File]::SetCreationTime($filePath, $newDate.ToString("yyyy-MM-ddTHH:mm:ss"))
    }
    catch {
        throw "Error updating the creation time: $_"
    }
}


# Array to store unrecognized file names
$unrecognizedFiles = @()

# Loop through each image file in the folder and its sub-folders
Get-ChildItem -Path $folderPath -Recurse -File -Include *.jpg, *.gif, *.mp4 | ForEach-Object {
    $fileName = $_.BaseName
    Write-Host "Updating" $_.FullName
    $newDate = $null
    if ($fileName -match '^signal-(?<datetimestamp>\d{4}-\d{2}-\d{2}-\d{6})$') {
        $newDate = Get-DateFromFileName -fileName $Matches.datetimestamp -format 'yyyy-MM-dd-HHmmss'
    }
    elseif ($fileName -match '^signal-(?<datetimestamp>\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2})$') {
        $newDate = Get-DateFromFileName -fileName $Matches.datetimestamp -format 'yyyy-MM-dd-HH-mm-ss'
    }
    elseif ($fileName -match '^PXL_(?<datetimestamp>\d{8}_\d{6})') {
        $newDate = Get-DateFromFileName -fileName $Matches.datetimestamp -format 'yyyyMMdd_HHmmss'
    }
    elseif ($fileName -match '^IMG_(?<datetimestamp>\d{8}_\d{6})') {
        $newDate = Get-DateFromFileName -fileName $Matches.datetimestamp -format 'yyyyMMdd_HHmmss'
    }
    elseif ($fileName -match '^(?<datetimestamp>\d{8}_\d{6})') {
        $newDate = Get-DateFromFileName -fileName $Matches.datetimestamp -format 'yyyyMMdd_HHmmss'
    }
    elseif ($fileName -match '^(?<datetimestamp>\d{8}-\d{6})') {
        $newDate = Get-DateFromFileName -fileName $Matches.datetimestamp -format 'yyyyMMdd-HHmmss'
    }
    else {
        $newDate = $null
        $unrecognizedFiles += $_.FullName
    }

    if ($newDate -ne $null) {
        Update-DateTakenProperty -filePath $_.FullName -newDate $newDate   
    }
}

# Display unrecognized file names
if ($unrecognizedFiles.Count -gt 0) {
    $errorMessage = "Unrecognized file names:`r`n" + ($unrecognizedFiles -join "`r`n")
    Write-Host $errorMessage
    $errorMessage | Out-File -FilePath $unrecognizedFilePath -Encoding UTF8
    Write-Host "Details written to: $unrecognizedFilePath"
}
else {
    Write-Host "All image files updated successfully."
}
