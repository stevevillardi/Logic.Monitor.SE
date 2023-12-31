<#
.SYNOPSIS
Exports an HTML report containing changed network configs

.DESCRIPTION
Export device config change report based on the number of days specified, defaults to using the Devices by Type/Network folder

.PARAMETER DeviceGroupId
Device group id for the group to use as the source of running the report.

.PARAMETER DeviceId
Device id to use as the source of running the report, defaults to Devices by Type/Network folder if not specified

.PARAMETER DaysBack
Number of days back to run the report, defaults to 7 if not specified

.PARAMETER Path
Path to export the HTML report to

.PARAMETER InstanceNameFilter
Regex filter to use to filter out Instance names used for discovery, defaults to "running|current|PaloAlto".

.PARAMETER ConfigSourceNameFilter
Regex filter to use to filter out ConfigSource names used for discovery, defaults to ".*"

.PARAMETER OpenOnCompletion
Open the output html report automatically once completed

.EXAMPLE
Export-LMDeviceConfigReport -DaysBack 30 -DeviceGroupId 2 -Path export-report.html

.EXAMPLE
Export-LMDeviceConfigReport -Path export-report.html -OpenOnCompletion

.NOTES
You must run this command before you will be able to execute other commands included with the Logic.Monitor module.

.INPUTS
None. You cannot pipe objects to this command.

.LINK
Module repo: https://github.com/stevevillardi/Logic.Monitor.SE

.LINK
PSGallery: https://www.powershellgallery.com/packages/Logic.Monitor.SE
#>

Function Export-LMDeviceConfigReport {

    [CmdletBinding(DefaultParameterSetName="Device")]
    Param (
        [Parameter(ParameterSetName="DeviceGroup",Mandatory)]
        [Int]$DeviceGroupId,
        
        [Parameter(ParameterSetName="Device",Mandatory)]
        [Int]$DeviceId,

        [Regex]$InstanceNameFilter = "[rR]unning|[cC]urrent|[pP]aloAlto",

        [Regex]$ConfigSourceNameFilter = ".*",

        [String]$DaysBack = 7,
        
        [Parameter(Mandatory)]
        [String]$Path,

        [Switch]$OpenOnCompletion
    )

    #Check if we are logged in and have valid api creds
    If ($(Get-LMAccountStatus).Valid) {

        If($DeviceId){
            $network_devices = Get-LMDevice -id $DeviceId
        }
        Else {
            $network_devices = Get-LMDeviceGroupDevices -id $DeviceGroupId
        }

        #Loop through Network group devices and pull list of applied ConfigSources
        $instance_list = @()
        Write-Host -Message "Found $(($network_devices | Measure-Object).Count) devices."
        Foreach ($device in $network_devices) {
            Write-Host -Message "Collecting configurations for: $($device.displayName)"
            $device_config_sources = Get-LMDeviceDatasourceList -id $device.id | Where-Object { $_.dataSourceType -eq "CS" -and $_.instanceNumber -gt 0 -and $_.dataSourceName -match $ConfigSourceNameFilter }

            Write-Host -Message " [INFO]: Found $(($device_config_sources | Measure-Object).Count) configsource(s) with discovered instances using match filter ($ConfigSourceNameFilter)." -ForegroundColor Gray
            #Loop through DSes and pull all instances matching running or current and add them to processing list
            $filtered_config_instance_count = 0
            Foreach ($config_source in $device_config_sources) {
                $running_config_instance = Get-LMDeviceDatasourceInstance -DeviceId $config_source.deviceId -DatasourceId $config_source.dataSourceId
                $filtered_config_instance = $running_config_instance | Where-Object { $_.displayName -Match $InstanceNameFilter}
                If ($filtered_config_instance) {
                    Foreach($instance in $filtered_config_instance){
                        $filtered_config_instance_count++
                        $instance_list += [PSCustomObject]@{
                            deviceId              = $device.id
                            deviceDisplayName     = $device.displayName
                            dataSourceId          = $config_source.id
                            dataSourceName        = $config_source.datasourceName
                            dataSourceDisplayname = $config_source.dataSourceDisplayname
                            instanceDisplayName   = $instance.displayName
                            instanceDescription   = $instance.description
                            instanceId            = $instance.id
                        }
                    }
                }
            }
            Write-Host -Message " [INFO]: Found $filtered_config_instance_count configsource instance(s) using match filter ($InstanceNameFilter)."  -ForegroundColor Gray
        }

        #Loop through filtered instance list and pull config diff
        $device_configs = @()
        Foreach ($instance in $instance_list) {
            $device_configs += Get-LMDeviceConfigSourceData -id $instance.deviceId -HdsId $instance.dataSourceId -HdsInsId $instance.instanceId -ConfigType Delta
        }
        
        #We found some config changes, let organize them
        $output_list = @()
        If ($device_configs) {
            #Filter configs by start and end date based on number of days to look back

            #Get start and end epoch range
            $start_date = [Math]::Floor((New-TimeSpan -Start (Get-Date "01/01/1970") -End ((Get-Date).AddDays(-$DaysBack).ToUniversalTime())).TotalMilliseconds)
            $end_date = [Math]::Floor((New-TimeSpan -Start (Get-Date "01/01/1970") -End ((Get-Date).ToUniversalTime())).TotalMilliseconds)
            
            #Remove old configs from report to limit processing
            $device_configs = $device_configs | Where-Object { $_.pollTimestamp -ge $start_date -and $_.pollTimestamp -le $end_date }
            
            #Group Configs by device so we can work through each set
            $config_grouping = $device_configs | Group-Object -Property deviceId
            Write-Host -Message "Collecting latest device configurations from $(($config_grouping | Measure-Object).Count) devices."

            #Loop through each set and built report
            Foreach ($device in $config_grouping) {
                Write-Host -Message " [INFO]: Found $(($device.Group | Measure-Object).Count) configsource instance version(s) for: $($device.deviceDisplayName) matching selected range of last $DaysBack day(s)"  -ForegroundColor Gray
                Foreach ($config in $device.Group) {
                    Foreach ($line in $config.deltaConfig) {
                        $output_list += [PSCustomObject]@{
                            deviceDisplayName        = $config.deviceDisplayName
                            deviceInstanceName       = $config.instanceName
                            devicePollTimestampEpoch = $config.pollTimestamp
                            devicePollTimestampUTC   = [datetimeoffset]::FromUnixTimeMilliseconds($config.pollTimestamp).DateTime
                            deviceConfigVersion      = $config.version
                            configChangeType         = $line.type
                            configChangeRow          = $line.rowNo
                            configChangeContent      = $line.content
                        }
                    }
                }
            }
        }
        If($output_list){
            #Generate HTML Report
            New-HTML -TitleText "LogicMonitor - Config Report" -ShowHTML:$OpenOnCompletion -Online -FilePath $Path {
                New-HTMLPanel {
                    New-HTMLTable -DataTable $output_list -HideFooter -ScrollCollapse -PagingLength 1000 {
                        New-TableHeader -Title "LogicMonitor - Config Report (Last $DaysBack days)" -Alignment center -BackGroundColor BuddhaGold -Color White -FontWeight bold
                        New-TableRowGrouping -Name "deviceDisplayName"
                    }
                }
            }
        }
        Else{
            Write-Host -Message "Did not find any configs to output based on date range selected ($DaysBack days), check your parameters and try again." -ForegroundColor Yellow
        }
        
    }
    Else {
        Write-Error "Please ensure you are logged in before running any commands, use Connect-LMAccount to login and try again."
    }
}
