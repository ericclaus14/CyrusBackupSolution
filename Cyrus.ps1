<#
.SYNOPSIS
    Core Powershell script for the Cyrus Backup Solution

.DESCRIPTION
    This script ties together the config file and Powershell module for the Cyrus Backup Solution.

.NOTES
    Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
    Last Modified: 3/18/2019

.LINK
    https://github.com/ericclaus14/CyrusBackupSolution
#>

[CmdletBinding()]
Param()

if ($VerbosePreference -eq "Continue") {echo "it's verbose!"}

$date = Get-Date -Format MM-dd-yyyy-HHmm
Start-Transcript -Path "$CBSRootDir\$date.transcript"

# Read in config file to variable
$configFile = Get-IniContent -FilePath C:\Repos\CyrusBackupSolution\Cyrus-Config.ini

# Loop through each backup job defined inside of the config file
foreach ($backupJob in $configFile.Keys) {
    # All the comments in the config file get lumped together into their own sub-hash table
    # Skip it
    if ($backupJob -eq "No-Section") {Continue}

    # Properties common to all backup types
    $name = $configFile[$backupJob].Name
    $type = $configFile[$backupJob].Type
    $frequency = $configFile[$backupJob].Frequency
    $retention = $configFile[$backupJob].Retention
    $bkDir = $configFile[$backupJob].BkDir
    $owner = $configFile[$backupJob].Owner

    # Properties not common to all backup types
    $hypervisor = $configFile[$backupJob].Host
    $sourcePath = $configFile[$backupJob].SourcePath
    $netPath = $configFile[$backupJob].NetPath
    $serverInstance = $configFile[$backupJob].ServerInstance
    $database = $configFile[$backupJob].Database
    $passwordFile = $configFile[$backupJob].PasswordFile
    $userName = $configFile[$backupJob].UserName
    $encryptionKeyFile = $configFile[$backupJob].EncryptionKeyFile
    $backupFileExetnsion = $configFile[$backupJob].BackupFileExtension
    $commandList = $configFile[$backupJob].CommandList
    # Convert command list from string to array so it can be iterated through
    if ($commandList) {$cmdList = $commandList.split(",")}

    # Frequency: [Hourly,top|bottom], [Daily,<hour>,top|bottom], [Weekly,<day of week>,<hour>,top|bottom]
    $dateTime = Get-Date
    $dayOfWeek = $dateTime.DayOfWeek
    $hour = $dateTime.Hour
    $minute = $dateTime.Minute

    # If the backup job is to be run at the current day and time, this variable will be changed to $true
    $toBeRun = $false

    # Check to see if the backup job's frequency sets it to run at the current day and time
    if ($frequency -like "Hourly*") {
        if ($frequency -eq "Hourly,top") {
            if ($minute -lt 30) {$toBeRun = $true}
        }
        elseif ($frequency -eq "Hourly,bottom") {
            if ($minute -gt 30) {$toBeRun = $true}
        }
        else {Throw "Error: Valid frequency value not set for backup $name."}
    }
    elseif ($frequency -like "Daily*") {
        if ($frequency -eq "Daily,$hour,top") {
            if ($minute -lt 30) {$toBeRun = $true}
        }
        elseif ($frequency -eq "Daily,$hour,bottom") {
            if ($minute -gt 30) {$toBeRun = $true}
        }
    }
    elseif ($frequency -like "Weekly*") {
        if ($frequency -eq "Weekly,$dayOfWeek,$hour,top") {
            if ($minute -lt 30) {$toBeRun = $true}
        }
        elseif ($frequency -eq "Weekly,$dayOfWeek,$hour,bottom") {
            if ($minute -gt 30) {$toBeRun = $true}
        }
    }
    else {Throw "Error: Valid frequency value not set for backup $name."}

    if ($toBeRun) {
        Write-Output "`nBacking up $name."

        # Simulate Write-Verbose functionality (Write-Verbose doesn't output hash tables correctly)
        if ($VerbosePreference -eq "Continue") {
            $defaultTextColor = $host.ui.RawUI.ForegroundColor
            $host.ui.RawUI.ForegroundColor = "Yellow"
            Write-Output $configFile[$backupJob]
            $host.ui.RawUI.ForegroundColor = $defaultTextColor
        }

        # Define backup types and call their corresponding backup functions
        # Then, clean up their backups that are older than their retention period 
        # Based on the Type property specified in the config file
        Switch ($type)
        {
            "VM-Linux" {
                $backupFileExetnsion = "vbk"
                if ($VerbosePreference -eq "Continue") {
                    Backup-VM -vmName $name -hypervisorName $hypervisor -backupDirectory $bkDir -encryptionKeyFile $encryptionKeyFile -ProductOwnerEmail $owner -disableQuiesce:$True -Verbose
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_VM-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose    
                }
                else {
                    Backup-VM -vmName $name -hypervisorName $hypervisor -backupDirectory $bkDir -encryptionKeyFile $encryptionKeyFile -ProductOwnerEmail $owner -disableQuiesce:$True 
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_VM-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "VM-Windows" {
                $backupFileExetnsion = "vbk"
                if ($VerbosePreference -eq "Continue") {
                    Backup-VM -vmName $name -hypervisorName $hypervisor -backupDirectory $bkDir -encryptionKeyFile $encryptionKeyFile -ProductOwnerEmail $owner -Verbose
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_VM-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose    
                }
                else {
                    Backup-VM -vmName $name -hypervisorName $hypervisor -backupDirectory $bkDir -encryptionKeyFile $encryptionKeyFile -ProductOwnerEmail $owner
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_VM-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "DirectoryFull" {
                $backupFileExetnsion = "7z"
                if (!($exclude)) {$exclude = "SomethingThatisNotgoingTobinanactuallpathnameIhope!!!th!s is gh3tt0!"}
                if ($VerbosePreference -eq "Continue") {
                    Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Full -Verbose
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Network-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Full 
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Network-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "DirectoryIncremental" {
                $backupFileExetnsion = "7z"
                if (!($exclude)) {$exclude = "SomethingThatisNotgoingTobinanactuallpathnameIhope!!!th!s is gh3tt0!"}
                if ($VerbosePreference -eq "Continue") {
                    Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Incremental -Verbose
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Network-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Incremental
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Network-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "GPO" {
                if ($VerbosePreference -eq "Continue") {
                    Backup-GroupPolicy -BackupDirectory $bkDir -ProductOwnerEmail $owner -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_GPO-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -Verbose
                }
                else {
                    Backup-GroupPolicy -BackupDirectory $bkDir -ProductOwnerEmail $owner
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_GPO-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency
                }
            }
            "SSH-Full" {
                if ($VerbosePreference -eq "Continue") {
                    Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -Verbose
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_SSH-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_SSH-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "SSH-Full-SSHShellStream" {
                if ($VerbosePreference -eq "Continue") {
                    Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -SshShellStream -Verbose
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_SSH-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -SshShellStream
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_SSH-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "SSH-Incremental" {
                if ($VerbosePreference -eq "Continue") {
                    Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -Incremental -Verbose
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_SSH-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose                
                }
                else {
                    Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -Incremental
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_SSH-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "SSH-Incremental-SSHShellStream" {
                if ($VerbosePreference -eq "Continue") {
                    Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -Incremental -SshShellStream -Verbose 
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_SSH-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -Incremental -SshShellStream
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_SSH-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "MS-SQL" {
                $backupFileExetnsion = "bak"
                if ($VerbosePreference -eq "Continue") {
                    if ($userName) {
                        Backup-MSSQL -ServerAndInstance $serverInstance -Database $database -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -Verbose
                    }
                    else {
                        Backup-MSSQL -ServerAndInstance $serverInstance -Database $database -BackupDirectory $bkDir -ProductOwnerEmail $owner -Verbose
                    }
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_DB-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    if ($userName) {
                        Backup-MSSQL -ServerAndInstance $serverInstance -Database $database -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner
                    }
                    else {
                        Backup-MSSQL -ServerAndInstance $serverInstance -Database $database -BackupDirectory $bkDir -ProductOwnerEmail $owner
                    }
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion   
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_DB-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion        
                }
            }
        }   
    }
    Write-IndexPage
}

Stop-Transcript