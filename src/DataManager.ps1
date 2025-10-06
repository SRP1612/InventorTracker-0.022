# src/DataManager.ps1
# This module handles loading, saving, and exporting tracking data

function Import-TrackingData {
    <#
    .SYNOPSIS
    Loads tracking data from a JSON file
    
    .PARAMETER FilePath
    Path to the JSON file containing tracking data
    
    .EXAMPLE
    $data = Import-TrackingData -FilePath "activity_data.json"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        try {
            $jsonContent = Get-Content $FilePath -Raw | ConvertFrom-Json
            
            # Convert PSCustomObject to hashtable for easier manipulation
            $trackingData = @{}
            if ($jsonContent) {
                # Check if this is the new format with metadata wrapper
                if ($jsonContent.PSObject.Properties.Name -contains "TrackingData" -and $jsonContent.PSObject.Properties.Name -contains "Metadata") {
                    # New format: extract tracking data from wrapper
                    $sourceData = $jsonContent.TrackingData
                    Write-Host "Loaded data from: $($jsonContent.Metadata.ComputerName)\$($jsonContent.Metadata.UserName) exported at $($jsonContent.Metadata.ExportTime)" -ForegroundColor Cyan
                } else {
                    # Old format: use the entire object as tracking data
                    $sourceData = $jsonContent
                    Write-Host "Loaded legacy format tracking data" -ForegroundColor Yellow
                }
                
                # Convert to hashtable - handle both old and new formats
                $sourceData.PSObject.Properties | ForEach-Object {
                    if ($_.Value.PSObject.Properties.Name -contains "DailyActivity") {
                        # New format: per-day tracking
                        $dailyData = @{}
                        $_.Value.DailyActivity.PSObject.Properties | ForEach-Object {
                            $dailyData[$_.Name] = @{
                                TotalActiveSeconds = $_.Value.TotalActiveSeconds
                                LastSeenTime = $_.Value.LastSeenTime
                            }
                        }
                        $trackingData[$_.Name] = @{
                            DailyActivity = $dailyData
                        }
                    } else {
                        # Old format: convert to new format with today's date
                        $today = (Get-Date).ToString("yyyy-MM-dd")
                        $trackingData[$_.Name] = @{
                            DailyActivity = @{
                                $today = @{
                                    TotalActiveSeconds = $_.Value.TotalActiveSeconds
                                    LastSeenTime = $_.Value.LastSeenTime
                                }
                            }
                        }
                    }
                }
            }
            
            Write-Host "Loaded tracking data for $($trackingData.Count) files" -ForegroundColor Green
            return $trackingData
        }
        catch {
            Write-Warning "Failed to load tracking data from $FilePath`: $_"
            return @{}
        }
    }
    
    Write-Host "No existing tracking data found, starting fresh" -ForegroundColor Yellow
    return @{}
}

function Export-TrackingData {
    <#
    .SYNOPSIS
    Saves tracking data to a JSON file with atomic write operation
    
    .PARAMETER FilePath
    Path where the JSON file will be saved
    
    .PARAMETER Data
    Hashtable containing the tracking data
    
    .EXAMPLE
    Export-TrackingData -FilePath "activity_data.json" -Data $trackingData
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        
        [Parameter(Mandatory)]
        [hashtable]$Data
    )
    
    $tempPath = "$($FilePath).tmp"
    
    try {
        # Create a new hashtable with metadata and tracking data
        $exportData = @{
            Metadata = @{
                ComputerName = $env:COMPUTERNAME
                UserName = $env:USERNAME
                ExportTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                Version = "1.0"
            }
            TrackingData = $Data
        }
        
        # Convert hashtable to JSON with proper formatting
        $jsonData = $exportData | ConvertTo-Json -Depth 10
        
        # Write to temporary file first (atomic operation)
        [System.IO.File]::WriteAllText($tempPath, $jsonData, [System.Text.Encoding]::UTF8)
        
        # Move to final location (atomic on same filesystem)
        Move-Item -Path $tempPath -Destination $FilePath -Force
        
        # Always show a visible confirmation in the console when a save completes
        Write-Host "Successfully saved tracking data to $FilePath" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Failed to save tracking data to $FilePath`: $_"
        
        # Clean up temp file if it exists
        if (Test-Path $tempPath) {
            try { Remove-Item $tempPath -Force } catch { }
        }
    }
}

function Export-TrackingDataToCsv {
    <#
    .SYNOPSIS
    Exports tracking data to a CSV file for analysis
    
    .PARAMETER CsvPath
    Path where the CSV file will be saved
    
    .PARAMETER TrackingData
    Hashtable containing the tracking data
    
    .EXAMPLE
    Export-TrackingDataToCsv -CsvPath "activity_export.csv" -TrackingData $trackingData
    #>
    param(
        [Parameter(Mandatory)]
        [string]$CsvPath,
        
        [Parameter(Mandatory)]
        [hashtable]$TrackingData
    )
    
    try {
        # Convert tracking data to CSV-friendly objects
        $csvOutput = $TrackingData.GetEnumerator() | ForEach-Object {
            $fileName = if ($_.Name) { Split-Path $_.Name -Leaf } else { "Unknown" }
            $fullPath = $_.Name
            
            # Process each day for this file
            if ($_.Value.DailyActivity) {
                $_.Value.DailyActivity.GetEnumerator() | ForEach-Object {
                    $date = $_.Name
                    $dayData = $_.Value
                    $totalSeconds = if ($dayData.TotalActiveSeconds) { [math]::Round($dayData.TotalActiveSeconds, 2) } else { 0 }
                    $lastSeen = if ($dayData.LastSeenTime) { $dayData.LastSeenTime } else { "Never" }
                    $totalMinutes = [math]::Round($totalSeconds / 60, 2)
                    $totalHours = [math]::Round($totalSeconds / 3600, 2)
                    
                    [PSCustomObject]@{
                        Date = $date
                        FileName = $fileName
                        FullPath = $fullPath
                        TotalActiveSeconds = $totalSeconds
                        TotalActiveMinutes = $totalMinutes
                        TotalActiveHours = $totalHours
                        LastSeenTime = $lastSeen
                    }
                }
            }
        } | Sort-Object Date, TotalActiveSeconds -Descending
        
        # Export to CSV
        $csvOutput | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        
        $fileCount = $csvOutput.Count
        $totalHours = ($csvOutput | Measure-Object TotalActiveHours -Sum).Sum
        
        Write-Host "Successfully exported CSV with $fileCount files" -ForegroundColor Green
        Write-Host "Total tracked time: $([math]::Round($totalHours, 2)) hours" -ForegroundColor Cyan
        Write-Host "CSV saved to: $CsvPath" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Failed to export CSV to $CsvPath`: $_"
    }
}

