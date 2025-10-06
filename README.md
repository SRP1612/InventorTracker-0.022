# Multi-Application Activity Tracker

A configurable, lightweight activity tracker that monitors user activity across multiple applications including Autodesk Inventor, Adobe Acrobat, Microsoft Excel, and more. The system runs in the background and can track active files when supported by the application.

## Change Log

- **10/6/25** - Major update: Added configurable multi-app tracking with external pattern files
- **9/25/25** - Adjusted sleeping interval from fixed amount to check every second for Ctrl+C input

## Features

- **Multi-Application Support**: Track activity across multiple configured applications
- **Configurable Pattern Detection**: External text files for easy customization of dialog/window patterns
- **Active File Tracking**: Automatically detects active files in supported applications (Inventor, Excel, Acrobat)
- **Headless Operation**: Runs silently in the background without a GUI interface
- **Smart Activity Detection**: Monitors mouse clicks, key presses, and continuous activity
- **Flexible Configuration**: JSON-based app configuration with no code changes required
- **Backward Compatible**: Existing Inventor-specific functions still work
- **Modular Architecture**: Clean separation for easy maintenance and extension

## Project Structure

```
InventorTracker/
├── config.json                    # Main configuration settings
├── run-tracker.ps1               # Main launcher script
├── activity_data-[COMPUTER]-[USER].json    # Generated tracking data
├── activity_export-[COMPUTER]-[USER].csv   # Generated activity report
└── src/
    ├── ActivityDetector.ps1       # Core detection logic and multi-app support
    ├── DataManager.ps1           # Data loading, saving, and CSV export
    ├── tracked_apps.json         # Application tracking configuration
    ├── inventor_titles.txt       # Inventor dialog/window patterns
    ├── inventor_classes.txt      # Inventor window class patterns
    ├── adobe_titles.txt          # Adobe Acrobat dialog/window patterns
    ├── adobe_classes.txt         # Adobe window class patterns
    └── monitored_keys.txt        # Configurable key codes to monitor
```

## Quick Start

1. **Run the tracker**:
   ```powershell
   .\run-tracker.ps1
   ```

2. **Use any configured application** - the tracker monitors all configured apps

3. **Stop the tracker** with `Ctrl+C` to save data and export CSV

## Multi-App Configuration

### Application Configuration (`src/tracked_apps.json`)

Define which applications to track and their settings:

```json
{
  "applications": [
    {
      "name": "Inventor",
      "processName": "Inventor",
      "mainTitleSubstring": "Autodesk Inventor",
      "titlePatternsFile": "inventor_titles.txt",
      "classPatternsFile": "inventor_classes.txt",
      "trackFiles": true,
      "comObject": "Inventor.Application",
      "fileMethod": "ActiveDocument.DisplayName"
    },
    {
      "name": "Acrobat",
      "processName": "Acrobat",
      "mainTitleSubstring": "Adobe Acrobat",
      "titlePatternsFile": "adobe_titles.txt",
      "classPatternsFile": "adobe_classes.txt",
      "trackFiles": true,
      "comObject": "AcroExch.App",
      "fileMethod": "GetActiveDoc().GetFileName()"
    },
    {
      "name": "Chrome",
      "processName": "chrome",
      "mainTitleSubstring": "Google Chrome",
      "titlePatternsFile": "",
      "classPatternsFile": "",
      "trackFiles": false,
      "comObject": "",
      "fileMethod": ""
    }
  ]
}
```

### Pattern Files

**Title Patterns** (`inventor_titles.txt`, `adobe_titles.txt`):
```
# One pattern per line - detects dialog/tool windows
extrude
revolve
sketch
annotation
# Comments start with #
```

**Class Patterns** (`inventor_classes.txt`, `adobe_classes.txt`):
```
# Window class name patterns
afx:400000:
autodesk
inventor
```

**Monitored Keys** (`monitored_keys.txt`):
```
# Virtual key codes to monitor (one per line)
65  # A
66  # B
# ... more key codes
```

## Usage Examples

### Multi-App Tracking
```powershell
# Load the module
. .\src\ActivityDetector.ps1

# Check all configured apps at once
$activeApps = Get-ActiveTrackedApps
foreach ($app in $activeApps) {
    $fileInfo = if ($app.ActiveFile) { " - File: $($app.ActiveFile)" } else { "" }
    Write-Host "$($app.Name) is active$fileInfo"
}

# Output example:
# Inventor is active - File: Part1.ipt
# Chrome is active
```

### Legacy Functions (Still Work)
```powershell
# Test specific application (backward compatible)
Test-InventorActive

# Get current input activity
$activity = Get-ActivityInput
Write-Host "Mouse clicks: $($activity.MouseClicks)"
Write-Host "Key presses: $($activity.KeyPresses)"
```

