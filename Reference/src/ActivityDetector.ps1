# src/ActivityDetector.ps1
# This module contains the core activity detection logic

# Load configuration
$configPath = Join-Path $PSScriptRoot "..\config.json"
$config = Get-Content $configPath | ConvertFrom-Json

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class UltraSensitiveDetector {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int vKey);
    
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
    
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
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
    
    public static int GetNewKeyPresses() {
        // Check for NEW key presses only (not held state)
        // Only check commonly used keys in CAD applications to avoid system noise
        int[] keysToCheck = {
            // Letters A-Z
            65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
            // Numbers 0-9
            48, 49, 50, 51, 52, 53, 54, 55, 56, 57,
            // Function keys F1-F12
            112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123,
            // Common CAD keys
            13, // Enter
            27, // Escape
            32, // Space
            8,  // Backspace
            46, // Delete
            9,  // Tab
            // Arrow keys
            37, 38, 39, 40,
            // Page Up/Down, Home, End
            33, 34, 35, 36
        };
        
        foreach (int key in keysToCheck) {
            if ((GetAsyncKeyState(key) & 0x0001) != 0) { // Newly pressed
                return 1; // Return 1 if any meaningful key was newly pressed
            }
        }
        
        return 0;
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

# PowerShell wrapper functions to make the C# code easy to use
function Test-ActiveProgram {
    <#
    .SYNOPSIS
    Checks if the currently active program is in the included list
    
    .PARAMETER IncludedPrograms
    Array of program names to track
    
    .EXAMPLE
    if (Test-ActiveProgram -IncludedPrograms $config.IncludedPrograms) {
        Write-Host "Active program is tracked"
    }
    #>
    param(
        [Parameter(Mandatory)]
        [string[]]$IncludedPrograms
    )
    
    try {
        $hWnd = [UltraSensitiveDetector]::GetForegroundWindow()
        if ($hWnd -eq [IntPtr]::Zero) { return $false }
        
        # Get process ID and process name
        $processId = 0
        [UltraSensitiveDetector]::GetWindowThreadProcessId($hWnd, [ref]$processId)
        
        $process = [System.Diagnostics.Process]::GetProcessById($processId)
        $processName = $process.ProcessName.ToLower()
        
        # Check if process name is in included list
        return $processName -in $IncludedPrograms
    }
    catch {
        Write-Verbose "Error checking active program: $_"
        return $false
    }
}

function Get-ActivityInput {
    <#
    .SYNOPSIS
    Retrieves current user input activity (mouse clicks, key presses, continuous activity)
    
    .DESCRIPTION
    Returns a hashtable containing mouse clicks, key presses, and continuous activity status
    
    .EXAMPLE
    $activity = Get-ActivityInput
    if ($activity.MouseClicks -gt 0) {
        Write-Host "Mouse activity detected"
    }
    #>
    return @{
        MouseClicks = [UltraSensitiveDetector]::GetNewMouseClicks()
        KeyPresses = [UltraSensitiveDetector]::GetNewKeyPresses()
        IsContinuous = [UltraSensitiveDetector]::HasContinuousActivity()
    }
}
