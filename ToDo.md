# ToDo

This document outlines the planned enhancements for the InventorTracker project. Each task includes a summary, prerequisites, estimated effort, and two detailed implementation options with code examples and considerations.

## 1. Implement idle time detection and exclusion

**Summary**: Detect when the user is away from the computer and exclude that time from activity calculations.

**Prerequisites**: Windows API knowledge, P/Invoke experience
**Estimated Effort**: Medium (2-3 days)
**Dependencies**: None (uses built-in Windows APIs)

**Option 1 - System Idle Time**:
Use Windows API calls to detect system idle time (no mouse/keyboard activity) and subtract idle periods from active time calculations.

**Implementation Steps**:

1. Add P/Invoke declarations for `GetLastInputInfo` and `LASTINPUTINFO` structure
2. Create a function to get idle time in seconds
3. Modify the tracking loop to check idle time before recording activity
4. Only count activity if idle time is below threshold (e.g., 5 minutes)

**Code Example**:
```powershell
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class IdleTime {
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
}
"@

function Get-IdleTime {
    $lastInputInfo = New-Object IdleTime+LASTINPUTINFO
    $lastInputInfo.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($lastInputInfo)
    [IdleTime]::GetLastInputInfo([ref]$lastInputInfo)
    $idleTime = [Environment]::TickCount - $lastInputInfo.dwTime
    return [math]::Floor($idleTime / 1000)  # Convert to seconds
}
```

**Pros**: Accurate, system-level detection
**Cons**: Requires admin privileges for some systems

**Option 2 - Active Window Monitoring**:
Monitor for changes in active windows and detect prolonged periods of inactivity by tracking when the same inactive window remains active for extended periods.

**Implementation Steps**:

1. Track the last active window handle and timestamp
2. In the tracking loop, check if the active window has changed
3. If the same window remains active for >5 minutes, consider it idle
4. Exclude idle periods from activity calculations

**Code Example**:
```powershell
$lastWindowHandle = $null
$lastWindowChange = Get-Date
$idleThreshold = 300  # 5 minutes

# In tracking loop:
$currentWindow = [WindowInfo]::GetForegroundWindow()
if ($currentWindow -ne $lastWindowHandle) {
    $lastWindowHandle = $currentWindow
    $lastWindowChange = Get-Date
} else {
    $idleTime = ((Get-Date) - $lastWindowChange).TotalSeconds
    if ($idleTime -gt $idleThreshold) {
        # Skip activity recording for this interval
        continue
    }
}
```

**Pros**: No additional permissions needed
**Cons**: Less accurate (user might be reading without switching windows)

## 2. Implement activity visualization charts

**Summary**: Add graphical representations of activity data to make it easier to understand usage patterns over time.

**Prerequisites**: PowerShell module installation, basic HTML/CSS knowledge
**Estimated Effort**: Medium (3-4 days)
**Dependencies**: PSWriteHTML or ImportExcel modules

**Option 1 - PowerShell Charts**:
Use PowerShell modules like PSWriteHTML or ImportExcel to generate HTML charts or embed charts in Excel workbooks. Keep everything within PowerShell ecosystem.

**Implementation Steps**:

1. Install required modules: `Install-Module PSWriteHTML` or `Install-Module ImportExcel`
2. Create a new function `Export-ActivityCharts`
3. Read activity data from JSON/CSV
4. Generate HTML with embedded charts using PSWriteHTML
5. Save HTML file for viewing in browser

**Code Example**:
```powershell
function Export-ActivityCharts {
    param([string]$DataFile, [string]$OutputPath)
    
    # Read data
    $data = Import-TrackingData -FilePath $DataFile
    
    # Process data for charts
    $chartData = $data.GetEnumerator() | ForEach-Object {
        $fileData = $_.Value.DailyActivity.GetEnumerator() | ForEach-Object {
            [PSCustomObject]@{
                Date = $_.Name
                File = (Split-Path $_.Name -Leaf)
                Minutes = [math]::Round($_.Value.TotalActiveSeconds / 60, 2)
            }
        }
    }
    
    # Generate HTML chart
    New-HTML -Title "Activity Charts" -FilePath $OutputPath {
        New-HTMLChart -Data $chartData -Type Bar -Keys 'Date' -Values 'Minutes' -Title "Daily Activity by File"
    }
}
```

**Pros**: Pure PowerShell, no external dependencies
**Cons**: Limited chart types, basic styling

