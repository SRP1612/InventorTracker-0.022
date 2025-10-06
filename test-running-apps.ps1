# Test script to validate activity detection with running applications
. "$PSScriptRoot\src\ActivityDetector.ps1"

Write-Host "=== TESTING ACTIVITY DETECTION WITH RUNNING APPS ===" -ForegroundColor Cyan
Write-Host "You have 20 seconds to click/type in any of your open applications:" -ForegroundColor Yellow
Write-Host "- Inventor, Acrobat, Chrome, Excel, Outlook" -ForegroundColor Yellow
Write-Host "Starting in 3 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

$startTime = Get-Date
$endTime = $startTime.AddSeconds(20)
$detectedApps = @{}

# Get the list of tracked apps from config
$configPath = "$PSScriptRoot\src\tracked_apps.json"
$appConfigs = Load-AppConfigurations -ConfigPath $configPath
$testApps = @()
foreach ($appConfig in $appConfigs) {
    $testApps += @{Name = $appConfig.name; Config = $appConfig}
}

Write-Host "Starting detection..." -ForegroundColor Green

while ((Get-Date) -lt $endTime) {
    $remainingSeconds = [math]::Ceiling(($endTime - (Get-Date)).TotalSeconds)
    
    foreach ($testApp in $testApps) {
        # Load patterns for this app
        $titlePatterns = @()
        $classPatterns = @()
        if ($testApp.Config.titlePatternsFile) {
            $titlePatternsPath = "$PSScriptRoot\src\$($testApp.Config.titlePatternsFile)"
            if (Test-Path $titlePatternsPath) {
                $titlePatterns = Get-Content $titlePatternsPath | Where-Object { $_.Trim() -ne "" }
            }
        }
        if ($testApp.Config.classPatternsFile) {
            $classPatternsPath = "$PSScriptRoot\src\$($testApp.Config.classPatternsFile)"
            if (Test-Path $classPatternsPath) {
                $classPatterns = Get-Content $classPatternsPath | Where-Object { $_.Trim() -ne "" }
            }
        }
        
        $isActive = Test-AppActive -ProcessName $testApp.Config.processName -MainTitleSubstring $testApp.Config.mainTitleSubstring -TitlePatterns $titlePatterns -ClassPatterns $classPatterns
        
        if ($isActive) {
            # Get activity
            $activity = Get-ActivityInput
            $hasActivity = ($activity.MouseClicks -gt 0) -or ($activity.KeyPresses -gt 0) -or $activity.IsContinuous
            
            if ($hasActivity) {
                $detectedApps[$testApp.Name]++
                Write-Host "[$remainingSeconds s] ACTIVITY in $($testApp.Name)! (Mouse: $($activity.MouseClicks), Keys: $($activity.KeyPresses), Continuous: $($activity.IsContinuous))" -ForegroundColor Green
            } else {
                Write-Host "[$remainingSeconds s] $($testApp.Name) is active (no activity yet)" -ForegroundColor Yellow
            }
            break  # Only report one app at a time to avoid spam
        }
    }
    
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "=== RESULTS ===" -ForegroundColor Cyan
if ($detectedApps.Count -gt 0) {
    Write-Host "SUCCESS! Detected activity in:" -ForegroundColor Green
    foreach ($app in $detectedApps.Keys) {
        $count = $detectedApps[$app]
        Write-Host "  - $app ($count activity events)" -ForegroundColor Green
    }
} else {
    Write-Host "No activity detected. Possible issues:" -ForegroundColor Red
    Write-Host "  - Applications might not be the active foreground window" -ForegroundColor Yellow
    Write-Host "  - Process names might be different than expected" -ForegroundColor Yellow
    Write-Host "  - Need to actually click/type in the application" -ForegroundColor Yellow
}
Write-Host ""