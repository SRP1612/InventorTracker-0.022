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

## 8. Add privacy controls and data anonymization options

**Summary**: Implement features to protect sensitive information in tracking data, especially important for enterprise deployments.

**Prerequisites**: Cryptography knowledge, privacy regulation compliance
**Estimated Effort**: Medium (3-4 days)
**Dependencies**: .NET cryptography libraries

**Option 1 - File Path Hashing**:
Replace sensitive file paths and names with cryptographic hashes while maintaining tracking functionality. This allows analysis without exposing actual project names or locations.

**Implementation Steps**:

1. Create hash function for file paths using SHA-256
2. Maintain hash-to-path mapping in encrypted lookup table
3. Add configuration option to enable/disable anonymization
4. Modify all display and export functions to use hashed names
5. Implement secure key management for hash lookup

**Code Example**:

```powershell
function Get-AnonymizedPath {
    param([string]$FilePath, [string]$Salt)
    
    $hasher = [System.Security.Cryptography.SHA256]::Create()
    $saltedPath = $FilePath + $Salt
    $hashBytes = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($saltedPath))
    $hashString = [System.BitConverter]::ToString($hashBytes).Replace("-", "")
    
    return "Project_" + $hashString.Substring(0, 8)
}

# Store mapping securely
$pathMappings = @{}
$anonymizedPath = Get-AnonymizedPath -FilePath $realPath -Salt $userSalt
$pathMappings[$anonymizedPath] = $realPath
```

**Pros**: Strong privacy protection, regulatory compliance
**Cons**: Harder to interpret reports, requires key management

**Option 2 - Configurable Data Filtering**:
Allow users to configure which data elements to exclude or anonymize based on patterns, file types, or directory structures.

**Implementation Steps**:

1. Create privacy configuration file with filtering rules
2. Add pattern matching for sensitive directories/files
3. Implement data masking for specific file types
4. Add user consent and notification features
5. Create audit trail for privacy compliance

**Code Example**:

```powershell
$privacyConfig = @{
    ExcludePatterns = @("*\Personal\*", "*\Confidential\*")
    MaskExtensions = @(".docx", ".xlsx", ".pdf")
    AnonymizeProjectCodes = $true
    RequireConsent = $true
}

function Test-ShouldTrackFile {
    param([string]$FilePath)
    
    foreach ($pattern in $privacyConfig.ExcludePatterns) {
        if ($FilePath -like $pattern) {
            return $false
        }
    }
    return $true
}
```

**Pros**: Flexible, user-controlled privacy
**Cons**: Complex configuration, potential for misconfiguration

## 9. Implement automatic project categorization based on file paths

**Summary**: Automatically categorize tracked activity into projects or work categories based on file system organization and naming conventions.

**Prerequisites**: Regex knowledge, organizational file structure understanding
**Estimated Effort**: Medium (4-5 days)
**Dependencies**: None (built-in PowerShell features)

**Option 1 - Rule-Based Categorization**:
Create configurable rules that match file paths to project categories using regex patterns and directory structures.

**Implementation Steps**:

1. Design categorization rule configuration format
2. Create rule engine for pattern matching
3. Add category assignment to tracking data
4. Implement rule priority and fallback logic
5. Create category-based reporting views

**Code Example**:

```powershell
$categoryRules = @(
    @{ Pattern = ".*\\Projects\\([^\\]+)\\.*"; Category = "Project: {1}"; Priority = 1 },
    @{ Pattern = ".*\\CAD\\.*"; Category = "CAD Design"; Priority = 2 },
    @{ Pattern = ".*\\Reports\\.*"; Category = "Documentation"; Priority = 2 },
    @{ Pattern = ".*\\Admin\\.*"; Category = "Administrative"; Priority = 3 }
)

function Get-FileCategory {
    param([string]$FilePath)
    
    foreach ($rule in ($categoryRules | Sort-Object Priority)) {
        if ($FilePath -match $rule.Pattern) {
            $category = $rule.Category
            # Replace placeholders with regex matches
            for ($i = 1; $i -le $matches.Count - 1; $i++) {
                $category = $category.Replace("{$i}", $matches[$i])
            }
            return $category
        }
    }
    return "Uncategorized"
}
```

**Pros**: Automated, customizable, scalable
**Cons**: Requires initial rule configuration, may need tuning

**Option 2 - Machine Learning Classification**:
Use historical data and file characteristics to automatically learn and predict project categories.

**Implementation Steps**:

1. Collect training data from existing file structures
2. Extract features (path components, file types, timestamps)
3. Train simple classification model (naive Bayes or decision tree)
4. Implement real-time classification
5. Add feedback mechanism for improving accuracy

