<#
.SYNOPSIS
	This script performs the installation of driver and firmware updates on Lenovo hardware using the Thin Installer utility.
	# LICENSE #
	PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows. 
	Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
	This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details. 
	You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.PARAMETER RepositoryLocation
    Specifies the UNC path of the ThinkVantage Update Retriever repository, e.g. '\\UpdateServer\Updates'
.PARAMETER ExportToWMI
    Enables the export of update status to the ROOT\Lenovo\Lenovo_Updates WMI class. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
        69000: RepositoryLocation not specified
        69001: RepositoryLocation not a valid path
        69002: Could not open the update information .xml file for one of the updates
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK 
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false,
    [Parameter(Mandatory=$false)]
    [string]$RepositoryLocation,
    [Parameter(Mandatory=$false)]
	[switch]$ExportToWMI = $false,
    [Parameter(Mandatory=$false)]
	[switch]$ReEnableBitLocker = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}
	
	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'Lenovo'
	[string]$appName = 'Thin Installer'
	[string]$appVersion = '1.3.0007'
	[string]$appArch = ''
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '2019-06-17'
	[string]$appScriptAuthor = 'Ryan Steele'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''
	
	##* Do not modify section below
	#region DoNotModify
	
	## Variables: Exit Code
	[int32]$mainExitCode = 0
	
	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.7.0'
	[string]$deployAppScriptDate = '02/13/2018'
	[hashtable]$deployAppScriptParameters = $psBoundParameters
	
	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
	
	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}
	
	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================
		
	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

        ## Script creates a scheduled task set to run at startup to call itself again with the -ReEnableBitLocker switch if needed
        If($ReEnableBitLocker) {
            ## Re-enable BitLocker
            Execute-Process -Path "$envSystem32Directory\manage-bde.exe" -Parameters "-protectors -enable $envSystemDrive"
            ## Unregister the scheduled task
            Execute-Process -Path "SCHTASKS" -Parameters "/Delete /TN `"$InstallTitle - Re-Enable BitLocker`" /F"
            Exit-Script -ExitCode 0
        }

        ## Exit with fast retry if we are on battery
        If(-not (Test-Battery)) { Exit-Script 1618 }

        If ($exportToWMI) { $exportToWMISwitch = '-exporttowmi' }

        ## We will increment rebootTypeCount[n] for each update requiring reboot type n that is Applicable
        $rebootTypeCount = 0,0,0,0,0,0
        $rebootTypeDesc = "No reboot required",
                          "Reboot forced by the package",
                          "Reserved",
                          "Reboot required but not forced by the package",
                          "Shutdown forced by the package",
                          "Reboot delayed"

        ## Perform update scan
        If (!$repositoryLocation) { 
            Write-Log "ERROR: No repository location was specified"
            Exit-Script 69000 
        }
        If (-not (Test-Path (Join-Path -Path $repositoryLocation -ChildPath 'database.xml'))) { 
            Write-Log "ERROR: No database.xml found in $repositoryLocation"
            Exit-Script 69001 
        }
        Execute-Process -Path "ThinInstaller.exe" -Parameters "/CM -search A -action SCAN -repository $RepositoryLocation -includerebootpackages 1,3,4,5 $exportToWMIswitch"

        ## Load SQLite DB generated by Thin Installer
        Add-Type -Path (Join-Path -Path $dirFiles -ChildPath "System.Data.SQLite.dll")
        $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
        $con.ConnectionString = "Data Source=$(Join-Path -Path $dirFiles -ChildPath "logs\update_history.db")"
        $con.Open()
        $sql = $con.CreateCommand()
        $sql.CommandText = "SELECT * FROM updatehistory"
        $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
        $data = New-Object System.Data.DataSet
        [void]$adapter.Fill($data)
            
        ## Iterate through rows in DB and collect reboot type for Applicable packages
        Write-Log "$($data.tables[0].rows.count) rows in the database"
        ForEach ($row in $data.tables[0].rows) {
            $id = $row.id
            $title = $row.title
            $status = $row.status
            If ($status -eq "Applicable") {
                $path = Join-Path -Path $RepositoryLocation -ChildPath "$($id)\$($id)_2_.xml"
                Try {
                    $xml = Select-Xml -XPath / -Path $path
                } Catch {
                    Write-Log "Could not open $path"
                    Exit-Script 69002
                }
                $rebootType = $xml.node.Package.Reboot.type
                $rebootTypeCount[$rebootType]++
                Write-Log "$id - $title - $status - $rebootType"
            } Else {
                Write-Log "$id - $title - $status"
            }
        }
        Write-Log "*** Applicable updates ***"
        For ($i = 0; $i -lt $rebootTypeCount.length; $i++) {
            Write-Log "Type $($i) ($($rebootTypeDesc[$i])): $($rebootTypeCount[$i])"
        }
        Write-Log "**************************"
		
		
		##*===============================================
		##* INSTALLATION 
		##*===============================================
		[string]$installPhase = 'Installation'

        ## First, install any updates that don't force a reboot
        If ($rebootTypeCount[0] -or $rebootTypeCount[3]) {
            Execute-Process -Path "ThinInstaller.exe" `
                -Parameters "/CM -search A -action INSTALL -repository $RepositoryLocation -includerebootpackages 3 -noicon -noreboot $exportToWMISwitch"
        }

        ## If a user is logged in, request to install updates requiring an immediate reboot or shutdown
        If ($isProcessUserInteractive -and ($rebootTypeCount[1] -or $rebootTypeCount[4] -or $rebootTypeCount[5])) {
            Write-Log "Install will force reboot or shutdown, so prompting user"
            $message = 'An important software update is available. This update will restart your computer, so save and close your documents before proceeding. '`
                + 'Do not unplug or shut down your computer until the Windows sign in screen is displayed.'
            $proceedText = 'Update and restart now'
            $deferText = 'Remind me later'
            $userResponse = Show-InstallationPrompt -Message $message -ButtonLeftText $proceedText -ButtonRightText $deferText -PersistPrompt -ExitOnTimeout $false
            If ($userResponse) { Write-Log "User chose $userResponse" }
            If ($userResponse -eq $proceedText) {
		        ## Detect whether BitLocker is enabled and disable if necessary (i.e. Secure Boot not enabled)
                $BitLockerWMIObject = Get-WmiObject -namespace root\CIMv2\Security\MicrosoftVolumeEncryption -class Win32_EncryptableVolume | `
                    Where-Object {$_.DriveLetter -eq $envSystemDrive}
                <# FIXME: Ideally we shouldn't have to suspend BitLocker before updating BIOS if Secure Boot is enabled, but
                          ThinkCentre M93p prompts for BitLocker recovery after BIOS update even if Secure Boot is enabled
                Try { 
                    $SecureBootEnabled = Confirm-SecureBootUEFI 
                    If ($SecureBootEnabled) { Write-Log "Secure Boot is enabled" } Else { Write-Log "Secure Boot is disabled" }
                } Catch {
                    Write-Log "System does not support Secure Boot"
                }
                If (!$SecureBootEnabled -and $BitLockerWMIObject.ProtectionStatus -eq 1) {
                    Write-Log -Message "Secure Boot is disabled and BitLocker is enabled on drive $envSystemDrive"
                #>
                If ($BitLockerWMIObject.ProtectionStatus -eq 1) {               ## FIXME: Replace these 2 lines when 
                    Write-Log "BitLocker is enabled on drive $envSystemDrive"   ##        Secure Boot issue is resolved
                    If ($envOSVersionMajor -eq 6 -and $envOSVersionMinor -eq 1) { # Windows 7
                        Write-Log "OS is Windows 7, so scheduling a task to re-enable BitLocker after the reboot" 
                        ## Schedule a task to re-run the script at startup with the -ReEnableBitLocker switch
                        Execute-Process -Path "SCHTASKS" -Parameters $("/Create /SC ONSTART /RU System /TR `"'$scriptParentPath\Deploy-Application.exe' "`
                                + "-ReEnableBitLocker`" /TN `"$InstallTitle - Re-Enable BitLocker`" /F") 
                    } Else {
                        Write-Log "OS is not Windows 7"
                    }
                    ## Suspend BitLocker
                    Execute-Process -Path "$envSystem32Directory\manage-bde.exe" -Parameters "-protectors -disable $envSystemDrive"
                }
                Show-InstallationProgress -StatusMessage "Installation in progress.`nDo not unplug or shut down your computer."
                Execute-Process -Path "ThinInstaller.exe" `
                    -Parameters "/CM -search A -action INSTALL -repository $RepositoryLocation -includerebootpackages 1,4,5 -nocontinueafterreboot -noicon $exportToWMISwitch"
            }
        }
		
		
		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		If ($rebootTypeCount[3]) {
            #Exit-Script 3010
            Show-InstallationRestartPrompt -CountdownSeconds 28800 -CountdownNoHideSeconds 3600
        } ElseIf ($rebootTypeCount[1] -or $rebootTypeCount[4] -or $rebootTypeCount[5]) {
            If ($userResponse -eq $deferText) { Start-Sleep 1200 } ## TODO: Make delay value a parameter to the script
            Exit-Script 1618
        }
		
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
				
		## <Perform Pre-Uninstallation tasks here>
		
		
		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'
				
		# <Perform Uninstallation tasks here>
		
		
		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'
		
		## <Perform Post-Uninstallation tasks here>
		
		
	}
	
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================
	
	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}