**Option 2 - Web Dashboard Integration**:
Create a simple web interface using HTML/CSS/JavaScript that reads the JSON/CSV data and renders charts using libraries like Chart.js or D3.js. Would require a local web server or static file generation.

**Implementation Steps**:

1. Create HTML template with Chart.js library
2. Add JavaScript to read JSON/CSV data via fetch API
3. Process data and render multiple chart types (bar, line, pie)
4. Add interactive features like date filtering
5. Serve via local web server or static files

**Code Example** (HTML template):
```html
<!DOCTYPE html>
<html>
<head>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <canvas id="activityChart"></canvas>
    <script>
        fetch('activity_data.json')
            .then(response => response.json())
            .then(data => {
                // Process data and create charts
                const ctx = document.getElementById('activityChart').getContext('2d');
                new Chart(ctx, {
                    type: 'bar',
                    data: processedData,
                    options: chartOptions
                });
            });
    </script>
</body>
</html>
```

**Pros**: Rich visualizations, interactive
**Cons**: Requires web development knowledge, external libraries

## 3. Add support for additional applications (e.g., AutoCAD, SolidWorks)

**Summary**: Extend application detection to include more CAD and design software beyond Inventor, Excel, Word, and PowerPoint.

**Prerequisites**: COM API documentation for target applications
**Estimated Effort**: High (1-2 weeks)
**Dependencies**: Target applications installed for testing

**Option 1 - COM API Integration**:
Use COM automation APIs specific to each application (similar to current Inventor/Office implementation) to retrieve active document paths. Requires research into each application's COM interface and error handling for when applications aren't running.

**Implementation Steps**:

1. Research COM APIs for AutoCAD (AcadApplication) and SolidWorks (SldWorks.Application)
2. Add try-catch blocks for each application in Get-ActiveApplicationAndFile
3. Test with different versions of applications
4. Handle cases where applications aren't running

**Code Example**:
```powershell
elseif ($processName -ieq "ACAD") {
    try {
        $acadApp = [Runtime.InteropServices.Marshal]::GetActiveObject("AutoCAD.Application")
        if ($acadApp -and $acadApp.ActiveDocument) {
            $filename = $acadApp.ActiveDocument.FullName
        }
    }
    catch {
        # AutoCAD not running or no active document
    }
}
elseif ($processName -ieq "SLDWORKS") {
    try {
        $swApp = [Runtime.InteropServices.Marshal]::GetActiveObject("SldWorks.Application")
        if ($swApp -and $swApp.ActiveDoc) {
            $filename = $swApp.ActiveDoc.GetPathName()
        }
    }
    catch {
        # SolidWorks not running or no active document
    }
}
```

**Pros**: Accurate file detection, reliable
**Cons**: Requires COM API knowledge, version compatibility issues

**Option 2 - Window Title Parsing**:
Implement advanced regex patterns and heuristics to extract file paths from window titles for applications without COM APIs. This would be more generic but less reliable than direct API access.

**Implementation Steps**:

1. Analyze window title patterns for target applications
2. Create regex patterns to extract file paths
3. Add fallback logic when COM APIs aren't available
4. Test with various file types and paths

**Code Example**:
```powershell
# Enhanced filename extraction with regex patterns
$patterns = @(
    # AutoCAD: "Drawing1.dwg - AutoCAD 2023"
    '^(?<file>.+\.dwg)\s*-\s*AutoCAD',
    # SolidWorks: "Part1.SLDPRT - SOLIDWORKS 2023"
    '^(?<file>.+\.SLDPRT)\s*-\s*SOLIDWORKS',
    # Generic: "filename.ext - Application Name"
    '^(?<file>.+\.\w+)\s*-\s*(?<app>.+)$'
)

foreach ($pattern in $patterns) {
    if ($windowTitle -match $pattern) {
        $filename = $matches['file']
        break
    }
}
```

**Pros**: Works without COM APIs, more generic
**Cons**: Less reliable, requires pattern maintenance

## 4. Create web-based dashboard for viewing reports

**Summary**: Build a web interface for viewing and analyzing activity data in a user-friendly format.

**Prerequisites**: HTML/CSS/JavaScript knowledge, web server setup
**Estimated Effort**: High (1-2 weeks)
**Dependencies**: Web server (IIS, Apache, or PowerShell Universal)

**Option 1 - Static HTML Generation**:
Use PowerShell to generate static HTML files with embedded charts and tables that can be opened in any browser. No server required, just file generation.

