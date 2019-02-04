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

function Test-ModuleEcho {Write-Output "Hello, world!"}
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
        Last modified: 2/4/2019
        Based on code by Vladimir Eremin (see the link section).

    .LINK
        https://www.veeam.com/blog/veeam-backup-free-edition-now-with-powershell.html

    .COMPONENT
        VeeamPSSnapin
    #>

    Param(
    [Parameter(Mandatory=$true)][string]$vmName,
    [Parameter(Mandatory=$true)][string]$hypervisorName,
    [Parameter(Mandatory=$true)][string]$backupDirectory,
    [boolean]$disableQuiesce = $false,
    [int]$compressionLevel = 5
    )

    # Add Veeam Powershell snapin
    Add-PSSnapIn VeeamPSSnapin

    # Secure password string file containing the encryption key for the backup
    $encryptionKeyFile = "C:\Repos\CyrusBackupSolution\Other\280299234"
    
    # Convert the secure password file to a Veeam encryption key
    $encryptionKey = Get-Content $encryptionKeyFile | ConvertTo-SecureString
    $encryptionKey = Add-VBREncryptionKey -Password $encryptionKey

    # Get the hypervisor Veeam object
    $hypervisor = Get-VBRServer -name $hypervisorName

    # Get the VM object and perform the backup
    $vm = Find-VBRHvEntity -Name $vmName -Server $hypervisor
    Write-Output "Performing VM backup on $($vm.Path)."
    # The Veeam job output is stored in a variable so as not to clutter the output (it's displayed if -Verbose is set)
    $backupJob = Start-VBRZip -Entity $vm -Folder $backupDirectory -Compression $CompressionLevel -DisableQuiesce:($DisableQuiesce) -EncryptionKey $encryptionKey
}
function Backup-FileShare{}
function Backup-SshAppliance{}
function Backup-GroupPolicy{}
function Backup-MSSQL {}

# Automatically delete backups as per retention policies
function Remove-Backup {}

# Manage secure storage and retieval of passwords
function Get-SecurePass {}
function New-SecurePassFile {
    <#
    .SYNOPSIS
    Creates a secure password file which can be used to retrieve the password at a later time.
    
    .DESCRIPTION
    This is a Powershell function to create a secure password file. It can be run one time to
    create a secure password that will be used in scripts that require automation.
    
    It prompts for the password to be entered and then converts it to a secure string and saves
    it to a file. It returns the path to the secure password file as a string. The file name is
    randomly generated and the directory it is located in can be either left to the default path
    defined in the script, or a directory specified with the -PwdFileDir parameter.
    
    This function must be run on the same computer and by the same user account that will run any 
    scripts that reference the secure password file.
    
    This function can be used in conjuction with Get-SecurePassword to store a secure password
    and then reference it as plain text in a script. It is useful for scripts that require both 
    automation and plain text passwords.  
    
    See Get-SecurePassword to convert the secure password file to a plain text password in scripts.
      
    .OUTPUTS
    [string] path to the secure password file.
    
    .EXAMPLE
    New-SecurePassFile.ps1
    Prompts for a password, then converts it to a secure string and saves the file to the default directory.
    
    .EXAMPLE
    New-SecurePassFile "C:\myPwds\"
    Prompts for a password, then converts it to a secure string and saves the file to the "C:\myPwds\" directory.
    
    .NOTES
    Author: Eric Claus
    Last Modified: 11/07/2017
    Based on code from Shawn Melton (@wsmelton), http://blog.wsmelton.com
    
    .LINK
    https://www.sqlshack.com/how-to-secure-your-passwords-with-powershell/
    #>

    Param(
        [string]$PwdFileDir = "C:\Scripts"
    )
    
    $PwdFile = "$PwdFileDir\$(Get-Random)"
    
    #If (Test-Path $PwdFile) {
        #New-SecurePassFile $PwdFileDir
    #}
    
    $Password = (Read-Host -Prompt "Enter the password to add to the file" -AsSecureString)
    
    ConvertFrom-SecureString -SecureString $Password | Out-File $PwdFile
    
    Write-Output $PwdFile
}

# Read in and process the config file
function Get-ConfigFile{}

# Get the histories of each backup
function Get-BackupFileHistory{}

# Automatically assign drive letters for rotating external hard drives
function Set-PartitionLetters{}

# Dynamically create HTML pages for the web dashboard
function Write-HtmlPages{}
function Write-IndexPage{}
function Write-HtmlContent{}

# Manage the TFTP server
function Start-TftpServer{}
function Stop-TftpServer{}

# Compare files for incremental backups
function Compare-Files{}

# Send alert emails upon backup failure
function Send-AlertEmail{}