**Code Example**:

```powershell
function Get-FileFeatures {
    param([string]$FilePath)
    
    $pathParts = $FilePath.Split('\')
    $extension = [System.IO.Path]::GetExtension($FilePath)
    $directory = [System.IO.Path]::GetDirectoryName($FilePath)
    
    return @{
        Extension = $extension
        DirectoryDepth = $pathParts.Length
        ContainsNumbers = $FilePath -match '\d+'
        ContainsProjectCode = $FilePath -match '[A-Z]{2,3}-\d{3,4}'
        DirectoryName = $pathParts[-2]
    }
}

# Simple classification logic
function Classify-Project {
    param($Features, $TrainingData)
    # Implement basic ML classification
    # Compare features against known patterns
}
```

**Pros**: Self-improving, learns from usage patterns
**Cons**: Requires training data, more complex implementation

## 10. Add integration with calendar systems for context-aware tracking

**Summary**: Integrate with Outlook/Google Calendar to provide context about meetings, deadlines, and scheduled work for more meaningful activity analysis.

**Prerequisites**: Calendar API knowledge, OAuth implementation
**Estimated Effort**: High (1-2 weeks)
**Dependencies**: Microsoft Graph API or Google Calendar API

**Option 1 - Outlook Integration via Microsoft Graph**:
Connect to Microsoft 365 calendar to correlate activity tracking with scheduled meetings and events.

**Implementation Steps**:

1. Set up Microsoft Graph API authentication
2. Retrieve calendar events for current day
3. Correlate activity periods with calendar entries
4. Add meeting context to activity reports
5. Identify productive vs. meeting time

**Code Example**:

```powershell
# Install-Module Microsoft.Graph
function Get-CalendarContext {
    param([DateTime]$StartTime, [DateTime]$EndTime)
    
    Connect-MgGraph -Scopes "Calendars.Read"
    
    $events = Get-MgUserEvent -Filter "start/dateTime ge '$($StartTime.ToString('yyyy-MM-ddTHH:mm:ss'))' and end/dateTime le '$($EndTime.ToString('yyyy-MM-ddTHH:mm:ss'))'"
    
    return $events | ForEach-Object {
        @{
            Subject = $_.Subject
            Start = $_.Start.DateTime
            End = $_.End.DateTime
            Type = if ($_.IsAllDay) { "All Day" } else { "Meeting" }
        }
    }
}

function Add-CalendarContext {
    param($ActivityData, $CalendarEvents)
    
    foreach ($activity in $ActivityData) {
        $overlappingEvents = $CalendarEvents | Where-Object {
            $activity.StartTime -ge $_.Start -and $activity.EndTime -le $_.End
        }
        $activity.CalendarContext = $overlappingEvents
    }
}
```

**Pros**: Rich context, meeting correlation, productivity insights
**Cons**: Requires permissions, OAuth complexity, API rate limits

**Option 2 - iCal File Integration**:
Read standard calendar files (ICS format) that can be exported from any calendar system for simpler integration.

**Implementation Steps**:

1. Implement ICS file parser
2. Set up automatic calendar file updates
3. Create event matching algorithm
4. Add calendar overlay to activity timeline
5. Generate context-aware reports

**Code Example**:

```powershell
function Parse-ICalFile {
    param([string]$ICalPath)
    
    $content = Get-Content $ICalPath -Raw
    $events = @()
    
    # Simple ICS parsing
    $eventBlocks = $content -split 'BEGIN:VEVENT'
    foreach ($block in $eventBlocks[1..$eventBlocks.Length]) {
        if ($block -match 'DTSTART:(\d{8}T\d{6}Z)' -and $block -match 'SUMMARY:(.+)') {
            $events += @{
                Start = [DateTime]::ParseExact($matches[1], 'yyyyMMddTHHmmssZ', $null)
                Summary = $matches[2].Trim()
            }
        }
    }
    return $events
}
```

**Pros**: Universal format, no API dependencies, works offline
**Cons**: Manual file updates, limited real-time integration

## 11. Create mobile companion app for status viewing

**Summary**: Develop a mobile application or responsive web interface for viewing activity status and reports on mobile devices.

**Prerequisites**: Mobile development or responsive web design
**Estimated Effort**: High (2-3 weeks)
**Dependencies**: Mobile development framework or web technologies

**Option 1 - Progressive Web App (PWA)**:
Create a responsive web application that works on mobile devices and can be installed as a native app.

**Implementation Steps**:

1. Design responsive HTML/CSS interface
2. Implement JavaScript for data visualization
3. Add PWA manifest and service workers
4. Create mobile-optimized charts and reports
5. Add push notifications for status updates