### Generic App Testing
```powershell
# Test any application with custom patterns
$patterns = Load-PatternsFile ".\adobe_titles.txt"
$classes = Load-PatternsFile ".\adobe_classes.txt"
Test-AppActive -ProcessName "Acrobat" -MainTitleSubstring "Adobe Acrobat" -TitlePatterns $patterns -ClassPatterns $classes
```

## Adding New Applications

To track a new application, simply edit `src/tracked_apps.json`:

1. **Add application entry** with process name and window title
2. **Create pattern files** (optional) for dialog detection
3. **Configure file tracking** if the app supports COM automation
4. **No code changes required** - reload the module

Example for adding Excel:
```json
{
  "name": "Excel",
  "processName": "EXCEL",
  "mainTitleSubstring": "Microsoft Excel",
  "titlePatternsFile": "",
  "classPatternsFile": "",
  "trackFiles": true,
  "comObject": "Excel.Application",
  "fileMethod": "ActiveWorkbook.Name"
}
```

## System Configuration

Edit `config.json` for general tracker behavior:

```json
{
    "LoopIntervalSeconds": 2,
    "SaveIntervalSeconds": 60,
    "ExcludedPaths": [
        "Content Center",
        "Design Accelerator",
        "\\Library\\",
        "\\Templates\\"
    ],
    "ActivityWeights": {
        "MouseClick": 0.5,
        "KeyPress": 0.25,
        "Continuous": 0.25
    }
}
```

## API Reference

### Core Functions

- **`Get-ActiveTrackedApps`**: Returns all currently active configured applications
- **`Test-AppActive`**: Generic function to test any application
- **`Test-InventorActive`**: Legacy Inventor-specific detection (backward compatible)
- **`Get-ActivityInput`**: Returns current mouse/keyboard activity
- **`Load-PatternsFile`**: Loads patterns from text file
- **`Load-AppConfigurations`**: Loads application configurations from JSON

### Configuration Functions

- **`Get-ActiveFile`**: Retrieves active file from supported applications via COM
- **`Load-MonitoredKeys`**: Loads key codes from configuration file

## File Tracking Support

Applications with file tracking return the active document name:

- **Inventor**: Returns `.ipt`, `.iam`, `.idw` filenames via COM
- **Excel**: Returns active workbook name via COM  
- **Acrobat**: Returns active PDF filename via COM
- **Chrome/Others**: App name only (no file tracking)

## Requirements

- Windows PowerShell 5.1 or PowerShell Core 6+
- Target applications installed (Inventor, Acrobat, etc.) for file tracking
- Windows operating system (uses Windows API for activity detection)

## Troubleshooting

### Common Issues

1. **"Cannot create COM object"**: Ensure target application is installed and supports COM
2. **Pattern files not loading**: Check file paths and ensure files exist in src/ directory
3. **App not detected**: Verify process name and window title in `tracked_apps.json`
4. **File tracking not working**: Ensure application is running and has an active document

### Testing Components

```powershell
# Test pattern loading
$patterns = Load-PatternsFile ".\inventor_titles.txt"
Write-Host "Loaded $($patterns.Count) patterns"

# Test app configuration loading
$apps = Load-AppConfigurations ".\tracked_apps.json"
$apps | Select-Object name, processName, trackFiles

# Test specific app detection
Test-AppActive -ProcessName "Code" -MainTitleSubstring "Visual Studio Code" -TitlePatterns @() -ClassPatterns @()
```

### Adding Debug Output

For troubleshooting, add verbose output:
```powershell
$activeApps = Get-ActiveTrackedApps
$activeApps | Format-Table -AutoSize
```

## Testing

### Validate Multi-App Detection

Use the `test-running-apps.ps1` script to validate activity detection for all configured applications:

```powershell
.\test-running-apps.ps1
```

This script will:
- Detect active applications from `tracked_apps.json`
- Monitor mouse clicks, key presses, and continuous activity
- Display results in real-time

### Validate Individual Activity

Use the `test-activity.ps1` script to validate input detection:

```powershell
.\test-activity.ps1
```

This script will:
- Monitor mouse clicks and key presses
- Display activity counts in real-time

## Updating Configuration

### JSON Configuration (`src/tracked_apps.json`)

Each application is defined with the following fields:

- `name`: Display name of the application
- `processName`: Name of the process to track
- `mainTitleSubstring`: Substring to identify the main window title
- `titlePatternsFile`: File containing dialog/window title patterns
- `classPatternsFile`: File containing window class patterns
- `trackFiles`: Whether to track active files (true/false)
- `comObject`: COM object for file tracking (optional)
- `fileMethod`: Method to retrieve the active file (optional)

### External Pattern Files

Update the `.txt` files in the `src` folder to customize dialog and class patterns:

- `inventor_titles.txt`: Patterns for Autodesk Inventor
- `adobe_titles.txt`: Patterns for Adobe Acrobat
- `monitored_keys.txt`: Key codes to monitor

Each pattern should be on a new line. Empty lines and comments (starting with `#`) are ignored.
