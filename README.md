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
- **Idle Threshold**: Configure minimum activity thresholds to filter out brief interruptions
- **Application Filters**: Exclude specific applications from tracking (e.g., system processes)

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
- For high CPU usage, increase the tracking interval or reduce activity sensitivity
- If CSV exports are empty, check file permissions in the output directory
- For network-shared files, ensure UNC paths are accessible and permissions are correct

## Privacy and Security

- **Data Privacy**: All tracking data remains local by default - no data is sent to external servers
- **File Path Privacy**: Consider using file hashing for sensitive project names in shared environments
- **User Consent**: Ensure proper notification and consent when deploying in corporate environments
- **Data Retention**: Implement automatic cleanup of old tracking data based on retention policies

## Use Cases

- **Project Time Tracking**: Automatically track time spent on different projects based on file locations
- **Productivity Analysis**: Identify peak productivity hours and application usage patterns
- **Billing and Invoicing**: Generate accurate time logs for client billing in consulting environments
- **Team Performance**: Analyze team productivity patterns (with proper privacy considerations)
- **Process Optimization**: Identify bottlenecks in design workflows and software usage

## Future Enhancements / TODO

- [ ] Implement idle time detection and exclusion
- [ ] Implement activity visualization charts
- [ ] Add support for additional applications (e.g., AutoCAD, SolidWorks)
- [ ] Create web-based dashboard for viewing reports
- [ ] Add data backup and synchronization features
- [ ] Add multi-user support with centralized database
- [ ] Create installer package for easier deployment
- [ ] Add privacy controls and data anonymization options
- [ ] Implement automatic project categorization based on file paths
- [ ] Add integration with calendar systems for context-aware tracking
- [ ] Create mobile companion app for status viewing
- [ ] Add productivity scoring and goal-setting features


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
