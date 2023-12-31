<#
.SYNOPSIS
Create a series of dynamic groups based off of active system.categories applied to your portal

.DESCRIPTION
Created dynamic groups based on in use device categories

.EXAMPLE
ConvertTo-LMDynamicGroupFromCategories

.NOTES
Created groups will be placed in devices by type default resource group

.INPUTS
None. You cannot pipe objects to this command.

.LINK
Module repo: https://github.com/stevevillardi/Logic.Monitor.SE

.LINK
PSGallery: https://www.powershellgallery.com/packages/Logic.Monitor.SE
#>
Function ConvertTo-LMDynamicGroupFromCategories {
    Param(
        [String[]]$ExcludeCategoryList = @("TopoSwitch","snmpTCPUDP","LogicMonitorPortal","snmp","snmpUptime","snmpHR","Netsnmp","email rtt","email transit","collector","NoPing","NoHTTPS"),

        [String]$DefaultGroupName = "Devices by Category"
    )

    $device_list = @()
    $category_list = @()

    #Get list of LM devices
    $devices = Get-LMDevice

    #Loop through each device build custom object
    foreach ($dev in $devices) {
        $device_list += [PSCustomObject]@{
            id          = $dev.id
            displayName = ($dev.displayName).toupper()
            categories  = ($dev.customProperties[$dev.customProperties.name.IndexOf("system.categories")].value).Split(",")

        }
    }

    #Loop through custom object and aggregate categories
    foreach ($category in $device_list.categories) {
        If((!$ExcludeCategoryList.Contains($category)) -and ($category)){
            $category_list += $category
        }
    }

    #Dedupe list down to unique values
    $category_list = $category_list | Select-Object -Unique
    Write-Host "Found $($category_list.count) categories for creation"

    #Grab id for devices by type folder (could optionally be set to any group)
    $root_group = (Get-LMDeviceGroup -Name $DefaultGroupName).id

    #if we have a matching folder continue
    if ($root_group) {
        Write-Host "$DefaultGroupName already created, checking existing dynamic groups"

        #Grab list of dynamic groups currently inside root group
        $current_groups = (Get-LMDeviceGroupGroups -Id $root_group).name

        #Compare the group list and pull out anything we already created or matches existing groups
        If($current_groups){
            $creation_list = (Compare-Object -ReferenceObject $current_groups -DifferenceObject $category_list.Replace("/", " ").Replace("_", " ") | Where-Object { $_.SideIndicator -eq "=>" }).InputObject
        }
        else{
            $creation_list = $category_list.Replace("/", " ").Replace("_", " ")
        }
    
        #Loop trough category list and create any groups not already exisitng
        foreach ($group in $creation_list) {
            $name = $group.Replace("/", " ").Replace("_", " ")
            New-LMDeviceGroup -Name $name -AppliesTo "hasCategory(`"$group`")" -ParentGroupId $root_group -Description "Auto created by PowerShell module"
        }
    }
    Else{
        Write-Host "$DefaultGroupName not found, creating device group for category creation"
        $root_group = New-LMDeviceGroup -Name $DefaultGroupName -Description "Auto created by PowerShell module" -ParentGroupId 1

        #Loop trough category list and create any groups not already exisitng
        foreach ($group in $category_list.Replace("/", " ").Replace("_", " ")) {
            $name = $group.Replace("/", " ").Replace("_", " ")
            New-LMDeviceGroup -Name $name -AppliesTo "hasCategory(`"$group`")" -ParentGroupId $root_group.id -Description "Auto created by PowerShell module"
        }
    }
}