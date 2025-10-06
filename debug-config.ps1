# Simple test to debug configuration loading
. "$PSScriptRoot\src\ActivityDetector.ps1"

$configPath = "$PSScriptRoot\src\tracked_apps.json"
Write-Host "Loading config from: $configPath"

$appConfigs = Load-AppConfigurations -ConfigPath $configPath
Write-Host "Config type: $($appConfigs.GetType())"
Write-Host "Config count: $($appConfigs.Count)"

if ($appConfigs.Count -gt 0) {
    Write-Host "First app: $($appConfigs[0] | ConvertTo-Json)"
}