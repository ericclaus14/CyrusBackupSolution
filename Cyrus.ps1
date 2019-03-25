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
        # Define backup types and call their corresponding backup functions
        # Then, clean up their backups that are older than their retention period 
        # Based on the Type property specified in the config file
        Switch ($type)
        {
            "VM-Linux" {
                Backup-VM -vmName $name -hypervisorName $hypervisor -backupDirectory $bkDir -encryptionKeyFile $encryptionKeyFile -ProductOwnerEmail $owner -disableQuiesce:$True 
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension "vbk"
            }
            "VM-Windows" {
                Backup-VM -vmName $name -hypervisorName $hypervisor -backupDirectory $bkDir -encryptionKeyFile $encryptionKeyFile -ProductOwnerEmail $owner
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension "vbk"
            }
            "DirectoryFull" {
                Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Full 
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension "7z"
            }
            "DirectoryIncremental" {
                Backup-Directory -BackupSource $sourcePath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Incremental
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension "7z"
            }
            "GPO" {
                Backup-GroupPolicy -BackupDirectory $bkDir -ProductOwnerEmail $owner
            }
            "SSH-Full" {
                Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
            }
            "SSH-Full-SSHShellStream" {
                Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -SshShellStream
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
            }
            "SSH-Incremental" {
                Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -Incremental
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
            }
            "SSH-Incremental-SSHShellStream" {
                Backup-SshAppliance -DeviceIPs $netPath -CommandList $cmdList -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner -Incremental -SshShellStream
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension $backupFileExetnsion
            }
            "MS-SQL" {
                if ($userName) {
                    Backup-MSSQL -ServerAndInstance $serverInstance -Database $database -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner
                }
                else {
                    Backup-MSSQL -ServerAndInstance $serverInstance -Database $database -BackupDirectory $bkDir -ProductOwnerEmail $owner
                }
                Remove-Backups -BackupName $name -DaysOldToKeep $retention -BackupFolder $bkDir -Extension "bak"           
            }
        }
    }
}