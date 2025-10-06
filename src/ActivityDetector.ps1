# src/ActivityDetector.ps1
# This module contains the core activity detection logic extracted from the original script

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class UltraSensitiveDetector {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
    
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    
    [DllImport("kernel32.dll")]
    public static extern uint GetTickCount();
    
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    
    [DllImport("user32.dll")]
    public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder lpClassName, int nMaxCount);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetWindow(IntPtr hWnd, uint uCmd);
    
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    
    // Generic app detection that accepts configurable patterns
    public static bool IsAppActive(string processName, string mainTitleSubstring, string[] titlePatterns, string[] classPatterns) {
        IntPtr hwnd = GetForegroundWindow();
        if (hwnd == IntPtr.Zero) return false;
        
        System.Text.StringBuilder windowText = new System.Text.StringBuilder(256);
        GetWindowText(hwnd, windowText, windowText.Capacity);
        string title = windowText.ToString();
        
        // Get window class name for additional identification
        System.Text.StringBuilder className = new System.Text.StringBuilder(256);
        GetClassName(hwnd, className, className.Capacity);
        string classNameStr = className.ToString();
        
        // PRIMARY CHECK: Main application window (most reliable)
        if (!string.IsNullOrEmpty(mainTitleSubstring) && title.IndexOf(mainTitleSubstring, StringComparison.OrdinalIgnoreCase) >= 0) {
            return true;
        }
        
        // SECONDARY CHECK: Get process to verify it's actually the target app
        uint processId;
        GetWindowThreadProcessId(hwnd, out processId);
        
        try {
            System.Diagnostics.Process process = System.Diagnostics.Process.GetProcessById((int)processId);
            string currentProcessName = process.ProcessName.ToLower();
            
            // Check if process name matches (with optional version suffix)
            if (currentProcessName == processName.ToLower() || currentProcessName.StartsWith(processName.ToLower() + ".")) {
                // Additional validation for known dialog patterns
                if (IsAppDialog(title, classNameStr, titlePatterns, classPatterns, processName)) {
                    return true;
                }
            }
        }
        catch {
            // Process access failed, don't assume it's the target app
        }
        
        return false;
    }
    
    // Legacy Inventor-specific method for backward compatibility
    public static bool IsInventorActive() {
        // This will be updated by PowerShell wrapper to load patterns
        return false; // Placeholder - PowerShell will override this
    }
    
    // Identify app dialogs and sub-windows using configurable patterns
    private static bool IsAppDialog(string title, string className, string[] titlePatterns, string[] classPatterns, string processName) {
        if (titlePatterns != null) {
            string lowerTitle = title.ToLower();
            foreach (string pattern in titlePatterns) {
                if (!string.IsNullOrWhiteSpace(pattern) && lowerTitle.Contains(pattern.ToLower())) {
                    return true;
                }
            }
        }
        
        if (classPatterns != null) {
            string lowerClassName = className.ToLower();
            foreach (string pattern in classPatterns) {
                if (!string.IsNullOrWhiteSpace(pattern) && lowerClassName.Contains(pattern.ToLower())) {
                    // Additional check: make sure parent or owner window belongs to the app
                    return HasAppParent(processName);
                }
            }
        }
        
        return false;
    }
    
    // Check if any visible app window exists (fallback detection)
    private static bool HasAppParent(string processName) {
        try {
            System.Diagnostics.Process[] appProcesses = 
                System.Diagnostics.Process.GetProcessesByName(processName);
            
            foreach (var process in appProcesses) {
                if (process.MainWindowHandle != IntPtr.Zero && 
                    IsWindowVisible(process.MainWindowHandle)) {
                    return true;
                }
            }
        }
        catch {
            // Process enumeration failed
        }
        
        return false;
    }
    
    public static int GetNewMouseClicks() {
        int clickCount = 0;
        
        // Check for NEW mouse button presses only (not held state)
        // 0x0001 = newly pressed (not held)
        if ((GetAsyncKeyState(0x01) & 0x0001) != 0) clickCount++; // Left mouse (newly pressed)
        if ((GetAsyncKeyState(0x02) & 0x0001) != 0) clickCount++; // Right mouse (newly pressed)
        if ((GetAsyncKeyState(0x04) & 0x0001) != 0) clickCount++; // Middle mouse (newly pressed)
        
        return clickCount;
    }
    
    public static int GetNewKeyPresses(int[] keysToCheck) {
        if (keysToCheck == null || keysToCheck.Length == 0) {
            return 0;
        }
        
        foreach (int key in keysToCheck) {
            if ((GetAsyncKeyState(key) & 0x0001) != 0) { // Newly pressed
                return 1; // Return 1 if any meaningful key was newly pressed
            }
        }
        
        return 0;
    }
    
    // Legacy method for backward compatibility
    public static int GetNewKeyPresses() {
        return 0; // Will be overridden by PowerShell wrapper
    }
    
    public static bool HasContinuousActivity() {
        // Only detect meaningful continuous activity:
        // 1. Mouse dragging (left mouse held down)
        // 2. Middle mouse button held (pan/orbit in CAD)
        // 3. Specific modifier keys commonly used in CAD work
        
        // Check for mouse dragging (left mouse button held)
        if ((GetAsyncKeyState(0x01) & 0x8000) != 0) {
            return true;
        }
        
        // Check for middle mouse button held (common for pan/orbit operations)
        if ((GetAsyncKeyState(0x04) & 0x8000) != 0) {
            return true;
        }
        
        // Check for specific meaningful keys that indicate intentional continuous activity
        // Ctrl, Shift, Alt (commonly held during CAD operations)
        if ((GetAsyncKeyState(0x10) & 0x8000) != 0 || // Shift
            (GetAsyncKeyState(0x11) & 0x8000) != 0 || // Ctrl
            (GetAsyncKeyState(0x12) & 0x8000) != 0) { // Alt
            return true;
        }
        
        // Check for arrow keys (often held for continuous movement/rotation)
        if ((GetAsyncKeyState(0x25) & 0x8000) != 0 || // Left arrow
            (GetAsyncKeyState(0x26) & 0x8000) != 0 || // Up arrow
            (GetAsyncKeyState(0x27) & 0x8000) != 0 || // Right arrow
            (GetAsyncKeyState(0x28) & 0x8000) != 0) { // Down arrow
            return true;
        }
        
        // Check for space bar (often held for pan/orbit in CAD)
        if ((GetAsyncKeyState(0x20) & 0x8000) != 0) { // Space
            return true;
        }
        
        return false;
    }
}
"@