**Code Example**:

```html
<!-- PWA Manifest -->
{
  "name": "InventorTracker Mobile",
  "short_name": "InvTracker",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#000000",
  "icons": [
    {
      "src": "icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    }
  ]
}

<!-- Mobile-optimized dashboard -->
<div class="mobile-dashboard">
  <div class="status-card">
    <h3>Today's Activity</h3>
    <div class="metric">
      <span class="value" id="total-hours">0</span>
      <span class="label">Hours</span>
    </div>
  </div>
</div>
```

**Pros**: Cross-platform, web-based, easier deployment
**Cons**: Limited native features, requires web server

**Option 2 - Native Mobile App**:
Develop native iOS/Android applications with full platform integration.

**Implementation Steps**:

1. Choose development framework (Xamarin, Flutter, React Native)
2. Design native UI for activity viewing
3. Implement data synchronization with desktop app
4. Add native notifications and widgets
5. Publish to app stores

**Code Example** (Flutter):

```dart
class ActivityStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text('Current Activity', style: Theme.of(context).textTheme.headline6),
          StreamBuilder<ActivityStatus>(
            stream: activityStream,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Text('Working on: ${snapshot.data.filename}');
              }
              return CircularProgressIndicator();
            },
          ),
        ],
      ),
    );
  }
}
```

**Pros**: Full native features, better performance, offline capability
**Cons**: Multiple platform development, app store approval, higher complexity

## 12. Add productivity scoring and goal-setting features

**Summary**: Implement productivity metrics, scoring algorithms, and goal-setting capabilities to gamify the tracking experience and encourage productivity improvements.

**Prerequisites**: Statistics knowledge, goal-setting methodology
**Estimated Effort**: Medium (5-6 days)
**Dependencies**: None (mathematical calculations)

**Option 1 - Algorithmic Productivity Scoring**:
Create scoring algorithms based on activity patterns, focus time, and application usage to generate productivity scores.

**Implementation Steps**:

1. Define productivity metrics (focus time, task switching, break patterns)
2. Create weighted scoring algorithm
3. Implement trend analysis and historical comparison
4. Add productivity insights and recommendations
5. Create scoring dashboard and reports

**Code Example**:

```powershell
function Calculate-ProductivityScore {
    param($DayActivity, $UserBaseline)
    
    $focusScore = Get-FocusScore $DayActivity.ContinuousMinutes
    $efficiencyScore = Get-EfficiencyScore $DayActivity.TaskSwitches
    $consistencyScore = Get-ConsistencyScore $DayActivity.WorkPattern
    
    $weightedScore = ($focusScore * 0.4) + ($efficiencyScore * 0.35) + ($consistencyScore * 0.25)
    
    return @{
        OverallScore = [math]::Round($weightedScore, 1)
        FocusScore = $focusScore
        EfficiencyScore = $efficiencyScore
        ConsistencyScore = $consistencyScore
        Insights = Get-ProductivityInsights $DayActivity $UserBaseline
    }
}

function Get-FocusScore {
    param([int]$ContinuousMinutes)
    
    # Score based on sustained focus periods
    $focusPeriods = $ContinuousMinutes / 25  # 25-minute focus blocks
    return [math]::Min(100, $focusPeriods * 10)
}
```

**Pros**: Objective measurement, gamification, improvement tracking
**Cons**: Subjective nature of productivity, may not suit all work styles

**Option 2 - Goal-Based Tracking System**:
Allow users to set specific goals (time targets, application usage limits, focus periods) and track progress against them.

**Implementation Steps**:

1. Create goal configuration interface
2. Implement goal types (daily hours, application limits, project time)
3. Add progress tracking and notifications
4. Create achievement system with badges/rewards
5. Generate goal-focused reports and analytics

**Code Example**:

```powershell
$userGoals = @{
    DailyHours = @{ Target = 8; Type = "Minimum" }
    InventorTime = @{ Target = 4; Type = "Minimum" }
    MaxEmailTime = @{ Target = 1; Type = "Maximum" }
    FocusBlocks = @{ Target = 6; Type = "Count" }
}

function Check-GoalProgress {
    param($TodayActivity, $Goals)
    
    $progress = @{}
    
    foreach ($goal in $Goals.GetEnumerator()) {
        $actualValue = Get-GoalActualValue $TodayActivity $goal.Key
        $targetValue = $goal.Value.Target
        
        $progress[$goal.Key] = @{
            Actual = $actualValue
            Target = $targetValue
            Progress = [math]::Round(($actualValue / $targetValue) * 100, 1)
            Status = if ($actualValue -ge $targetValue) { "Achieved" } else { "In Progress" }
        }
    }
    
    return $progress
}
```

