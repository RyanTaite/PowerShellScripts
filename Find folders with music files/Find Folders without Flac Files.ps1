param(
    [Parameter(Mandatory = $true)]
    [string]$TargetFolder,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

# Stop on any error
$ErrorActionPreference = "Stop"

# Get all subfolders (including root if you want)
$allFolders = Get-ChildItem -Path $TargetFolder -Directory -Recurse -ErrorAction Stop
$total = $allFolders.Count
$counter = 0

$foldersWithoutFlac = @()

foreach ($folder in $allFolders) {
    $counter++

    # Update progress bar
    Write-Progress -Activity "Scanning folders for FLAC files" `
                   -Status "Checking: $($folder.FullName)" `
                   -PercentComplete (($counter / $total) * 100)

    # Check if folder does NOT contain any .flac
    $flacFiles = Get-ChildItem -Path $folder.FullName -Filter *.flac -File -ErrorAction Stop
    if (-not $flacFiles) {
        $foldersWithoutFlac += $folder.FullName
    }
}

Write-Progress -Activity "Scanning folders for FLAC files" -Completed

# Save results to text file
$foldersWithoutFlac | Sort-Object -Unique | Out-File -FilePath $OutputFile -Encoding UTF8 -ErrorAction Stop

Write-Host "Results saved to $OutputFile"
