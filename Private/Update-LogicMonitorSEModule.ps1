# Auto-Update PowerShell
Function Update-LogicMonitorSEModule {
    Param (
        [String]$Module = 'Logic.Monitor.SE',
        [Boolean]$UninstallFirst = $False,
        [Switch]$CheckOnly
    )

    # Read the currently installed version
    $Installed = Get-Module -ListAvailable -Name $Module

    # There might be multiple versions
    If ($Installed -is [Array]) {
        $InstalledVersion = $Installed[0].Version
    }
    Else {
        $InstalledVersion = $Installed.Version
        If(!$InstalledVersion){
            #Should not be possible, but even so just return if module is not detected
            return
        }
    }
    
    # Lookup the latest version Online
    $Online = Find-Module -Name $Module -Repository PSGallery -ErrorAction Stop
    $OnlineVersion = $Online.Version  

    # Compare the versions
    If ([System.Version]$OnlineVersion -gt [System.Version]$InstalledVersion) {
        
        # Uninstall the old version
        If($CheckOnly){
            Write-Host "You are currently using an outdated version ($InstalledVersion) of $Module, please consider upgrading to the latest version ($OnlineVersion) as soon as possible." -ForegroundColor Yellow
        }
        ElseIf ($UninstallFirst -eq $true) {
            Write-Host "Uninstalling prior Module $Module version $InstalledVersion"
            Uninstall-Module -Name $Module -Force -Verbose:$False
        }
        Else{
            Write-Host "Installing newer Module $Module version $OnlineVersion"
            Install-Module -Name $Module -Force -AllowClobber -Verbose:$False
        }
        
    } 
    Else {
        Write-Host "Module $Module version $InstalledVersion is the latest version."
    }
}