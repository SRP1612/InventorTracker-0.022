# Get-ActiveApplication.ps1
# Program to detect the active application and filename if applicable

Write-Host "Monitoring active window in real-time. Press Ctrl+C to stop."
Write-Host ""

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class WindowInfo {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@

function Get-ActiveApplicationAndFile {
    <#
    .SYNOPSIS
        Gets the currently active application and filename if applicable.

    .DESCRIPTION
        Returns a hashtable with 'Application' and optionally 'Filename'.

    .EXAMPLE
        $result = Get-ActiveApplicationAndFile
        Write-Host "Application: $($result.Application)"
        if ($result.Filename) {
            Write-Host "Filename: $($result.Filename)"
        }
    #>

    try {
        $hWnd = [WindowInfo]::GetForegroundWindow()
        if ($hWnd -eq [IntPtr]::Zero) {
            return $null
        }

        # Get window title
        $titleBuilder = New-Object System.Text.StringBuilder 256
        [WindowInfo]::GetWindowText($hWnd, $titleBuilder, 256)
        $windowTitle = $titleBuilder.ToString()

        # Get process ID and name
        $processId = 0
        [WindowInfo]::GetWindowThreadProcessId($hWnd, [ref]$processId)
        $process = [System.Diagnostics.Process]::GetProcessById($processId)
        $processName = $process.ProcessName

        # Try to extract filename from title
        $filename = $null
        if ($windowTitle) {
            # Common patterns: "filename.ext - Application Name" or "Application Name - filename.ext"
            $parts = $windowTitle -split " - "
            if ($parts.Length -gt 1) {
                $potentialFile1 = $parts[0].Trim()
                $potentialFile2 = $parts[1].Trim()
                
                # Check first part for filename
                if ($potentialFile1 -match '\.\w+$') {
                    $filename = $potentialFile1
                }
                # If not found, check second part
                elseif ($potentialFile2 -match '\.\w+$') {
                    $filename = $potentialFile2
                }
            }
            # If no " - " separator, check if the whole title is a filename
            elseif ($windowTitle -match '\.\w+$') {
                $filename = $windowTitle
            }
        }

        # Special handling for specific applications using COM APIs
        if ($processName -eq "Inventor") {
            try {
                $inventorApp = [Runtime.InteropServices.Marshal]::GetActiveObject("Inventor.Application")
                if ($inventorApp -and $inventorApp.ActiveDocument) {
                    $activeDoc = $inventorApp.ActiveDocument
                    $filename = $activeDoc.FullFileName
                }
            }
            catch {
                # Inventor not running or no active document
            }
        }
        elseif ($processName -ieq "EXCEL") {
            try {
                $excelApp = [Runtime.InteropServices.Marshal]::GetActiveObject("Excel.Application")
                if ($excelApp -and $excelApp.ActiveWorkbook) {
                    $filename = $excelApp.ActiveWorkbook.FullName
                }
            }
            catch {
                # Excel not running or no active workbook
            }
        }
        elseif ($processName -ieq "WINWORD") {
            try {
                $wordApp = [Runtime.InteropServices.Marshal]::GetActiveObject("Word.Application")
                if ($wordApp -and $wordApp.ActiveDocument) {
                    $filename = $wordApp.ActiveDocument.FullName
                }
            }
            catch {
                # Word not running or no active document
            }
        }
        elseif ($processName -ieq "POWERPNT") {
            try {
                $pptApp = [Runtime.InteropServices.Marshal]::GetActiveObject("PowerPoint.Application")
                if ($pptApp -and $pptApp.ActivePresentation) {
                    $filename = $pptApp.ActivePresentation.FullName
                }
            }
            catch {
                # PowerPoint not running or no active presentation
            }
        }

        return @{
            Application = $processName
            Filename = $filename
        }
    }
    catch {
        Write-Warning "Error getting active application: $_"
        return $null
    }
}

# Example usage - Real-time monitoring


while ($true) {
    $result = Get-ActiveApplicationAndFile
    
    # Clear screen and display current info
    Clear-Host
    
    Write-Host "Monitoring active window in real-time. Press Ctrl+C to stop."
    Write-Host ""
    
    if ($result) {
        Write-Host "Active Application: $($result.Application)"
        if ($result.Filename) {
            Write-Host "Filename: $($result.Filename)"
        } else {
            Write-Host "No filename detected"
        }
    } else {
        Write-Host "Unable to detect active application"
    }
    
    # Update every second
    Start-Sleep -Seconds 1
}