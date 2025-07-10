<#
.SYNOPSIS
Imports multi-credential configuration for LogicMonitor.

.DESCRIPTION
The Import-LMMultiCredentialConfig function imports multi-credential configuration for LogicMonitor. It allows you to specify SNMP and SSH credentials either as objects or by providing a CSV file path. It also provides options to generate example CSV files and specify the credential group and import group names.

.PARAMETER SNMPCredentialsObject
Specifies an object with SNMP credentials. This parameter is mandatory when using the SNMP-Config or SNMP-SSH-Config parameter sets.

.PARAMETER SNMPCsvFilePath
Specifies the file path to the SNMP CSV file. This parameter is mandatory when using the SNMP-Config-CSV or SNMP-SSH-Config-CSV parameter sets.

.PARAMETER SSHCredentialsObject
Specifies an object with SSH credentials. This parameter is mandatory when using the SSH-Config or SNMP-SSH-Config parameter sets.

.PARAMETER SSHCsvFilePath
Specifies the file path to the SSH CSV file. This parameter is mandatory when using the SSH-Config-CSV or SNMP-SSH-Config-CSV parameter sets.

.PARAMETER GenerateExampleCSV
Generates example CSV files for SSH and SNMP credentials.

.PARAMETER CredentialGroupName
Specifies the group name for where dynamic credential groups should be created. The default value is "Resource Credential Group".

.PARAMETER ImportGroupName
Specifies the group name for where devices will be onboarded into. The default value is "Resource Import Group".

.EXAMPLE
Import-LMMultiCredentialConfig -SNMPCredentialsObject $SNMPCredentials -SSHCredentialsObject $SSHCredentials -CredentialGroupName "MyCredentialGroup" -ImportGroupName "MyImportGroup"
Imports multi-credential configuration using SNMP and SSH credentials provided as objects. The dynamic credential groups will be created under the "MyCredentialGroup" group, and devices will be onboarded into the "MyImportGroup" group.

.EXAMPLE
Import-LMMultiCredentialConfig -SNMPCsvFilePath "C:\Path\To\SNMPCredentials.csv" -SSHCsvFilePath "C:\Path\To\SSHCredentials.csv"
Imports multi-credential configuration using SNMP and SSH credentials provided in CSV files located at the specified file paths.

.EXAMPLE
Import-LMMultiCredentialConfig -GenerateExampleCSV
Generates example CSV files for SSH and SNMP credentials.