function Get-TrackingDataSummary {
    <#
    .SYNOPSIS
    Returns a summary of the current tracking data
    
    .PARAMETER TrackingData
    Hashtable containing the tracking data
    
    .EXAMPLE
    $summary = Get-TrackingDataSummary -TrackingData $trackingData
    Write-Host "Tracking $($summary.FileCount) files"
    #>
    param(
        [Parameter(Mandatory)]
        [hashtable]$TrackingData
    )
    
    $fileCount = $TrackingData.Count
    
    # Calculate total seconds across all files and all days
    $totalSeconds = 0
    $totalDays = 0
    foreach ($fileData in $TrackingData.Values) {
        if ($fileData -and $fileData.ContainsKey('DailyActivity')) {
            foreach ($dayData in $fileData.DailyActivity.Values) {
                if ($dayData -and $dayData.ContainsKey('TotalActiveSeconds')) {
                    $totalSeconds += $dayData.TotalActiveSeconds
                    $totalDays++
                }
            }
        }
    }
    
    $totalHours = [math]::Round($totalSeconds / 3600, 2)
    
    # Find most active file (sum across all days)
    $mostActiveFile = "None"
    if ($fileCount -gt 0) {
        $maxSeconds = 0
        foreach ($entry in $TrackingData.GetEnumerator()) {
            $fileTotal = 0
            if ($entry.Value.DailyActivity) {
                foreach ($dayData in $entry.Value.DailyActivity.Values) {
                    $fileTotal += $dayData.TotalActiveSeconds
                }
            }
            if ($fileTotal -gt $maxSeconds) {
                $maxSeconds = $fileTotal
                $mostActiveFile = $entry.Name
            }
        }
    }
    
    return @{
        FileCount = $fileCount
        TotalDays = $totalDays
        TotalActiveSeconds = $totalSeconds
        TotalActiveHours = $totalHours
        MostActiveFile = $mostActiveFile
    }
}

function Get-TrackingDataMetadata {
    <#
    .SYNOPSIS
    Extracts metadata from a tracking data JSON file
    
    .PARAMETER FilePath
    Path to the JSON file containing tracking data
    
    .EXAMPLE
    $metadata = Get-TrackingDataMetadata -FilePath "activity_data.json"
    Write-Host "Data from: $($metadata.ComputerName)\$($metadata.UserName)"
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return $null
    }
    
    try {
        $jsonContent = Get-Content $FilePath -Raw | ConvertFrom-Json
        
        # Check if this is the new format with metadata
        if ($jsonContent.PSObject.Properties.Name -contains "Metadata") {
            return @{
                ComputerName = $jsonContent.Metadata.ComputerName
                UserName = $jsonContent.Metadata.UserName
                ExportTime = $jsonContent.Metadata.ExportTime
                Version = $jsonContent.Metadata.Version
            }
        } else {
            # Legacy format - no metadata available
            return @{
                ComputerName = "Unknown"
                UserName = "Unknown"
                ExportTime = "Unknown"
                Version = "Legacy"
            }
        }
    }
    catch {
        Write-Warning "Failed to read metadata from $FilePath`: $_"
        return $null
    }
}
