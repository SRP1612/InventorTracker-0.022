# DataManager.ps1
# Handles loading, saving, and exporting tracking data (no Reference dependencies)

function Import-TrackingData {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        try {
            $jsonContent = Get-Content $FilePath -Raw | ConvertFrom-Json
            $trackingData = @{}
            if ($jsonContent) {
                $sourceData = $jsonContent.TrackingData
                $sourceData.PSObject.Properties | ForEach-Object {
                    $dailyData = @{}
                    $_.Value.DailyActivity.PSObject.Properties | ForEach-Object {
                        $dailyData[$_.Name] = @{
                            TotalActiveSeconds = $_.Value.TotalActiveSeconds
                            LastSeenTime = $_.Value.LastSeenTime
                        }
                    }
                    $trackingData[$_.Name] = @{ DailyActivity = $dailyData }
                }
            }
            return $trackingData
        } catch { return @{} }
    }
    return @{}
}

function Export-TrackingData {
    param([string]$FilePath, [hashtable]$Data)
    # Ensure file exists in main folder, create if missing
    $folder = Split-Path $FilePath -Parent
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
    if (-not (Test-Path $FilePath)) {
        New-Item -ItemType File -Path $FilePath | Out-Null
    }
    $exportData = @{ Metadata = @{ ComputerName = $env:COMPUTERNAME; UserName = $env:USERNAME; ExportTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); Version = "1.0" }; TrackingData = $Data }
    $jsonData = $exportData | ConvertTo-Json -Depth 10
    Set-Content -Path $FilePath -Value $jsonData -Encoding UTF8
}

function Export-TrackingDataToCsv {
    param([string]$CsvPath, [hashtable]$TrackingData)
    # Ensure file exists in main folder, create if missing
    $folder = Split-Path $CsvPath -Parent
    if (-not (Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
    }
    if (-not (Test-Path $CsvPath)) {
        New-Item -ItemType File -Path $CsvPath | Out-Null
    }
    $csvOutput = $TrackingData.GetEnumerator() | ForEach-Object {
        $fileName = if ($_.Name) { Split-Path $_.Name -Leaf } else { "Unknown" }
        $fullPath = $_.Name
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
    $csvOutput | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
}
