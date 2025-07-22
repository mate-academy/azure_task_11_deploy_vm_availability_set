$locations = Get-AzLocation | Select-Object -ExpandProperty Location

foreach ($location in $locations) {
    Write-Host "Checking usage for region: $location"
    try {
        Get-AzVMUsage -Location $location | Where-Object {$_.Name.Value -eq "cores" -or $_.Name.Value -eq "total Regional Cores"} | Format-Table Name, CurrentValue, Limit, Unit
    }
    catch {
        Write-Warning "Could not retrieve usage for $location. Error: $($_.Exception.Message)"
    }
    Write-Host "" # Add a blank line for readability
}