**Pros**: Personalized, motivational, clear targets
**Cons**: Requires user engagement, goal setting complexity

---

## Footnotes and Additional Considerations

### Performance and Security Notes

**Note 1**: *Idle Time Detection Security* - When implementing idle time detection, consider that some enterprise security software may interfere with GetLastInputInfo API calls. Alternative approaches include monitoring clipboard changes, network activity, or file system events as secondary indicators of user activity.

**Note 2**: *Application COM API Versions* - COM API integration requires version-specific handling. AutoCAD's COM API varies significantly between versions (2018+ uses different object models than older versions). Consider implementing version detection logic to handle multiple API versions gracefully.

**Note 3**: *Chart Performance* - For visualization charts with large datasets (>10,000 activity records), consider implementing data pagination or aggregation. Chart.js performance degrades with datasets larger than 5,000 points. PSWriteHTML may require chunking for very large reports.

### Technical Implementation Details

**Note 4**: *Database Schema Evolution* - When implementing the multi-user database backend, design the schema with versioning in mind. Include a schema_version table and migration scripts to handle future data structure changes without losing existing tracking data.

**Note 5**: *Web Dashboard CORS Issues* - Static HTML dashboards that fetch JSON files locally will encounter CORS restrictions in modern browsers. Consider serving files via a simple HTTP server (Python's `http.server` module or PowerShell's `Start-SimpleHTTPServer`) or embedding data directly in HTML.

**Note 6**: *Backup Encryption* - For cloud storage integration, implement client-side encryption before uploading activity data. Personal activity tracking data contains sensitive information about work patterns and file access that should be encrypted at rest.

### Alternative Implementation Approaches

**Note 7**: *Event-Driven Architecture* - Instead of polling for active applications every second, consider implementing Windows Event Tracing (ETW) or WMI event subscriptions to detect application focus changes. This reduces CPU overhead and improves accuracy.

**Note 8**: *Cross-Platform Considerations* - While the current implementation is Windows-specific, the core tracking logic could be abstracted to support macOS (using AppleScript/Objective-C) and Linux (using X11/Wayland APIs) for organizations with mixed environments.

**Note 9**: *Machine Learning Enhancement* - Advanced idle detection could incorporate machine learning to learn individual user patterns. Some users naturally have longer pauses between interactions, and ML could adapt thresholds based on historical behavior patterns.

### Integration Opportunities

**Note 10**: *Time Tracking Integration* - Consider integration with existing time tracking systems (Toggl, Harvest, Clockify) via their APIs. This could automatically start/stop timers based on detected application activity, bridging the gap between passive monitoring and active time tracking.

**Note 11**: *Project Management Integration* - File path analysis could automatically categorize activity by project based on folder structures or naming conventions. Integration with project management tools (Jira, Azure DevOps, Asana) could provide project context to tracked time.

**Note 12**: *Reporting Automation* - Implement scheduled reporting that automatically generates and emails weekly/monthly summaries to managers or team leads. This could include productivity insights, most-used applications, and time distribution analysis.

### Enterprise and Compliance Considerations

**Note 13**: *GDPR and Privacy Compliance* - For European deployments, ensure GDPR compliance by implementing data portability, right to deletion, and explicit consent mechanisms. Consider data minimization principles and purpose limitation for tracking data collection.

**Note 14**: *Audit Trail Implementation* - Enterprise environments may require comprehensive audit trails showing when tracking was active, what data was collected, and any modifications made to historical data. Include immutable logging for compliance requirements.

**Note 15**: *Performance Monitoring* - Add system resource monitoring to ensure the tracker doesn't impact system performance. Include CPU/memory usage reporting and automatic throttling when system resources are constrained.

### Advanced Analytics and AI Integration

**Note 16**: *Predictive Analytics* - Implement machine learning models to predict project completion times based on historical activity patterns. This could help with better project planning and resource allocation.

**Note 17**: *Anomaly Detection* - Add algorithms to detect unusual activity patterns that might indicate security issues, system problems, or changes in work habits that require attention.

**Note 18**: *Natural Language Processing* - For organizations with standardized file naming conventions, implement NLP to automatically extract project information, client names, and task types from file names and paths.

### Collaboration and Team Features

**Note 19**: *Team Dashboard* - Create collaborative features showing team activity patterns, workload distribution, and identifying potential bottlenecks in collaborative projects. Include privacy controls for individual vs. aggregate reporting.

**Note 20**: *Integration with Collaboration Tools* - Consider integration with Slack, Microsoft Teams, or other collaboration platforms to provide activity status updates and enable team coordination based on current work focus.

