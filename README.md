# InventorTracker

A PowerShell-based activity tracking tool that monitors user engagement with files across various applications, particularly Autodesk Inventor and Microsoft Office suite applications.

## Features

- **Real-time Activity Monitoring**: Tracks mouse clicks, key presses, and continuous activity per second
- **Application Detection**: Automatically detects and records active applications including:
  - Autodesk Inventor
  - Microsoft Excel
  - Microsoft Word
  - Microsoft PowerPoint
  - Other Windows applications
- **File-based Tracking**: Associates activity time with specific files being worked on
- **Daily Activity Reports**: Maintains separate activity logs for each day
- **Data Export**: Exports tracking data to both JSON and CSV formats
- **Auto-save**: Automatically saves data at configurable intervals
- **Console Display**: Shows current active application and file in real-time

## Installation

1. Clone or download the repository to your local machine
2. Ensure PowerShell execution policy allows script execution:

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. Run the main script:

   ```powershell
   .\UserActivityTracker.ps1
   ```

## Usage

1. Start the tracker by running `UserActivityTracker.ps1`
2. The script will begin monitoring activity after a 5-second countdown
3. Activity data is automatically saved to `activity_data-[computer]-[user].json`
4. CSV exports are generated in the same directory
5. Press Ctrl+C to stop monitoring

## Configuration

- **Save Interval**: Modify `$SaveIntervalSeconds` in the script (default: 300 seconds)
- **Data Files**: JSON and CSV files are created in the script's directory
- **Activity Scoring**: Adjust activity weights in the scoring algorithm if needed

## Data Structure

The tracker records the following metrics per file per day:

- Total active seconds
- Mouse clicks
- Key presses
- Continuous activity seconds
- Last seen time
- Application name

## Files

- `UserActivityTracker.ps1` - Main tracking script
- `DataManager.ps1` - Handles data loading, saving, and CSV export
- `Get-ActiveApplication.ps1` - Application and file detection utilities

## Requirements

- Windows 10/11
- PowerShell 5.1 or higher
- Administrative privileges may be required for some COM API access

## Troubleshooting

- If application detection fails, ensure the target applications are running
- Check Windows permissions for COM object access
- Verify PowerShell execution policy settings

## Future Enhancements / TODO

01- [ ] Implement idle time detection and exclusion
02- [ ] Implement activity visualization charts
03- [ ] Add support for additional applications (e.g., AutoCAD, SolidWorks)
04- [ ] Create web-based dashboard for viewing reports
05- [ ] Add data backup and synchronization features
06- [ ] Add multi-user support with centralized database
07- [ ] Create installer package for easier deployment


## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is provided as-is for personal and organizational use. Please review and comply with all applicable software licenses for the applications being monitored.

## Version History

- v0.022 - Enhanced application detection, CSV export improvements, filename truncation
- Previous versions - Initial activity tracking functionality
