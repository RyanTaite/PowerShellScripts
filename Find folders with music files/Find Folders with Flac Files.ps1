# .\Find-FlacFolders.ps1 -TargetFolder "C:\Music" -OutputFile "C:\flac_folders.txt"

param(
    [Parameter(Mandatory = $true)]
    [string]$TargetFolder,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

# Stop on any error
$ErrorActionPreference = "Stop"

# If OutputFile is a folder path, append default file name
if (Test-Path $OutputFile -PathType Container -ErrorAction SilentlyContinue) {
    $OutputFile = Join-Path $OutputFile "flac_folders.txt"
}
elseif (-not (Split-Path $OutputFile -Leaf)) {
    # Handle case where a UNC path ends with a slash (e.g. \\Server\Share\Folder\)
    $OutputFile = Join-Path $OutputFile "flac_folders.txt"
}

Write-Host "Getting folders to scan..."

# Get all subfolders (including root if you want)
$allFolders = Get-ChildItem -Path $TargetFolder -Directory -Recurse
$total = $allFolders.Count
$counter = 0

$foldersWithFlac = @()

foreach ($folder in $allFolders) {
    $counter++

    # Update progress bar
    Write-Progress -Activity "Scanning folders for FLAC files" `
                   -Status "Checking: $($folder.FullName)" `
                   -PercentComplete (($counter / $total) * 100)

    # Check if folder contains at least one .flac
    if (Get-ChildItem -Path $folder.FullName -Filter *.flac -File -ErrorAction SilentlyContinue) {
        $foldersWithFlac += $folder.FullName
    }
}

Write-Progress -Activity "Scanning folders for FLAC files" -Completed

# Save results to text file
$foldersWithFlac | Sort-Object -Unique | Out-File -FilePath $OutputFile -Encoding UTF8

Write-Host "Results saved to $OutputFile"
