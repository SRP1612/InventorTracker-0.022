# UserActivityTracker.ps1
# Enhanced activity tracker that records detailed activity data and exports to CSV

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class ActivityDetector {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    public static int GetNewMouseClicks() {
        int clickCount = 0;
        if ((GetAsyncKeyState(0x01) & 0x0001) != 0) clickCount++;
        if ((GetAsyncKeyState(0x02) & 0x0001) != 0) clickCount++;
        if ((GetAsyncKeyState(0x04) & 0x0001) != 0) clickCount++;
        return clickCount;
    }

    public static int GetNewKeyPresses() {
        int[] keysToCheck = {
            65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
            81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 48, 49, 50, 51, 52, 53,
            54, 55, 56, 57, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121,
            122, 123, 13, 27, 32, 8, 46, 9, 37, 38, 39, 40, 33, 34, 35, 36
        };

        foreach (int key in keysToCheck) {
            if ((GetAsyncKeyState(key) & 0x0001) != 0) {
                return 1;
            }
        }
        return 0;
    }

    public static bool HasContinuousActivity() {
        int[] keysToCheck = {
            65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
            81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 48, 49, 50, 51, 52, 53,
            54, 55, 56, 57, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121,
            122, 123, 13, 27, 32, 8, 46, 9, 37, 38, 39, 40, 33, 34, 35, 36,
            16, 17, 18
        };

        foreach (int key in keysToCheck) {
            if ((GetAsyncKeyState(key) & 0x8000) != 0) {
                return true;
            }
        }

        if ((GetAsyncKeyState(0x01) & 0x8000) != 0 ||
            (GetAsyncKeyState(0x04) & 0x8000) != 0) {
            return true;
        }

        return false;
    }
}
'@

