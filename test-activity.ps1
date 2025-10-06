# Test script to check multi-app activity tracking
# Gives you 10 seconds to switch to a tracked app and generate activity

# Load the modules
. ".\src\ActivityDetector.ps1"
. ".\src\DataManager.ps1"

Write-Host "=== Multi-App Activity Test ===" -ForegroundColor Cyan
Write-Host ""

# Show which apps are configured
Write-Host "Configured applications:" -ForegroundColor Yellow
$config = Load-AppConfigurations ".\src\tracked_apps.json"
$config | ForEach-Object { 
    $fileTracking = if ($_.trackFiles) { " (tracks files)" } else { " (app only)" }
    Write-Host "  - $($_.name)$fileTracking" -ForegroundColor Gray
}
Write-Host ""

Write-Host "You have 10 seconds to:" -ForegroundColor Green
Write-Host "  1. Switch to any tracked application (Inventor, Acrobat, Excel, Chrome, VSCode)" -ForegroundColor White
Write-Host "  2. Click around, type, or move the mouse" -ForegroundColor White
Write-Host "  3. The script will detect and report activity" -ForegroundColor White
Write-Host ""

Write-Host "Starting in 3 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 1
Write-Host "2..." -ForegroundColor Yellow
Start-Sleep -Seconds 1
Write-Host "1..." -ForegroundColor Yellow
Start-Sleep -Seconds 1
Write-Host ""
Write-Host "GO! Switch to a tracked app and generate activity!" -ForegroundColor Green

# Monitor for 10 seconds
$startTime = Get-Date
$endTime = $startTime.AddSeconds(10)
$activityDetected = $false

while ((Get-Date) -lt $endTime) {
    $remainingSeconds = [math]::Ceiling(($endTime - (Get-Date)).TotalSeconds)
    
    # Check for active apps
    $activeApps = Get-ActiveTrackedApps
    
    if ($activeApps.Count -gt 0) {
        $activity = Get-ActivityInput
        $hasActivity = ($activity.MouseClicks -gt 0) -or ($activity.KeyPresses -gt 0) -or $activity.IsContinuous
        
        if ($hasActivity) {
            $activityDetected = $true
            foreach ($app in $activeApps) {
                $fileInfo = if ($app.ActiveFile) { " - File: $($app.ActiveFile)" } else { "" }
                Write-Host "[$remainingSeconds`s] ACTIVITY DETECTED in $($app.Name)$fileInfo" -ForegroundColor Green
                Write-Host "    Mouse clicks: $($activity.MouseClicks), Key presses: $($activity.KeyPresses), Continuous: $($activity.IsContinuous)" -ForegroundColor Cyan
            }
        } else {
            foreach ($app in $activeApps) {
                $fileInfo = if ($app.ActiveFile) { " - File: $($app.ActiveFile)" } else { "" }
                Write-Host "[$remainingSeconds`s] $($app.Name) is active$fileInfo (no activity detected)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "[$remainingSeconds`s] No tracked applications currently active" -ForegroundColor Red
    }
    
    Start-Sleep -Seconds 1
}

Write-Host ""
if ($activityDetected) {
    Write-Host "SUCCESS: Activity was detected! The tracking system is working." -ForegroundColor Green
} else {
    Write-Host "No activity detected. Try:" -ForegroundColor Yellow
    Write-Host "  - Make sure you switched to Inventor, Acrobat, Excel, Chrome, or VSCode" -ForegroundColor Gray
    Write-Host "  - Click the mouse or press keys while in the application" -ForegroundColor Gray
    Write-Host "  - Check that the application is actually running" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Test complete!" -ForegroundColor Cyan