**Implementation Steps**:

1. Create HTML template with placeholders
2. Use PowerShell string replacement to populate data
3. Generate charts using inline JavaScript
4. Add CSS for styling
5. Create refresh mechanism

**Code Example**:
```powershell
function New-ActivityDashboard {
    param([string]$DataFile, [string]$OutputPath)
    
    $data = Import-TrackingData -FilePath $DataFile
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Activity Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>Activity Dashboard - $(Get-Date)</h1>
    <div id="summary">
        Total Files: $($data.Count)
        Total Days: $(($data.Values.DailyActivity.Keys | Sort-Object -Unique).Count)
    </div>
    <canvas id="chart"></canvas>
    <script>
        // Chart.js code to render data
    </script>
</body>
</html>
"@
    
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
}
```

**Pros**: No server needed, simple deployment
**Cons**: Not interactive, requires regeneration for updates

**Option 2 - Local Web Server**:
Create a simple web application using PowerShell Universal or a .NET web API that serves dynamic content. More interactive but requires additional dependencies.

**Implementation Steps**:

1. Set up PowerShell Universal or ASP.NET Core
2. Create API endpoints to serve activity data
3. Build frontend with HTML/CSS/JavaScript
4. Add authentication if needed
5. Implement real-time updates

**Code Example** (PowerShell Universal):
```powershell
# In PSU dashboard
New-UDDashboard -Title "Activity Tracker" -Content {
    New-UDCard -Title "Today's Activity" -Content {
        # Dynamic content based on data
    }
    
    New-UDChart -Type Bar -Data $activityData
}
```

**Pros**: Interactive, real-time data
**Cons**: Requires web server setup, more complex

## 5. Add data backup and synchronization features

**Summary**: Ensure activity data is safely backed up and can be synchronized across multiple devices.

**Prerequisites**: Cloud API knowledge, Git experience
**Estimated Effort**: Medium (4-5 days)
**Dependencies**: Cloud service APIs or Git

**Option 1 - Cloud Storage Integration**:
Integrate with services like OneDrive, Google Drive, or Dropbox to automatically upload data files. Uses their APIs for seamless backup.

**Implementation Steps**:

1. Choose cloud service and get API credentials
2. Install required PowerShell modules (e.g., Microsoft.Graph for OneDrive)
3. Create backup function that uploads files periodically
4. Add restore functionality
5. Handle authentication securely

**Code Example**:
```powershell
function Backup-ToOneDrive {
    param([string]$LocalPath, [string]$RemotePath)
    
    Connect-MgGraph -Scopes "Files.ReadWrite"
    
    $fileContent = Get-Content $LocalPath -Raw
    $uploadParams = @{
        FilePath = $LocalPath
        OneDrivePath = $RemotePath
    }
    
    # Upload logic using Microsoft Graph API
}
```

**Pros**: Automatic, accessible from anywhere
**Cons**: Requires internet, API rate limits

**Option 2 - Git-Based Sync**:
Store data files in a Git repository and use Git commands for version control and synchronization. Leverages existing Git infrastructure for backup and multi-device access.

**Implementation Steps**:

1. Initialize Git repo in data directory
2. Create automated commit script
3. Set up remote repository (GitHub, GitLab)
4. Add sync commands to main script
5. Handle merge conflicts

**Code Example**:
```powershell
function Sync-DataWithGit {
    param([string]$DataDir, [string]$RemoteUrl)
    
    Set-Location $DataDir
    
    if (-not (Test-Path ".git")) {
        git init
        git remote add origin $RemoteUrl
    }
    
    git add .
    git commit -m "Auto-backup: $(Get-Date)"
    git push origin main
}
```

**Pros**: Version control, works offline
**Cons**: Requires Git knowledge, potential conflicts

## 6. Add multi-user support with centralized database

**Summary**: Enable multiple users to use the tracker with shared data storage and reporting.

**Prerequisites**: Database knowledge, network setup
**Estimated Effort**: High (2-3 weeks)
**Dependencies**: Database server (SQL Server, SQLite, or PostgreSQL)

**Option 1 - Shared Network Folder**:
Store data files on a network share with user-specific subfolders. Simple but requires network access and file permissions management.

**Implementation Steps**:

1. Set up network share with proper permissions
2. Modify data file paths to use UNC paths
3. Add user identification to data structure
4. Create shared reporting functions
5. Handle network connectivity issues

