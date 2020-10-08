function GetImportExportStatus($request, [String]$activityMessage = "Importing / Exporting Db", [int]$writeProgressId = 0) {
    $importStatus = Get-AzSqlDatabaseImportExportStatus -OperationStatusLink $request.OperationStatusLink

    if ($importStatus.ErrorMessage) {
        # Catch and print the error message and mar this as done becuase nothing further can be done
        Write-Progress -Id $writeProgressId -Activity ("${activityMessage} ERROR") -Status $importStatus.ErrorMessage
        [Console]::Error("!!! ERROR: ${importStatus.ErrorMessage}")
        return -1
    } elseif ($importStatus.Status -eq "Succeeded") {
        # If we succeeded, mark this as done
        Write-Progress -Id $writeProgressId -Activity ("${activityMessage} Status") -Status $importStatus.Status
        return 1
    } elseif ($importStatus.StatusMessage) {
        # Print out the current status percentage, usually "Running, Progress, 0%"
        Write-Progress -Id $writeProgressId -Activity ("${activityMessage} Status Message") -Status $importStatus.StatusMessage
        return 0
    } elseif ($importStatus.Status) {
        # Pending or otherwise. NOT Succeeded, that's handled earlier.
        Write-Progress -Id $writeProgressId -Activity ("${activityMessage} Status") -Status $importStatus.Status
        return 0
    } else {
        # Hopefully we don't hit this!
        [Console]::Error("!!! Something unexpected happened when ${activityMessage}!")
        return -1
    }
}