# Helper function to load patterns from text files
function Load-PatternsFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { 
        Write-Warning "Pattern file not found: $Path"
        return @() 
    }
    
    try {
        Get-Content $Path -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#') }
    }
    catch {
        Write-Warning "Error loading pattern file: $Path - $($_.Exception.Message)"
        return @()
    }
}

# Helper function to load monitored keys
function Load-MonitoredKeys {
    param([string]$Path)
    if (-not (Test-Path $Path)) { 
        Write-Warning "Monitored keys file not found: $Path"
        # Return default keys if file not found
        return @(65..90) + @(48..57) + @(112..123) + @(13, 27, 32, 8, 46, 9, 37, 38, 39, 40, 33, 34, 35, 36)
    }
    
    try {
        $keys = Get-Content $Path -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and -not $_.StartsWith('#') -and $_ -match '^\d+$' } |
            ForEach-Object { [int]$_ }
        
        if ($keys.Count -eq 0) {
            # Return default keys if file is empty
            return @(65..90) + @(48..57) + @(112..123) + @(13, 27, 32, 8, 46, 9, 37, 38, 39, 40, 33, 34, 35, 36)
        }
        
        return $keys
    }
    catch {
        Write-Warning "Error loading monitored keys file: $Path - $($_.Exception.Message)"
        # Return default keys on error
        return @(65..90) + @(48..57) + @(112..123) + @(13, 27, 32, 8, 46, 9, 37, 38, 39, 40, 33, 34, 35, 36)
    }
}

# Load app configurations
function Load-AppConfigurations {
    param([string]$ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Warning "App configuration file not found: $ConfigPath"
        return @()
    }
    
    try {
        $configJson = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        return $configJson.applications
    }
    catch {
        Write-Warning "Error loading app configuration: $($_.Exception.Message)"
        return @()
    }
}

# Get active file for applications that support it
function Get-ActiveFile {
    param($AppConfig)
    
    if (-not $AppConfig.trackFiles -or [string]::IsNullOrEmpty($AppConfig.comObject)) {
        return $null
    }
    
    try {
        $app = New-Object -ComObject $AppConfig.comObject -ErrorAction Stop
        
        switch ($AppConfig.name) {
            "Inventor" {
                if ($app.ActiveDocument) {
                    return $app.ActiveDocument.DisplayName
                }
            }
            "Excel" {
                if ($app.ActiveWorkbook) {
                    return $app.ActiveWorkbook.Name
                }
            }
            "Acrobat" {
                $activeDoc = $app.GetActiveDoc()
                if ($activeDoc) {
                    return $activeDoc.GetFileName()
                }
            }
        }
    }
    catch {
        # COM object not available or app not running
    }
    
    return $null
}

