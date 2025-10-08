# run-tracker.ps1
# Main launcher script for the headless Inventor Activity Tracker
# This script starts the tracker and ensures proper cleanup on exit

# Set the working directory to the script's location
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptRoot

# Display banner
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  Inventor Activity Tracker v.021" -ForegroundColor White
Write-Host "     Headless Edition" -ForegroundColor Gray
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Load the simplified configuration
try {
    $configPath = "$ScriptRoot\config.json"
    if (-not (Test-Path $configPath)) {
        Write-Host "Error: Configuration file not found at $configPath" -ForegroundColor Red
        Write-Host "Please ensure config.json exists in the same directory as this script." -ForegroundColor Yellow
        exit 1
    }
    
    $config = Get-Content $configPath | ConvertFrom-Json
    Write-Host "Configuration loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "Error loading configuration: $_" -ForegroundColor Red
    exit 1
}

# Validate configuration
$requiredProperties = @('DataSourceFile', 'CsvExportFile', 'LoopIntervalSeconds', 'SaveIntervalSeconds', 'ExcludedPaths', 'ActivityWeights')
$missingProperties = @()

foreach ($prop in $requiredProperties) {
    if (-not $config.PSObject.Properties.Name.Contains($prop)) {
        $missingProperties += $prop
    }
}

