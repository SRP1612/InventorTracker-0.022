# Inventor Activity Tracker - Headless Edition


Change log
9/25/25 - Adjusted sleeping interval from a fixed amount to check every second for ctrl+c input to allow fast exiting without having to wait for another save loop.






A simplified, lightweight version of the Inventor Activity Tracker that runs in the background without a GUI, focusing solely on tracking user activity in Autodesk Inventor and exporting the data to CSV.

## Features

- **Headless Operation**: Runs silently in the background without a GUI interface
- **Automatic Activity Detection**: Monitors mouse clicks, key presses, and continuous activity
- **Smart File Filtering**: Excludes system files, templates, and libraries from tracking
- **Periodic Auto-Save**: Automatically saves tracking data at configurable intervals
- **Unique Filenames**: Both JSON and CSV files include computer name and username for multi-user environments
- **Enhanced Metadata**: JSON files include creation timestamp, computer, and user information
- **CSV Export**: Exports comprehensive activity reports on shutdown with unique filenames
- **Graceful Shutdown**: Ctrl+C handling ensures data is always saved before exit
- **Modular Architecture**: Clean separation of concerns for easy maintenance

## Project Structure

```
InventorTracker-Headless/
├── config.json              # Configuration settings
├── run-tracker.ps1          # Main launcher script
├── activity_data-[COMPUTER]-[USER].json       # Generated tracking data (JSON)
├── activity_export-[COMPUTER]-[USER].csv      # Generated activity report (CSV)
└── src/
    ├── Core.ps1             # Main tracking loop and logic
    ├── ActivityDetector.ps1 # Windows API integration for activity detection
    └── DataManager.ps1      # Data loading, saving, and CSV export functions
```

## Quick Start

1. **Run the tracker**:
   ```powershell
   .\run-tracker.ps1
   ```

2. **Use Inventor normally** - the tracker runs silently in the background

3. **Stop the tracker** with `Ctrl+C` to save data and export CSV

## Configuration

Edit `config.json` to customize the tracker behavior:

```json
{
    "DataSourceFile": "activity_data.json",
    "CsvExportFile": "activity_export.csv",
    "LoopIntervalSeconds": 2,
    "SaveIntervalSeconds": 60,
    "ExcludedPaths": [
        "Content Center",
        "Design Accelerator",
        "\\Library\\",
        "\\Templates\\",
        "Autodesk\\Inventor",
        "Program Files"
    ],
    "ActivityWeights": {
        "MouseClick": 0.5,
        "KeyPress": 0.25,
        "Continuous": 0.25
    }
}
```

### Configuration Options

- **DataSourceFile**: JSON file where tracking data is stored
- **CsvExportFile**: CSV file where final report is exported
- **LoopIntervalSeconds**: How often to check for activity (default: 2 seconds)
- **SaveIntervalSeconds**: How often to auto-save data (default: 60 seconds)
- **ExcludedPaths**: File paths to exclude from tracking
- **ActivityWeights**: Time in seconds to add for each type of activity

## Modules

### ActivityDetector.ps1
- Contains the `UltraSensitiveDetector` C# class
- Provides PowerShell wrapper functions:
  - `Test-InventorActive`: Checks if Inventor is the active window
  - `Get-ActivityInput`: Returns current mouse/keyboard activity

### DataManager.ps1
- Handles all data operations:
  - `Import-TrackingData`: Loads data from JSON file
  - `Export-TrackingData`: Saves data to JSON file (atomic operation)
  - `Export-TrackingDataToCsv`: Exports data to CSV format
  - `Get-TrackingDataSummary`: Provides summary statistics

### Core.ps1
- Contains the main tracking loop
- Integrates activity detection with data management
- Provides periodic status updates and auto-save functionality
- Includes the `Get-ActiveInventorFile` function for COM integration

## CSV Export Format

The exported CSV contains the following columns:

- **FileName**: Just the filename without path
- **FullPath**: Complete file path
- **TotalActiveSeconds**: Total time spent working on the file
- **TotalActiveMinutes**: Time in minutes (calculated)
- **TotalActiveHours**: Time in hours (calculated)
- **LastSeenTime**: When the file was last worked on

### File Naming Convention

Both JSON and CSV files are automatically saved with unique names to prevent conflicts in multi-user environments:

**JSON Format:** `activity_data-[COMPUTERNAME]-[USERNAME].json`
**CSV Format:** `activity_export-[COMPUTERNAME]-[USERNAME].csv`

Examples: 
- `activity_data-WORKSTATION01-john.doe.json`
- `activity_export-WORKSTATION01-john.doe.csv`

This ensures that:
- Multiple users can run the tracker without overwriting each other's files
- Easy identification of which user/computer generated each report
- Consistent naming across both data formats

### JSON Data Format

The `activity_data.json` file now includes metadata along with tracking data:

```json
{
    "Metadata": {
        "ComputerName": "SRP-LT-002",
        "UserName": "Andrew",
        "ExportTime": "2025-08-13 10:06:19",
        "Version": "1.0"
    },
    "TrackingData": {
        "C:\\Path\\To\\File.iam": {
            "TotalActiveSeconds": 150.25,
            "LastSeenTime": "2025-08-13 10:06:15"
        }
    }
}
```

**Metadata Fields:**
- **ComputerName**: Name of the computer that generated the data
- **UserName**: Windows username of the person running the tracker
- **ExportTime**: When the data was last saved
- **Version**: Format version for future compatibility

The tracker is backward compatible and can read legacy JSON files without metadata.

## Requirements

- Windows PowerShell 5.1 or PowerShell Core 6+
- Autodesk Inventor (any version that supports COM automation)
- Windows operating system (uses Windows API for activity detection)

## Troubleshooting

### Common Issues

1. **"Cannot create COM object"**: Ensure Inventor is installed and properly registered
2. **Access denied errors**: Run PowerShell as Administrator if needed
3. **Tracking not working**: Verify Inventor is the active window and a document is open
4. **High CPU usage**: Increase `LoopIntervalSeconds` in config.json

### Verbose Output

Run with verbose output for debugging:
```powershell
.\run-tracker.ps1 -Verbose
```

### Manual Testing

Test individual components:
```powershell
# Test activity detection
. .\src\ActivityDetector.ps1
Test-InventorActive
Get-ActivityInput

# Test data operations  
. .\src\DataManager.ps1
$data = Import-TrackingData -FilePath "activity_data.json"
```
