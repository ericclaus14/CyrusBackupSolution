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
    # Properties common to all backup types
    $name = $configFile[$backupJob].Name
    $type = $configFile[$backupJob].Type
    $frequency = $configFile[$backupJob].Frequency
    $retention = $configFile[$backupJob].Retention
    $bkDir = $configFile[$backupJob].BkDir
    $owner = $configFile[$backupJob].Owner

    # Properties not common to all backup types
    $hypervisor = $configFile[$backupJob].Host
    $netPath = $configFile[$backupJob].NetPath
    $serverInstance = $configFile[$backupJob].ServerInstance
    $database = $configFile[$backupJob].Database

    # Define backup types and call their corresponding backup functions 
    # Based on the Type property specified in the config file
    Switch ($type)
    {
        "VM-Linux" {
            Backup-VM -vmName $name -hypervisorName $hypervisor -backupDirectory $bkDir -encryptionKeyFile $encryptionKeyFile -ProductOwnerEmail $owner -disableQuiesce:$True 
        }
        "VM-Windows" {
            Backup-VM -vmName $name -hypervisorName $hypervisor -backupDirectory $bkDir -encryptionKeyFile $encryptionKeyFile -ProductOwnerEmail $owner
        }
        "DirectoryFull" {
            Backup-Directory -BackupSource $netPath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Full 
        }
        "DirectoryIncremental" {
            Backup-Directory -BackupSource $netPath -BackupDestinationDir $bkDir -Name $name -EncryptionKey $encryptionKeyFile -Exclude $exclude -ProductOwnerEmail $owner -Type Incremental
        }
        "GPO" {
            Backup-GroupPolicy -BackupDirectory $bkDir -ProductOwnerEmail $owner
        }
        "SSH-Full" {
            Backup-SshAppliance -DeviceIPs $netPath -CommandList $commands -BackupDirectory $bkDir -Username $userName -SecurePasswordFile = $passwordFile -ProductOwnerEmail $owner
        }
        "SSH-Full-SSHShellStream" {
            Backup-SshAppliance -DeviceIPs $netPath -CommandList $commands -BackupDirectory $bkDir -Username $userName -SecurePasswordFile = $passwordFile -ProductOwnerEmail $owner -SshShellStream
        }
        "SSH-Incremental" {
            Backup-SshAppliance -DeviceIPs $netPath -CommandList $commands -BackupDirectory $bkDir -Username $userName -SecurePasswordFile = $passwordFile -ProductOwnerEmail $owner -Incremental
        }
        "SSH-Incremental-SSHShellStream" {
            Backup-SshAppliance -DeviceIPs $netPath -CommandList $commands -BackupDirectory $bkDir -Username $userName -SecurePasswordFile = $passwordFile -ProductOwnerEmail $owner -Incremental -SshShellStream
        }
        "MS-SQL" {
            Backup-MSSQL -ServerAndInstance $serverInstance -Database $database -BackupDirectory $bkDir -Username $userName -SecurePasswordFile $passwordFile -ProductOwnerEmail $owner
        }
    }


}