if ($missingProperties.Count -gt 0) {
    Write-Host "Error: Missing required configuration properties:" -ForegroundColor Red
    $missingProperties | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

# Set up Ctrl+C handler for graceful shutdown
$global:shutdownRequested = $false

# Handle Ctrl+C manually
try {
    [Console]::CancelKeyPress += {
        param($s, $e)
        $e.Cancel = $true  # Don't terminate immediately
        $global:shutdownRequested = $true
        Write-Host ""
        Write-Host "Shutdown requested... Please wait for data to be saved." -ForegroundColor Yellow
    }
}
catch {
    # Fallback if Console CancelKeyPress isn't available
    Write-Verbose "Could not register Ctrl+C handler: $_"
}

# Use a try/finally block to guarantee cleanup on exit
try {
    Write-Host "Starting Inventor Activity Tracker..." -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop the tracker and export the final CSV." -ForegroundColor Yellow
    Write-Host ""
    
    # Import required modules
    . "$ScriptRoot\src\ActivityDetector.ps1"
    . "$ScriptRoot\src\DataManager.ps1"
    
    # Helper function to generate unique filenames
    function Get-UniqueFileName {
        param(
            [Parameter(Mandatory)]
            [string]$BaseFilePath
        )
        
        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($BaseFilePath)
        $extension = [System.IO.Path]::GetExtension($BaseFilePath)
        # Determine directory to place the unique file. If BaseFilePath includes a directory, use it.
        $dir = [System.IO.Path]::GetDirectoryName($BaseFilePath)
        if ([string]::IsNullOrWhiteSpace($dir)) {
            # Use the script root as default
            $dir = $ScriptRoot
        }

        $uniqueName = "$baseName-$computerName-$userName$extension"
        return [System.IO.Path]::Combine($dir, $uniqueName)
    }
    
    # Generate unique filenames for this session
    $uniqueJsonPath = Get-UniqueFileName -BaseFilePath $config.DataSourceFile
    $uniqueCsvPath = Get-UniqueFileName -BaseFilePath $config.CsvExportFile
    
    # Initialize tracking variables
    $trackingData = Import-TrackingData -FilePath $uniqueJsonPath
    $lastSaveTime = [datetime]::Now
    $startTime = [datetime]::Now

    Write-Host "=== Inventor Activity Tracker - Headless Mode ===" -ForegroundColor Green
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Data file: $uniqueJsonPath" -ForegroundColor Gray
    Write-Host "  CSV export: $uniqueCsvPath" -ForegroundColor Gray
    Write-Host "  Loop interval: $($config.LoopIntervalSeconds) seconds" -ForegroundColor Gray
    Write-Host "  Save interval: $($config.SaveIntervalSeconds) seconds" -ForegroundColor Gray
    Write-Host "  Activity weights: Mouse=$($config.ActivityWeights.MouseClick), Key=$($config.ActivityWeights.KeyPress), Continuous=$($config.ActivityWeights.Continuous)" -ForegroundColor Gray
    Write-Host ""

    # Display initial summary
    $summary = Get-TrackingDataSummary -TrackingData $trackingData
    Write-Host "Initial data summary:" -ForegroundColor Yellow
    Write-Host "  Files tracked: $($summary.FileCount)" -ForegroundColor Gray
    Write-Host "  Days of data: $($summary.TotalDays)" -ForegroundColor Gray
    Write-Host "  Total time tracked: $($summary.TotalActiveHours) hours" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Tracker is running... Press Ctrl+C to stop and export CSV" -ForegroundColor Green
    Write-Host ""

    function Get-ActiveInventorFile {
        param([string[]]$ExcludedPaths = @())
        
        try {
            # Try to get the Inventor application COM object
            $inventorApp = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Inventor.Application")
            $activeDoc = $inventorApp.ActiveDocument
            
            if ($activeDoc) {
                $filePath = $activeDoc.FullFileName
                
                # Filter out excluded paths
                foreach ($excluded in $ExcludedPaths) {
                    if ($filePath -like "*$excluded*") {
                        Write-Verbose "Excluded file: $filePath (matches: $excluded)"
                        return $null
                    }
                }
                
                Write-Verbose "Active Inventor file: $filePath"
                return $filePath
            }
        }
        catch {
            # Inventor is not running or no document is active
            Write-Verbose "No active Inventor document: $_"
        }
        
        return $null
    }

    # Main tracking loop
    $loopCount = 0
    $lastStatusTime = [datetime]::Now

    Write-Host "Starting main tracking loop..." -ForegroundColor Green

    while (-not $global:shutdownRequested) {
        $loopCount++
        
        # Add periodic check to see if shutdown is requested
        if ($loopCount % 10 -eq 0) {
            Write-Verbose "Loop $loopCount - Shutdown requested: $global:shutdownRequested"
        }
        
        try {
            # Check if Inventor is the active window
            if (Test-InventorActive) {
                # Get the currently active Inventor file
                $activeFile = Get-ActiveInventorFile -ExcludedPaths $config.ExcludedPaths
                
                if ($activeFile) {
                    # Get user input activity
                    $activity = Get-ActivityInput
                    $hasActivity = ($activity.MouseClicks -gt 0) -or ($activity.KeyPresses -gt 0) -or $activity.IsContinuous
                    
                    if ($hasActivity) {
                        $today = (Get-Date).ToString("yyyy-MM-dd")
                        
                        # Initialize tracking for new files
                        if (-not $trackingData.ContainsKey($activeFile)) {
                            $trackingData[$activeFile] = @{
                                DailyActivity = @{}
                            }
                        }
                        
                        # Initialize tracking for today if not exists
                        if (-not $trackingData[$activeFile].DailyActivity.ContainsKey($today)) {
                            $trackingData[$activeFile].DailyActivity[$today] = @{
                                TotalActiveSeconds = 0
                                LastSeenTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                            }
                            Write-Host "Started tracking new file for $today`: $(Split-Path $activeFile -Leaf)" -ForegroundColor Green
                        }
                        
                        # Calculate time to add based on activity weights
                        $timeToAdd = 0
                        $timeToAdd += $activity.MouseClicks * $config.ActivityWeights.MouseClick
                        $timeToAdd += $activity.KeyPresses * $config.ActivityWeights.KeyPress
                        if ($activity.IsContinuous) {
                            $timeToAdd += $config.ActivityWeights.Continuous
                        }
                        
                        # Update tracking data for today
                        $trackingData[$activeFile].DailyActivity[$today].TotalActiveSeconds += $timeToAdd
                        $trackingData[$activeFile].DailyActivity[$today].LastSeenTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        
                        $fileName = Split-Path $activeFile -Leaf
                        $timestamp = Get-Date -Format "HH:mm:ss"
                        $todayTotal = $trackingData[$activeFile].DailyActivity[$today].TotalActiveSeconds
                        Write-Host "[$timestamp] Activity in $fileName`: +$([math]::Round($timeToAdd, 2))s (Today: $([math]::Round($todayTotal, 2))s)" -ForegroundColor Green
                        Write-Verbose "Activity detected in $fileName`: +$([math]::Round($timeToAdd, 2))s (Mouse: $($activity.MouseClicks), Keys: $($activity.KeyPresses), Continuous: $($activity.IsContinuous))"
                    }
                }
            }
            
            # Check if it's time to save data
            if (([datetime]::Now - $lastSaveTime).TotalSeconds -ge $config.SaveIntervalSeconds) {
                Write-Verbose "Auto-saving tracking data..."
                Export-TrackingData -FilePath $uniqueJsonPath -Data $trackingData
                $lastSaveTime = [datetime]::Now
                
                $summary = Get-TrackingDataSummary -TrackingData $trackingData
                Write-Host "Auto-saved: $($summary.FileCount) files, $($summary.TotalActiveHours) hours total" -ForegroundColor Yellow
            }
            
            # Sleep for the specified interval
            #Start-Sleep -Seconds $config.LoopIntervalSeconds
			
			# Sleep for the interval, but check for shutdown every second
			for ($i = 0; $i -lt $config.LoopIntervalSeconds; $i++) {
			if ($global:shutdownRequested) { 
			# Exit the sleep loop immediately if shutdown is requested
			break 
			}
			Start-Sleep -Seconds 1
			}
			
        }
        catch {
            Write-Warning "Error in tracking loop: $_"
            Write-Host "Loop will continue..." -ForegroundColor Yellow
            Start-Sleep -Seconds $config.LoopIntervalSeconds
        }
    }

    Write-Host "Main tracking loop ended - shutdown requested: $global:shutdownRequested" -ForegroundColor Yellow

    # Save data before exiting
    Write-Host "Saving tracking data before shutdown..." -ForegroundColor Yellow
    Export-TrackingData -FilePath $uniqueJsonPath -Data $trackingData
}
catch {
    if ($_.Exception.Message -like "*break*" -or $_.Exception.Message -like "*stopped*") {
        Write-Host "Tracker stopped by user" -ForegroundColor Yellow
    }
    else {
        Write-Host "Tracker encountered an error: $_" -ForegroundColor Red
    }
}
finally {
    # This code runs when you press Ctrl+C or the script ends for any reason
    Write-Host ""
    Write-Host "Shutting down tracker..." -ForegroundColor Yellow
    
    try {
        # Prefer using the in-memory tracking data collected during this session.
        Write-Host "Preparing final tracking data for export..." -ForegroundColor Cyan
        $finalData = $trackingData

        # If in-memory data is empty (e.g. never collected or lost), try loading from disk as a fallback
        if (-not $finalData -or $finalData.Count -eq 0) {
            Write-Host "No in-memory tracking data found, attempting to load from disk..." -ForegroundColor Yellow
            if (Test-Path $uniqueJsonPath) {
                $finalData = Import-TrackingData -FilePath $uniqueJsonPath
            } else {
                $finalData = @{}
            }
        }

        if ($finalData -and $finalData.Count -gt 0) {
            # Export final data to JSON (backup)
            Write-Host "Saving final tracking data..." -ForegroundColor Cyan
            Export-TrackingData -FilePath $uniqueJsonPath -Data $finalData

            # Export to CSV
            Write-Host "Exporting final CSV report..." -ForegroundColor Cyan
            Export-TrackingDataToCsv -CsvPath $uniqueCsvPath -TrackingData $finalData

            # Display final summary
            $summary = Get-TrackingDataSummary -TrackingData $finalData
            Write-Host ""
            Write-Host "=== Final Summary ===" -ForegroundColor Green
            Write-Host "Files tracked: $($summary.FileCount)" -ForegroundColor Cyan
            Write-Host "Days of data: $($summary.TotalDays)" -ForegroundColor Cyan
            Write-Host "Total active time: $($summary.TotalActiveHours) hours" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Data saved to: $uniqueJsonPath" -ForegroundColor Green
            Write-Host "CSV exported to: $uniqueCsvPath" -ForegroundColor Green
        }
        else {
            Write-Host "No tracking data to export" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Error during final data export: $_" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Inventor Activity Tracker has stopped." -ForegroundColor Green
    Write-Host "Thank you for using the tracker!" -ForegroundColor Cyan
}