function Get-ActiveApplicationAndFile {
    try {
        $hWnd = [ActivityDetector]::GetForegroundWindow()
        if ($hWnd -eq [IntPtr]::Zero) { return $null }

        $titleBuilder = New-Object System.Text.StringBuilder 256
        [ActivityDetector]::GetWindowText($hWnd, $titleBuilder, 256)
        $windowTitle = $titleBuilder.ToString()

        $processId = 0
        [ActivityDetector]::GetWindowThreadProcessId($hWnd, [ref]$processId)
        $process = [System.Diagnostics.Process]::GetProcessById($processId)
        $processName = $process.ProcessName

        $filename = $null
        if ($windowTitle) {
            $parts = $windowTitle -split " - "
            if ($parts.Length -gt 1) {
                $potentialFile1 = $parts[0].Trim()
                $potentialFile2 = $parts[1].Trim()

                if ($potentialFile1 -match '\.\w+$') {
                    $filename = $potentialFile1
                }
                elseif ($potentialFile2 -match '\.\w+$') {
                    $filename = $potentialFile2
                }
            }
            elseif ($windowTitle -match '\.\w+$') {
                $filename = $windowTitle
            }
        }

        if ($processName -eq "Inventor") {
            try {
                $inventorApp = [Runtime.InteropServices.Marshal]::GetActiveObject("Inventor.Application")
                if ($inventorApp -and $inventorApp.ActiveDocument) {
                    $activeDoc = $inventorApp.ActiveDocument
                    $filename = $activeDoc.FullFileName
                }
            }
            catch { }
        }
        elseif ($processName -ieq "EXCEL") {
            try {
                $excelApp = [Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
                if ($excelApp -and $excelApp.ActiveWorkbook) {
                    $filename = $excelApp.ActiveWorkbook.FullName
                }
            }
            catch { }
        }
        elseif ($processName -ieq "WINWORD") {
            try {
                $wordApp = [Runtime.InteropServices.Marshal]::GetActiveObject("Word.Application")
                if ($wordApp -and $wordApp.ActiveDocument) {
                    $filename = $wordApp.ActiveDocument.FullName
                }
            }
            catch { }
        }
        elseif ($processName -ieq "POWERPNT") {
            try {
                $pptApp = [Runtime.InteropServices.Marshal]::GetActiveObject("PowerPoint.Application")
                if ($pptApp -and $pptApp.ActivePresentation) {
                    $filename = $pptApp.ActivePresentation.FullName
                }
            }
            catch { }
        }
        # For other applications, try to extract more path info from window title
        elseif ($windowTitle -and ($filename -notmatch '^[A-Z]:\\')) {
            # Look for patterns that might contain path info in the title
            # Some applications show full paths in their titles
            if ($windowTitle -match '([A-Z]:\\[^"<>|*?]+\.\w+)') {
                $filename = $matches[1]
            }
            # Some show "path - application" format
            elseif ($windowTitle -match '^([A-Z]:\\[^"<>|*?]+\.\w+)\s*-') {
                $filename = $matches[1]
            }
            # Some show "filename (path)" format
            elseif ($windowTitle -match '\(([A-Z]:\\[^"<>|*?)]+)\)' -and $filename) {
                $pathPart = $matches[1]
                if (Test-Path $pathPart -IsValid) {
                    $filename = Join-Path $pathPart $filename
                }
            }
        }

        return @{
            Application = $processName
            Filename = $filename
        }
    }
    catch {
        return $null
    }
}

function Get-UserActivity {
    return @{
        MouseClicks = [ActivityDetector]::GetNewMouseClicks()
        KeyPresses = [ActivityDetector]::GetNewKeyPresses()
        IsContinuous = [ActivityDetector]::HasContinuousActivity()
    }
}

function Update-TrackingData {
    param([string]$FilePath, [string]$Application, [hashtable]$Activity)

    if (-not $FilePath -or $FilePath -eq "" -or $FilePath -eq "None detected") { return }

    $today = (Get-Date).ToString("yyyy-MM-dd")

    if (-not $TrackingData.ContainsKey($FilePath)) {
        $TrackingData[$FilePath] = @{ DailyActivity = @{} }
    }

    if (-not $TrackingData[$FilePath].DailyActivity.ContainsKey($today)) {
        $TrackingData[$FilePath].DailyActivity[$today] = @{
            TotalActiveSeconds = 0
            MouseClicks = 0
            KeyPresses = 0
            ContinuousSeconds = 0
            LastSeenTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            Application = $Application
        }
    }

    $todaysData = $TrackingData[$FilePath].DailyActivity[$today]
    $todaysData.MouseClicks += $Activity.MouseClicks
    $todaysData.KeyPresses += $Activity.KeyPresses
    $todaysData.ContinuousSeconds += $Activity.ContinuousSeconds
    $todaysData.LastSeenTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $todaysData.Application = $Application

    $activityScore = ($Activity.MouseClicks * 3) + ($Activity.KeyPresses * 3) + ($Activity.ContinuousSeconds * 1)
    if ($activityScore -gt 0) {
        $todaysData.TotalActiveSeconds += 1
    }
}

# Import the DataManager module
. "$PSScriptRoot\DataManager.ps1"

# Configuration
$DataFile = "$PSScriptRoot\activity_data-$env:COMPUTERNAME-$env:USERNAME.json"
$CsvFile = "$PSScriptRoot\activity_export-$env:COMPUTERNAME-$env:USERNAME.csv"
$SaveIntervalSeconds = 10

# Load existing tracking data
$TrackingData = Import-TrackingData -FilePath $DataFile

# Initialize variables
$startTime = Get-Date
$lastSaveTime = Get-Date
$sessionStartTime = Get-Date
$totalClicks = 0
$totalPresses = 0
$continuousSeconds = 0
$currentDayActivity = @{
    MouseClicks = 0
    KeyPresses = 0
    ContinuousSeconds = 0
    StartTime = $sessionStartTime
}

Write-Host "Enhanced User Activity Tracker started. Press Ctrl+C to stop." -ForegroundColor Green
Write-Host "Recording activity data per file per day with CSV export." -ForegroundColor Green
Write-Host "Data file: $DataFile" -ForegroundColor Cyan
Write-Host "CSV file: $CsvFile" -ForegroundColor Cyan
Write-Host "Auto-save interval: $SaveIntervalSeconds seconds" -ForegroundColor Cyan
Write-Host "Program will start recording activity in 5 seconds..."
Start-Sleep -Seconds 5
Write-Host ""
Clear-Host


try {
    while ($true) {
        try {
            $activity = Get-UserActivity
            $totalClicks += $activity.MouseClicks
            $totalPresses += $activity.KeyPresses
            if ($activity.IsContinuous) { $continuousSeconds++ }

            $currentDayActivity.MouseClicks += $activity.MouseClicks
            $currentDayActivity.KeyPresses += $activity.KeyPresses
            if ($activity.IsContinuous) { $currentDayActivity.ContinuousSeconds++ }

            $currentTime = Get-Date
            if (($currentTime - $startTime).TotalSeconds -ge 1) {
                $active = Get-ActiveApplicationAndFile

                if ($active -and $active.Filename) {
                    $fullPath = $active.Filename

                    if ($currentDayActivity.MouseClicks -gt 0 -or $currentDayActivity.KeyPresses -gt 0 -or $currentDayActivity.ContinuousSeconds -gt 0) {
                        Update-TrackingData -FilePath $fullPath -Application $active.Application -Activity $currentDayActivity
                    }
                }

                Clear-Host
                Write-Host "Enhanced User Activity Monitor - $(Get-Date)" -ForegroundColor Green
                Write-Host ""

                if ($active) {
                    Write-Host "Active Application: $($active.Application)" -ForegroundColor Yellow
                    if ($active.Filename) {
                        $displayName = Split-Path $active.Filename -Leaf
                        Write-Host "Active File: $displayName" -ForegroundColor Cyan
                    } else {
                        Write-Host "Active File: None detected" -ForegroundColor Gray
                    }
                }

                Write-Host ""
                Write-Host "Activity (last second):" -ForegroundColor White
                Write-Host "  - Mouse Clicks: $totalClicks" -ForegroundColor $(if ($totalClicks -gt 0) { "Green" } else { "Gray" })
                Write-Host "  - Key Presses: $totalPresses" -ForegroundColor $(if ($totalPresses -gt 0) { "Green" } else { "Gray" })
                Write-Host "  - Continuous Activity: $(if ($continuousSeconds -gt 0) { 'Active' } else { 'Inactive' })" -ForegroundColor $(if ($continuousSeconds -gt 0) { "Green" } else { "Gray" })
                Write-Host ""

                $sessionDuration = (Get-Date) - $sessionStartTime
                Write-Host "Session Stats:" -ForegroundColor White
                Write-Host "  - Duration: $([math]::Round($sessionDuration.TotalMinutes, 1)) minutes" -ForegroundColor Cyan
                Write-Host "  - Total Files Tracked: $($TrackingData.Count)" -ForegroundColor Cyan

                $today = (Get-Date).ToString("yyyy-MM-dd")
                $todayTotalSeconds = 0
                $todayFiles = 0
                foreach ($fileData in $TrackingData.Values) {
                    if ($fileData.DailyActivity.ContainsKey($today)) {
                        $todayTotalSeconds += $fileData.DailyActivity[$today].TotalActiveSeconds
                        $todayFiles++
                    }
                }
                Write-Host "  - Today's Active Time: $([math]::Round($todayTotalSeconds / 60, 1)) minutes across $todayFiles files" -ForegroundColor Green

                $totalClicks = 0
                $totalPresses = 0
                $continuousSeconds = 0
                $currentDayActivity = @{
                    MouseClicks = 0
                    KeyPresses = 0
                    ContinuousSeconds = 0
                    StartTime = $currentTime
                }
                $startTime = $currentTime
            }

            if (($currentTime - $lastSaveTime).TotalSeconds -ge $SaveIntervalSeconds) {
                if ($TrackingData.Count -gt 0) {
                    Write-Host ""
                    Write-Host "Auto-saving data..." -ForegroundColor Yellow -NoNewline
                    try {
                        Export-TrackingData -FilePath $DataFile -Data $TrackingData
                        Export-TrackingDataToCsv -CsvPath $CsvFile -TrackingData $TrackingData
                            Write-Host "Complete!" -ForegroundColor Green
                    }
                    catch {
                            Write-Host "Failed: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                $lastSaveTime = $currentTime
            }

            Start-Sleep -Milliseconds 50
        }
        catch {
            Write-Warning "Error in tracking loop: $_"
            Start-Sleep -Milliseconds 100
        }
    }
}
catch {
    Write-Warning "Critical error in activity tracker: $_"
}
finally {
    if ($TrackingData.Count -gt 0) {
        Write-Host ""
        Write-Host "Saving final data before exit..." -ForegroundColor Yellow
        try {
            Export-TrackingData -FilePath $DataFile -Data $TrackingData
            Export-TrackingDataToCsv -CsvPath $CsvFile -TrackingData $TrackingData
            Write-Host "Data saved successfully!" -ForegroundColor Green
        }
        catch {
            Write-Host "Error saving final data: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}