# Check which tracked applications are currently active
function Get-ActiveTrackedApps {
    <#
    .SYNOPSIS
    Checks all configured applications and returns which ones are currently active
    
    .DESCRIPTION
    Loads the tracked_apps.json configuration and checks each application.
    Returns details about active apps including file information when available.
    
    .EXAMPLE
    $activeApps = Get-ActiveTrackedApps
    foreach ($app in $activeApps) {
        Write-Host "$($app.Name) is active$(if($app.ActiveFile) { " - File: $($app.ActiveFile)" })"
    }
    #>
    
    $scriptDir = if ($PSScriptRoot) { 
        $PSScriptRoot 
    } elseif ($MyInvocation.MyCommand.Definition) { 
        Split-Path -Parent $MyInvocation.MyCommand.Definition 
    } else { 
        Get-Location 
    }
    
    $configFile = Join-Path $scriptDir 'tracked_apps.json'
    $appConfigs = Load-AppConfigurations $configFile
    
    $activeApps = @()
    
    foreach ($appConfig in $appConfigs) {
        $titlePatterns = @()
        $classPatterns = @()
        
        if (![string]::IsNullOrEmpty($appConfig.titlePatternsFile)) {
            $titleFile = Join-Path $scriptDir $appConfig.titlePatternsFile
            $titlePatterns = Load-PatternsFile $titleFile
        }
        
        if (![string]::IsNullOrEmpty($appConfig.classPatternsFile)) {
            $classFile = Join-Path $scriptDir $appConfig.classPatternsFile
            $classPatterns = Load-PatternsFile $classFile
        }
        
        $isActive = [UltraSensitiveDetector]::IsAppActive(
            $appConfig.processName, 
            $appConfig.mainTitleSubstring, 
            $titlePatterns, 
            $classPatterns
        )
        
        if ($isActive) {
            $activeFile = Get-ActiveFile $appConfig
            
            $activeApps += [PSCustomObject]@{
                Name = $appConfig.name
                ProcessName = $appConfig.processName
                IsActive = $true
                ActiveFile = $activeFile
                TrackFiles = $appConfig.trackFiles
            }
        }
    }
    
    return $activeApps
}

# Generic app detection function
function Test-AppActive {
    param(
        [string]$ProcessName,
        [string]$MainTitleSubstring,
        [string[]]$TitlePatterns,
        [string[]]$ClassPatterns
    )
    
    return [UltraSensitiveDetector]::IsAppActive($ProcessName, $MainTitleSubstring, $TitlePatterns, $ClassPatterns)
}

# PowerShell wrapper functions to make the C# code easy to use
function Test-InventorActive {
    <#
    .SYNOPSIS
    Checks if Autodesk Inventor is the currently active window
    
    .DESCRIPTION
    Uses configurable pattern files to determine if Inventor is active,
    including main windows and tool dialogs. Falls back to hardcoded patterns if files are missing.
    
    .EXAMPLE
    if (Test-InventorActive) {
        Write-Host "Inventor is active"
    }
    #>
    
    # Try to get script directory, fallback to current directory
    $scriptDir = if ($PSScriptRoot) { 
        $PSScriptRoot 
    } elseif ($MyInvocation.MyCommand.Definition) { 
        Split-Path -Parent $MyInvocation.MyCommand.Definition 
    } else { 
        Get-Location 
    }
    
    $titleFile = Join-Path $scriptDir 'inventor_titles.txt'
    $classFile = Join-Path $scriptDir 'inventor_classes.txt'
    
    $titlePatterns = Load-PatternsFile $titleFile
    $classPatterns = Load-PatternsFile $classFile
    
    return Test-AppActive -ProcessName "Inventor" -MainTitleSubstring "Autodesk Inventor" -TitlePatterns $titlePatterns -ClassPatterns $classPatterns
}

function Get-ActivityInput {
    <#
    .SYNOPSIS
    Retrieves current user input activity (mouse clicks, key presses, continuous activity)
    
    .DESCRIPTION
    Returns a hashtable containing mouse clicks, key presses, and continuous activity status.
    Uses configurable monitored keys file.
    
    .EXAMPLE
    $activity = Get-ActivityInput
    if ($activity.MouseClicks -gt 0) {
        Write-Host "Mouse activity detected"
    }
    #>
    
    # Try to get script directory, fallback to current directory
    $scriptDir = if ($PSScriptRoot) { 
        $PSScriptRoot 
    } elseif ($MyInvocation.MyCommand.Definition) { 
        Split-Path -Parent $MyInvocation.MyCommand.Definition 
    } else { 
        Get-Location 
    }
    
    $keysFile = Join-Path $scriptDir 'monitored_keys.txt'
    $monitoredKeys = Load-MonitoredKeys $keysFile
    
    return @{
        MouseClicks = [UltraSensitiveDetector]::GetNewMouseClicks()
        KeyPresses = [UltraSensitiveDetector]::GetNewKeyPresses($monitoredKeys)
        IsContinuous = [UltraSensitiveDetector]::HasContinuousActivity()
    }
}