**Code Example**:
```powershell
$networkShare = "\\server\ActivityData"
$userFolder = Join-Path $networkShare $env:USERNAME

if (-not (Test-Path $userFolder)) {
    New-Item -ItemType Directory -Path $userFolder
}

$dataFile = Join-Path $userFolder "activity_data.json"
```

**Pros**: Simple to implement, no database needed
**Cons**: File locking issues, network dependency

**Option 2 - Database Backend**:
Migrate from JSON files to a database (SQLite or SQL Server) with user authentication and centralized storage. More robust but requires database setup and schema design.

**Implementation Steps**:

1. Choose database (SQLite for simplicity)
2. Design schema: Users, Files, ActivitySessions tables
3. Create database connection functions
4. Migrate existing data
5. Update all data access functions

**Code Example**:
```powershell
# SQLite schema
$createTables = @"
CREATE TABLE IF NOT EXISTS Users (
    UserId INTEGER PRIMARY KEY,
    Username TEXT UNIQUE,
    ComputerName TEXT
);

CREATE TABLE IF NOT EXISTS Files (
    FileId INTEGER PRIMARY KEY,
    UserId INTEGER,
    FilePath TEXT,
    Application TEXT,
    FOREIGN KEY (UserId) REFERENCES Users(UserId)
);

CREATE TABLE IF NOT EXISTS ActivitySessions (
    SessionId INTEGER PRIMARY KEY,
    FileId INTEGER,
    Date TEXT,
    TotalSeconds REAL,
    MouseClicks INTEGER,
    KeyPresses INTEGER,
    FOREIGN KEY (FileId) REFERENCES Files(FileId)
);
"@

# Database operations using System.Data.SQLite
```

**Pros**: Scalable, concurrent access
**Cons**: Complex setup, migration effort

## 7. Create installer package for easier deployment

**Summary**: Package the application for easy installation on multiple machines without manual setup.

**Prerequisites**: Installation tool knowledge, PowerShell packaging
**Estimated Effort**: Medium (3-4 days)
**Dependencies**: WiX Toolset or Advanced Installer

**Option 1 - PowerShell Script Installer**:
Create a PowerShell script that handles installation, sets up execution policies, and creates shortcuts. Simple but requires PowerShell execution.

**Implementation Steps**:

1. Create installation script with parameter validation
2. Set execution policy automatically
3. Create desktop/start menu shortcuts
4. Copy files to Program Files
5. Add uninstall functionality

**Code Example**:

```powershell
param(
    [string]$InstallPath = "$env:ProgramFiles\InventorTracker",
    [switch]$Uninstall
)

if ($Uninstall) {
    # Uninstall logic
    Remove-Item $InstallPath -Recurse -Force
    # Remove shortcuts
} else {
    # Install logic
    New-Item -ItemType Directory -Path $InstallPath -Force
    Copy-Item "*.ps1" $InstallPath
    Copy-Item "README.md" $InstallPath
    
    # Create shortcut
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut("$env:Public\Desktop\InventorTracker.lnk")
    $shortcut.TargetPath = "powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$InstallPath\UserActivityTracker.ps1`""
    $shortcut.Save()
}
```

**Pros**: Pure PowerShell, easy to modify
**Cons**: Requires PowerShell execution, no system integration

**Option 2 - MSI Package**:
Use tools like WiX Toolset or Advanced Installer to create a proper Windows MSI package with uninstaller and system integration.

**Implementation Steps**:

1. Install WiX Toolset
2. Create WiX source file (.wxs) defining components
3. Compile to MSI using candle and light
4. Test installation/uninstallation
5. Sign the MSI if needed

**Code Example** (WiX source):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
    <Product Id="*" Name="InventorTracker" Version="1.0.0.0">
        <Package InstallerVersion="200" Compressed="yes" />
        <Directory Id="TARGETDIR" Name="SourceDir">
            <Directory Id="ProgramFilesFolder">
                <Directory Id="InventorTracker" Name="InventorTracker">
                    <Component Id="MainExecutable" Guid="*">
                        <File Id="UserActivityTracker.ps1" Source="UserActivityTracker.ps1" />
                    </Component>
                </Directory>
            </Directory>
        </Directory>
        <Feature Id="ProductFeature" Title="InventorTracker" Level="1">
            <ComponentRef Id="MainExecutable" />
        </Feature>
    </Product>
</Wix>
```

**Pros**: Professional installation, system integration
**Cons**: Steep learning curve, requires additional tools

