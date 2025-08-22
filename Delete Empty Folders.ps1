param (
    [string]$RootPath = "."
)

Write-Host "Deleting empty folders in: $RootPath`n"

# Step 1: Find all empty folders
$emptyFolders = Get-ChildItem -Path $RootPath -Directory -Recurse |
    Where-Object {
        @(Get-ChildItem $_.FullName -Force | Where-Object { -not $_.PSIsContainer }).Count -eq 0
    } |
    Sort-Object FullName -Descending

$total = $emptyFolders.Count
$counter = 0

# Step 2: Delete folders with progress bar
foreach ($folder in $emptyFolders) {
    $counter++
    $percentComplete = [math]::Round(($counter / $total) * 100)

    Write-Progress -Activity "Deleting Empty Folders" `
                   -Status "Processing: $($folder.FullName)" `
                   -PercentComplete $percentComplete

    Remove-Item $folder.FullName -Force
}

Write-Progress -Activity "Deleting Empty Folders" -Completed
Write-Host "Done. Deleted $total empty folder(s)."

