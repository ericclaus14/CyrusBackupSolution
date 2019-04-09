<#
.SYNOPSIS
    Core Powershell script for the Cyrus Backup Solution

.DESCRIPTION
    This script ties together the config file and Powershell module for the Cyrus Backup Solution.

.NOTES
    Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
    Last Modified: 4/4/2019
    Licensed under GNU General Public License v3 (GPL-3)

.LINK
    https://github.com/ericclaus14/CyrusBackupSolution
#>

# This is here so that default parameters, such as -Verbose, can be recognized by this script
[CmdletBinding()]
Param()

##### CHANGE BELOW WHEN INSTALLING CYRUS BACKUP SOLUTION ON A NEW SERVER #####
# Where Cyrus Backup Solution is installed
$CBSRootDirectory = "C:\Repos\CyrusBackupSolution"
##### CHANGE ABOVE WHEN INSTALLING CYRUS BACKUP SOLUTION ON A NEW SERVER #####

$date = Get-Date -Format MM-dd-yyyy-HHmm
Start-Transcript -Path "$CBSRootDirectory\Transcripts\$date.transcript"

# Get date and time information which will be compared to each backup job's frequency to determine if the job should be run or not
# Frequency syntax in config file: [Hourly,top|bottom], [Daily,<hour>,top|bottom], [Weekly,<day of week>,<hour>,top|bottom]
$dateTime = Get-Date
$dayOfWeek = $dateTime.DayOfWeek
$hour = $dateTime.Hour
$minute = $dateTime.Minute

# Read in config file to variable. This will output a hash table of hash tables
$configFile = Get-IniContent -FilePath "$CBSRootDirectory\Cyrus-Config.ini"

# Loop through each backup job (sub-hash table) defined inside of the config file
foreach ($backupJob in $configFile.Keys) {
    # All the comments in the config file get lumped together into their own sub-hash table
    # Skip this sub-has table
    if ($backupJob -eq "No-Section") {Continue}

    #### Backup Job Properties ####
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

    ####################################################################################################
    ########### Add Additional Properties Here #########################################################

    ####################################################################################################
    ####################################################################################################

    #### End Backup Job Properties Section ####

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
        Write-Output "`n--------------------------------"
        Write-Output "`nBacking up $name, $type."

        # Simulate Write-Verbose functionality (Write-Verbose doesn't output hash tables correctly)
        if ($VerbosePreference -eq "Continue") {
            $defaultTextColor = $host.ui.RawUI.ForegroundColor
            $host.ui.RawUI.ForegroundColor = "Yellow"
            Write-Output $configFile[$backupJob]
            $host.ui.RawUI.ForegroundColor = $defaultTextColor
        }

        #### Backup Job Types ####
        # Define backup types and call their corresponding backup functions
        # Then, clean up their backups that are older than their retention period 
        # Based on the Type property specified in the config file
        # If you want to define a new backup type, add it as an option to this switch statement
        # and call the necessary functions.
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
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Dir-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Full 
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Dir-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            "DirectoryIncremental" {
                $backupFileExetnsion = "7z"
                if (!($exclude)) {$exclude = "SomethingThatisNotgoingTobinanactuallpathnameIhope!!!th!s is gh3tt0!"}
                if ($VerbosePreference -eq "Continue") {
                    Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Incremental -Verbose
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Dir-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Incremental
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Dir-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
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
            ####################################################################################################
            ########### Add Additional Backup Types Here #######################################################
            "<INSERT NEW TYPE HERE>" {
                if ($VerbosePreference -eq "Continue") {
                    # CALL BACKUP FUNCTION HERE

                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion -Verbose
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Custom-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion -Verbose
                }
                else {
                    # CALL BACKUP FUNCTION HERE
                    
                    Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion   
                    Write-HtmlPage -BackupDirPath $bkDir -HtmlFileName "History_Custom-$name.html" -HtmlPageTitle "$name Backup History" -Frequency $frequency -FileExtensionWithoutPeriod $backupFileExetnsion
                }
            }
            ####################################################################################################
            ####################################################################################################
        }   
        #### End Backup Job Types Section ####
    }
    # Generate the index (home) page of the web dashboard
    Write-IndexPage
}
Write-Output "`n"
Stop-Transcript