#>
Function Import-LMMultiCredentialConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ParameterSetName="SNMP-Config")]
        [Parameter(Mandatory,ParameterSetName="SNMP-SSH-Config")]
        [Object]$SNMPCredentialsObject, #Object with SNMP credentials
        
        [Parameter(Mandatory,ParameterSetName="SNMP-Config-CSV")]
        [Parameter(Mandatory,ParameterSetName="SNMP-SSH-Config-CSV")]
        [ValidateScript({Test-Path $_})]
        [Object]$SNMPCsvFilePath, #File path to SNMP CSV
        
        [Parameter(Mandatory,ParameterSetName="SSH-Config")]
        [Parameter(Mandatory,ParameterSetName="SNMP-SSH-Config")]
        [Object]$SSHCredentialsObject, #Object with SSH credentials
        
        [Parameter(Mandatory,ParameterSetName="SSH-Config-CSV")]
        [Parameter(Mandatory,ParameterSetName="SNMP-SSH-Config-CSV")]
        [ValidateScript({Test-Path $_})]
        [Object]$SSHCsvFilePath, #File path to SSH CSV
        
        [Parameter(ParameterSetName="ExampleCSV")]
        [Switch]$GenerateExampleCSV,
        [String]$CredentialGroupName = "Resource Credential Group", #Group name for where dynamic cred groups should be created
        [String]$ImportGroupName = "Resource Import Group", #Group name for where devices will be onboarded into
        [String]$ImportGroupId #Group ID for where devices will be onboarded into, allows you to use groups that need fullPath as name like "Device by Type/Network"

    )
    Begin{
        $GitubURI = "https://raw.githubusercontent.com/stevevillardi"
    }
    Process{
        If($GenerateExampleCSV){
            $SampleCSV = ("name,sshuser,sshpass").Split(",")

            [PSCustomObject]@{
                $SampleCSV[0]="CorpSSHCred"
                $SampleCSV[1]="logicmonitor"
                $SampleCSV[2]="chamgeMe123"
            } | Export-Csv "SampleSSHCredCSV.csv"  -Force -NoTypeInformation

            Write-Host "[INFO]: Saved sample CSV (SampleSSHCredCSV.csv) to current directory."
            
            $SampleCSV = ("name,version,community,security,authMethod,authToken,privMethod,privToken").Split(",")

            $SampleContent = New-Object System.Collections.ArrayList
            $SampleContent.Add([PSCustomObject]@{
                $SampleCSV[0]="CorpROv2c"
                $SampleCSV[1]="v2c"
                $SampleCSV[2]="notpublic"
                $SampleCSV[3]="$null"
                $SampleCSV[4]="$null"
                $SampleCSV[5]="$null"
                $SampleCSV[6]="$null"
                $SampleCSV[7]="$null"
            }) | Out-Null
            $SampleContent.Add([PSCustomObject]@{
                $SampleCSV[0]="CorpROv3"
                $SampleCSV[1]="v3"
                $SampleCSV[2]="$null"
                $SampleCSV[3]="v3user"
                $SampleCSV[4]="MD5"
                $SampleCSV[5]="authpassword"
                $SampleCSV[6]="AES"
                $SampleCSV[7]="privpassword"
            }) | Out-Null

            $SampleContent | Export-Csv "SampleSNMPCredCSV.csv"  -Force -NoTypeInformation

            Write-Host "[INFO]: Saved sample CSV (SampleSNMPCredCSV.csv) to current directory."

            Return
        }

        #Check if we are logged in and have valid api creds
        If ($(Get-LMAccountStatus).Valid) {
            #Attempt to process credentials into JSON
            Try{
                Switch ($PsCmdlet.ParameterSetName) {
                    "SNMP-Config" {
                        #Convert to JSON
                        $SNMPCredentialsJSON = $SNMPCredentialsObject | ConvertTo-Json -ErrorAction Stop
                    }
                    
                    "SSH-Config" {
                        #Convert to JSON
                        $SSHCredentialsJSON = $SSHCredentialsObject | ConvertTo-Json -ErrorAction Stop
                    }
    
                    "SNMP-Config-CSV" {
                        #Convert CSV to proper object format
                        $SNMPCsvInfo = Import-Csv -Path $SNMPCsvFilePath

                        #Loop through creds list and add to JSON object
                        $SNMPCredentialsObject = New-Object System.Collections.ArrayList

                        Foreach($SNMPCred in $SNMPCsvInfo){
                            $priority = if ($SNMPCred.PSObject.Properties['priority']) { [int]$SNMPCred.priority } else { 0 }
                            If($SNMPCred.version -eq "v2c" -or $SNMPCred.version -eq "v2"){
                                $SNMPCredentialsObject.Add([PSCustomObject]@{
                                    name = $SNMPCred.name
                                    version = "v2c"
                                    community = $SNMPCred.community
                                    priority = $priority
                                }) | Out-Null
                            }
                            Else{
                                $SNMPCredentialsObject.Add([PSCustomObject]@{
                                    name = $SNMPCred.name
                                    version = "v3"
                                    v3 = [PSCustomObject]@{
                                        security = $SNMPCred.security
                                        authMethod = $SNMPCred.authMethod
                                        authToken = $SNMPCred.authToken
                                        privMethod = $SNMPCred.privMethod
                                        privToken = $SNMPCred.privToken
                                    }
                                    priority = $priority
                                }) | Out-Null
                            }
                        }
                        # Determine if priority column exists
                        $sortKey = if ($SNMPCsvInfo | Get-Member -Name 'priority') { 'priority' } else { 'name' }
                        # Convert to JSON after sorting by priority, then name
                        $SNMPCredentialsJSON = ($SNMPCredentialsObject | Sort-Object priority, name) | ConvertTo-Json -ErrorAction Stop
                    }
    
                    "SSH-Config-CSV" {
                        #Convert CSV to proper object format
                        $SSHCsvInfo = Import-Csv -Path $SSHCsvFilePath
                        
                        #Loop through creds list and add to JSON object
                        $SSHCredentialsObject = New-Object System.Collections.ArrayList
        
                        Foreach($SSHCred in $SSHCsvInfo){
                            $priority = if ($SSHCred.PSObject.Properties['priority']) { [int]$SSHCred.priority } else { 100 }
                            $SSHCredentialsObject.Add([PSCustomObject]@{
                                name = $SSHCred.name
                                sshuser = $SSHCred.sshuser
                                sshpass = $SSHCred.sshpass
                                priority = $priority
                            }) | Out-Null
                        }
                        $sortKey = if ($SSHCsvInfo | Get-Member -Name 'priority') { 'priority' } else { 'name' }
                        $SSHCredentialsJSON = ($SSHCredentialsObject | Sort-Object priority, name) | ConvertTo-Json -ErrorAction Stop
                    }
                }
            }
            Catch{
                Write-Error "[ERROR]: Unable to process credentials, ensure that supplied credentials are in the proper format, see -GenerateExampleCSV for expected format: $_"

                Return
            }

            # Track if ImportGroupName was explicitly set by the user
            $IsImportGroupNameDefault = ($PSBoundParameters['ImportGroupName'] -eq $null -or $ImportGroupName -eq "Resource Import Group")

            #Verifed JSON object, proceed with setting up multi-credential config
            $CredentialGroupId = (Get-LMDeviceGroup -Name $CredentialGroupName).Id
            If(!$CredentialGroupId){
                #Create new credential group
                $CredentialGroupId = (New-LMDeviceGroup -Name $CredentialGroupName -ParentGroupId 1 -Description "Auto created resource group for multi credential configuration").Id
            }

            If (-not $ImportGroupId) {
                $ImportGroupId = (Get-LMDeviceGroup -Name $ImportGroupName).Id
                If(!$ImportGroupId){
                    #Create new import group
                    $ImportGroupId = (New-LMDeviceGroup -Name $ImportGroupName -ParentGroupId 1 -Description "Auto created resource group for onboarding resources using multi credential configuration").Id
                }
            }else{
                #If ImportGroupId is provided, only overwrite ImportGroupName if it was not explicitly set
                if ($IsImportGroupNameDefault) {
                    $ImportGroupName = (Get-LMDeviceGroup -Id $ImportGroupId).fullPath
                }
            }

            #Bulk create dynamic credentials resource group
            If($CredentialGroupId -and $ImportGroupId){
                #Create SNMP dynamic credentials group
                Foreach ($Cred in $SNMPCredentialsObject){
                    If($Cred.v3){
                        $GroupArguments = @{
                            Name = $Cred.name
                            ParentGroupId = $CredentialGroupId
                            Properties = @{
                                "snmp.security" = $Cred.v3.security
                                "snmp.auth" = $Cred.v3.authMethod
                                "snmp.authToken" = $Cred.v3.authToken
                                "snmp.priv" = $Cred.v3.privMethod
                                "snmp.privToken" = $Cred.v3.privToken
                                "snmp.version" = "v3"
                            }
                            AppliesTo = "auto.lm_cred_tester.snmp.name == `"$($Cred.name)`""
                        }
                    }
                    Else{
                        $GroupArguments = @{
                            Name = $Cred.name
                            ParentGroupId = $CredentialGroupId
                            Properties = @{
                                "snmp.community" = $Cred.community
                                "snmp.version" = "v2c"
                            }
                            AppliesTo = "auto.lm_cred_tester.snmp.name == `"$($Cred.name)`""
                        }
                    }
                    $CredGroup = Get-LMDeviceGroup -Filter "name -eq '$($Cred.Name)' -and parentId -eq '$CredentialGroupId'"
                    If(!$CredGroup){
                        New-LMDeviceGroup @GroupArguments | Out-Null
                        Write-Host "[INFO]: Created SNMP credential group: $($Cred.name)"
                    }
                    Else{
                        Set-LMDeviceGroup -Id $CredGroup.Id -Properties $GroupArguments.Properties | Out-Null
                        Write-Host "[INFO]: Credential group $($Cred.name) already exists, updated properties."
                    }
                }
                #Create SSH dynamic credentials group
                Foreach ($Cred in $SSHCredentialsObject){
                    $GroupArguments = @{
                        Name = $Cred.name
                        ParentGroupId = $CredentialGroupId
                        Properties = @{
                            "ssh.user" = $Cred.sshuser
                            "ssh.pass" = $Cred.sshpass
                        }
                        AppliesTo = "auto.lm_cred_tester.ssh.name == `"$($Cred.name)`""
                    }

                    #Check if groups exists, if not create, else update
                    $CredGroup = Get-LMDeviceGroup -Filter "name -eq '$($Cred.Name)' -and parentId -eq '$CredentialGroupId'"
                    If(!$CredGroup){
                        New-LMDeviceGroup @GroupArguments | Out-Null
                        Write-Host "[INFO]: Created SSH credential group: $($Cred.name)"
                    }
                    Else{
                        Set-LMDeviceGroup -Id $CredGroup.Id -Properties $GroupArguments.Properties | Out-Null
                        Write-Host "[INFO]: Credential group $($Cred.name) already exists, updating properties."
                    }
                }

                #Import required logic modules
                $ModuleList = @(
                    @{
                        name = "Force_Active_Discovery.xml"
                        type = "datasource"
                        repo = "LogicMonitor-Dashboards/main/Suites/MultiCredTester"
                    },
                    @{
                        name = "SNMP_Credential_Tester.json"
                        type = "propertyrules"
                        repo = "LogicMonitor-Dashboards/main/Suites/MultiCredTester"
                    },
                    @{
                        name = "SSH_Credential_Tester.json"
                        type = "propertyrules"
                        repo = "LogicMonitor-Dashboards/main/Suites/MultiCredTester"
                    }
                )

                Foreach($Module in $ModuleList){
                    $ModuleName = $Module.name.Split(".")[0]
                    If($Module.type -eq "datasource"){
                        $LogicModule = Get-LMDataSource -name $ModuleName
                        If(!$LogicModule){
                            Try{
                                $ReplaceString = "&#60;path/to/import/group&#62;"
                                $LogicModule = (Invoke-WebRequest -Uri "$GitubURI/$($Module.repo)/$($Module.name)").Content
                                #Replace placeholder with actual group name
                                $LogicModule = $LogicModule -replace $ReplaceString, $ImportGroupName

                                Import-LMLogicModule -File $LogicModule -Type $Module.type -ErrorAction Stop
                                Write-Host "[INFO]: Successfully imported $ModuleName datasource"
                            }
                            Catch{
                                #Oops
                                Write-Error "[ERROR]: Unable to import $ModuleName LogicModule from source: $_" 
                            }
                        }
                        Else{
                            Write-Host "[INFO]: LogicModule $ModuleName already exists, skipping import" -ForegroundColor Gray
                        }
                    }
                    ElseIf ($Module.type -eq "propertyrules"){
                        $LogicModule = Get-LMPropertySource -name $ModuleName
                        If(!$LogicModule){
                            Try{
                                $LogicModule = (Invoke-WebRequest -Uri "$GitubURI/$($Module.repo)/$($Module.name)").Content
                                Import-LMLogicModule -File $LogicModule -Type $Module.type -ErrorAction Stop
                                Write-Host "[INFO]: Successfully imported $ModuleName propertysource"
                            }
                            Catch{
                                #Oops
                                Write-Error "[ERROR]: Unable to import $ModuleName LogicModule from source: $_" 
                            }
                        }
                        Else{
                            Write-Host "[INFO]: LogicModule $ModuleName already exists, skipping import" -ForegroundColor Gray
                        }
                    }
                }
                #Add cred properties to import group
                If($SNMPCredentialsJSON){
                    Try{
                        Set-LMDeviceGroup -Properties @{ "lm_cred_tester.snmp.pass" = $SNMPCredentialsJSON } -Id $ImportGroupId | Out-Null
                        Write-Host "[INFO]: Successfully set SNMP credentials property on import group."
                    }
                    Catch{
                        Write-Error "[ERROR]: Unable to set SNMP credentials property on import group: $_." 
                        Return
                    }
                }
                If ($SSHCredentialsJSON){
                    Try {
                        Set-LMDeviceGroup -Properties @{ "lm_cred_tester.ssh.pass" = $SSHCredentialsJSON } -Id $ImportGroupId | Out-Null
                        Write-Host "[INFO]: Successfully set SSH credentials property on import group."
                    }
                    Catch {
                        Write-Error "[ERROR]: Unable to set SSH credentials property on import group: $_." 
                        Return
                    }
                }

                #Setup user and role for API key
                $LMMultiCredRoleName = "lm-multi-cred-role"
                $LMMultiCredUserName = "lm_multi_cred_user"
                $LMMultiCredUser = Get-LMUser -Name $LMMultiCredUserName
                $LMMultiCredRole = Get-LMRole -Name $LMMultiCredRoleName

                If(!$LMMultiCredRole){
                    Write-Host "[INFO]: Setting up Multi Credential Config API Role: $LMMultiCredRoleName"
                    $LMMultiCredRole = New-LMRole -Name $LMMultiCredRoleName -ResourcePermission manage -Description "Auto provisioned to allow for API token creation for use with multi credential configuration."
                    If($LMMultiCredRole){
                        Write-Host "[INFO]: Successfully setup API role: $LMMultiCredRoleName"
                    }
                }
                Else{
                    Write-Host "[INFO]: Multi Credential Config API Role ($LMMultiCredRoleName) already exists in portal, skipping setup" -ForegroundColor Gray
                }

                If(!$LMMultiCredUser){
                    Write-Host "[INFO]: Setting up Multi Credential Config API user: $LMMultiCredUsernName"
                    $LMMultiCredUser = New-LMAPIUser -Username "$LMMultiCredUserName" -note "Auto provisioned for use with Multi Credential Config" -RoleNames @($LMMultiCredRoleName)
                    If ($LMMultiCredUser) {
                        Write-Host "[INFO]: Successfully setup API user: $LMMultiCredUserName"
                    }
                }
                Else {
                    Write-Host "[INFO]: Multi Credential Config API User ($LMMultiCredUserName) already exists in portal, skipping setup" -ForegroundColor Gray
                }

                #Set API creds on minimal monitoring group
                $MinimalMonitoringGroupId = (Get-LMDeviceGroup -Name "Minimal Monitoring").Id
                If($MinimalMonitoringGroupId){
                    $LMMultiCredAPIINfo = New-LMAPIToken -id $LMMultiCredUser.id -Note "Auto provisioned for use with Multi Credential Config"
                    Set-LMDeviceGroup -Properties @{"lmaccess.id" = $LMMultiCredAPIINfo.accessId; "lmaccess.key" = $LMMultiCredAPIINfo.accessKey} -Id $MinimalMonitoringGroupId  | Out-Null
                    Write-Host "[INFO]: Successfully set API credentials on Minimal Monitoring group ($($LMMultiCredAPIINfo.accessId))."
                }
                Else{
                    Write-Error "[ERROR]: Unable to find Minimal Monitoring group, please ensure that it exists and try again." 
                    Return
                }

                #Cleanup
                Write-Host "[INFO]: Successfully configured multi-credential configuration, please ensure that devices are onboarded into the $ImportGroupName group."
            }
            Else{
                Write-Error "[ERROR]: Unable to find or create resource groups for multi-credential configuration, please check and try again."
                Return
            }
        }
    }
    End{}
}
