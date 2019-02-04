<#
.SYNOPSIS
    Powershell module for the Cyrus Backup Solution

    .DESCRIPTION
    This module contains functions used for the Cyrus Backup Solution.

.NOTES
    Author: Eric Claus
    Last Modified: 2/4/2019

.LINK
    https://github.com/ericclaus14/CyrusBackupSolution
#>

# Import required modules
Import-Module Posh-SSH
Import-Module 7Zip4PowerShell

function Test-ModuleEcho {echo "Hello, world!"}
# Perform backups
function Backup-VM {
    <#
    .SYNOPSIS
        Backs up a VM using Veeam.    

    .DESCRIPTION
        This function uses Veeam Backup & Replication to backup virtual machines.

        Requirements:
            * Veeam Backup & Replication must be installed (the free version is fine).
            * The hypervisors (Hyper-V or a paid version of VMWare) must be added to Veeam.
            * Must have access to (ie. on the same user account and computer as) the secure password file containing the backup encryption key.

    .EXAMPLE
        Backup-VM -vmNames "Centurion1" -hypervisorName "Isaac" -backupDirectory "\\nas1\v$\VM Backups\Centurion1"
        Backs up a VM named "Centurion1" on a hypervisor named "Isaac" and saves the backup file to "\\nas1\v$\VM Backups\Centurion1".

    .EXAMPLE
        Backup-VM -vmNames "Dokuwiki1" -hypervisorName "172.17.0.96" -backupDirectory "E:\VM Backups\Dokuwiki1" -disableQuiesce $true
        Backs up a VM named "Dokuwiki1" on a hypervisor named "172.17.0.96", disable quiesce (useful for Linux guests), and saves the backup 
        file to "E:\VM Backups\Dokuwiki1". 

    .NOTES
        Author: Eric Claus
        Last modified: 2/22/2018
        Based on code by Vladimir Eremin (see the link section).

    .LINK
        https://www.veeam.com/blog/veeam-backup-free-edition-now-with-powershell.html

    .COMPONENT
        VeeamPSSnapin
    #>

    Param(
    [Parameter(Mandatory=$true)][array]$vmNames,
    [Parameter(Mandatory=$true)][string]$hypervisorName,
    [Parameter(Mandatory=$true)][string]$backupDirectory,
    [boolean]$disableQuiesce = $false,
    [int]$compressionLevel = 5
    )

    # Add Veeam Powershell snapin
    Asnp VeeamPSSnapin

    # Secure password string file containing the encryption key for the backup
    $encryptionKeyFile = "$PSScriptRoot\1539586380"
    
    # Convert the secure password file to a Veeam encryption key
    $encryptionKey = Get-Content $encryptionKeyFile | ConvertTo-SecureString
    $encryptionKey = Add-VBREncryptionKey -Password $encryptionKey

    $hypervisor = Get-VBRServer -name $hypervisorName

    foreach ($vmName in $vmNames) {
        $vm = Find-VBRHvEntity -Name $vmName -Server $hypervisor
        echo "$($vm.Path)"
        $backupJob = Start-VBRZip -Entity $vm -Folder $backupDirectory -Compression $CompressionLevel -DisableQuiesce:($DisableQuiesce) -EncryptionKey $encryptionKey
    }
}
function Backup-FileShare{}
function Backup-SshAppliance{}
function Backup-GroupPolicy{}
function Backup-MSSQL {}

# Automatically delete backups as per retention policies
function Cleanup-Backup {}

# Manage secure storage and retieval of passwords
function Get-SecurePass {}
function New-SecurePassFile {}

# Read in and process the config file
function Get-ConfigFile{}

# Get the histories of each backup
function Get-BackupFileHistory{}

# Automatically assign drive letters for rotating external hard drives
function Set-PartitionLetters{}

# Dynamically create HTML pages for the web dashboard
function Build-HtmlPages{}
function Build-IndexPage{}
function Build-HtmlContent{}

# Manage the TFTP server
function Start-TftpServer{}
function Stop-TftpServer{}

# Compare files for incremental backups
function Compare-Files{}

# Send alert emails upon backup failure
function Send-AlertEmail{}