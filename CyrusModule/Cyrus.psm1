<#
.SYNOPSIS
    Powershell module for the Cyrus Backup Solution

    .DESCRIPTION
    This module contains functions used for the Cyrus Backup Solution.

.NOTES
    Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
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
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/4/2019
        Based on code by Vladimir Eremin (see the link section).

    .LINK
        https://www.veeam.com/blog/veeam-backup-free-edition-now-with-powershell.html

    .COMPONENT
        VeeamPSSnapin
    #>

    [CmdletBinding()]
    
    Param(
    [Parameter(Mandatory=$true)]
        [string]$vmName,
    [Parameter(Mandatory=$true)]
        [string]$hypervisorName,
    [Parameter(Mandatory=$true)]
        [string]$backupDirectory,
    [Parameter(Mandatory=$true)]
        # Thanks to Graham Gold for this line https://stackoverflow.com/a/29956099
        [ValidateScript({Test-Path $_ -PathType 'leaf'})] 
        [string]$encryptionKeyFile,
    [boolean]$disableQuiesce = $false,
    [ValidateSet(0, 4, 5, 6, 9)]
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
    
    Write-Verbose $backupJob
    
    Remove-Variable $backupJob, $vm, $hypervisor, $encryptionKey, $encryptionKeyFile, $backupDirectory, $hypervisorName
}
function Backup-FileShare{
    <#
    .SYNOPSIS
        Performs Full or Incremental backups on the NAS.    

    .DESCRIPTION
        This function uses the 7Zip4PowerShell module to compress, encrypt, and backup the file shares on NAS1.
        All folders inside of the NASShare folder on NAS1 are backed up.

        When an incremental backup is performed, only files modifed since the last backup was completed will be backed up.
        
        Requirements:
            * Must have access to (ie. on the same user account and computer as) the secure password file containing the backup encryption key.

    .EXAMPLE
        Backup-FileShare -Type Full
        Perform a full backup of the file shares on NAS1

    .EXAMPLE
        Backup-FileShare -Type Incremental
        Perform an incremental backup of the file shares on NAS1 

    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/6/2019
        Thanks to Thomas Freudenberg for his module and his help with getting the incremental backup to work.

    .LINK
        https://github.com/thoemmi/7Zip4Powershell

    .COMPONENT
        7Zip4PowerShell
    #>

    #Requires –Modules 7Zip4PowerShell
    #Uncomment line below to install the module
    #Install-Module -Name 7Zip4PowerShell

    Param(
        [Parameter(Mandatory=$true)]
            # Thanks to Graham Gold for this line https://stackoverflow.com/a/29956099
            [ValidateScript({Test-Path $_ -PathType 'leaf'})] 
            [string]$directoryPath,
        
        [Parameter(Mandatory=$true)]
            [ValidateSet("Full", "Incremental")]
            [string]$Type
    )
    
    $date = Get-Date -Format MM-dd-yyyy-HHmm
    
    # Include the neccasary functions
    $myFunctions = @(
        "$PSScriptRoot\Get-SecurePassword.ps1"
        )
    $myFunctions | ForEach-Object {
        If (Test-Path $_) {. $_}
        Else {throw "Error: At least one necessary function was not found."; Exit 99}
    }

    # Folder the backup file will reside in (make it if it doesn't exist)
    $destination = "Z:\Cyrus\NASShare"
    if (!(Test-Path $destination)) {mkdir $destination}

    # Create a PSCredential object with the password for the domain backup VLAN admin account
    $securePassFile = "$PSScriptRoot\130294490"
    $userName = "ad\Cyrus"
    $creds = Get-SecurePassword -PwdFile $securePassFile -userName $userName
    
    # What is being backed up
    $backupSource = "\\192.168.90.92\d$\NASShare"
    
    # Create a temporary mapped drive, connecting to the backup source folder with the credentials from above
    Remove-PSDrive -Name "tempSource" -ErrorAction SilentlyContinue
    New-PSDrive -Name "tempSource" -PSProvider FileSystem -Root $backupSource -Credential $creds
    $source = "tempSource:\"
    
    # Files/folders to exclude from being backed up, regular expression
    $exclude = "\\home\\mlavertue|\\ICE_INS\\|\\Overall Desktop A\\Corsair\\|\\yearbook\\backup 2017|\\yearbook\\backup 2016|\\CONERLKE\\conerlke\\Google Drive\\|conerlke\\Documents\\Documents 10.26.12\\|\\Backpup files from Julian|02-04-18.tar.gz|\\djernesd.AD\\AppData|\\djernesd\\AppData|\\jancion\\Djernes Drive\\|\\djernesd1.old\\"
    
    # Get the password to encrypt the backup with
    $nasBackupZipPassword = (Get-SecurePassword -PwdFile "$PSScriptRoot\455799013").Password
    
    # What compression level to use, options are: Ultra, High, Fast, Low, None, and Normal
    $compressionLevel = "Fast"
    
    if ($Type -eq "Incremental") {
        $backupLog = "$destination\BackupLog-INCREMENTAL-$date.txt"
        
        # Get the creation time of the most recent backup
        $lastWrite = (Get-ChildItem -Path $destination -Filter "NASShare-*").CreationTime | Sort | Select -Last 1
        echo "Backing up files modifed since: $lastWrite"
    
        $destinationFile = "$destination\NASShare-INCREMENTAL-$date.7z"
        
        Get-ChildItem $source -Recurse -File |              # Get a list of files in the backup source folder
            Where-Object {$_.FullName -notmatch $exclude} | # Filter out the items listed in the exclude list above
            Where {$_.LastWriteTime -ge "$LastWrite"} |     # Only get the files that have been modified since the last backup
            % {$_.FullName} |                               # Get their full path names
            Compress-7Zip -Format SevenZip -ArchiveFileName $destinationFile -SecurePassword $nasBackupZipPassword -CompressionLevel $compressionLevel
    }
    elseif ($Type -eq "Full") {
        $backupLog = "$destination\BackupLog-FULL-$date.txt"
        
        $destinationFile = "$destination\NASShare-FULL-$date.7z"
    
        Get-ChildItem $source -Recurse -File |              # Get a list of files in the backup source folder
            Where-Object {$_.FullName -notmatch $exclude} | # Filter out the items listed in the exclude list above
            % {$_.FullName} |                               # Get their full path names
            Compress-7Zip -Format SevenZip -ArchiveFileName $destinationFile -SecurePassword $nasBackupZipPassword -CompressionLevel $compressionLevel
        
        # Delete any previous incremental backups (restart incremental backups every time a full backup is run)
        Remove-Item -Path "$destination\*" -Filter "*INCREMENTAL*"
    }

    # Get a list of items in the new backup file (files that were backed up) and send the list to the backup log
    (Get-7Zip -ArchiveFileName $destinationFile).FileName | Out-File $backupLog -Append
    
    # The drive created should be removed once the Powershell session ends, however, this makes sure it goes away
    Remove-PSDrive -Name "tempSource" -ErrorAction SilentlyContinue
}
function Backup-SshAppliance{}
function Backup-GroupPolicy{
    <#
    .SYNOPSIS
        This is a Powershell script to automatically backup all GPOs.

    .DESCRIPTION
        This script can be used to automate the backup of all group policy objects.
        It performs an incremental backup and only backs up GPOs that have been
        modified since their last backup. 

        The Group Policy Management feature (or Remote Server Administration Tools, 
        RSAT, if on Windows 10 and not Server 2016) needs to be installed in order
        for the grouppolicy module, needed by this script, to import.

        Thanks to Matt Browne, MattB101, for his script named GPO_Backup.ps1. 
        The incremental backup part of this script is based upon his script.
        The link to his script is in the LINK section.

    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last Modified: 2/4/2019

    .LINK
        https://gallery.technet.microsoft.com/scriptcenter/Incremental-GPO-Backup-ccc0856f

    .COMPONENT
        RSAT, PS module grouppolicy
    #>

    $date = Get-Date -Format d | ForEach-Object {$_ -replace "/", "-"}
    $log = "\\nas1\d$\NASShare\dr\GPO\Logs\Backuplog-$date.log"
    Write-Output $date | Out-File $log
      
    # Import required module
    Import-Module grouppolicy

    # Get all GPOs and loop through them
    Foreach ($GPO in $(Get-GPO -All)) {
        $name = $GPO.DisplayName
        $lastModified = $GPO.ModificationTime
    
        # Set the path to the backup directory, named for the GPO and it's modification date
        $path = "\\nas1\d$\NASShare\dr\GPO\Incremental\$name\$lastModified"
        $path = $path -replace ':','-'
        $path = $path -replace '/','-'
        $path = $path -replace ' ','_'
    
        # Check if the GPO has been modified since it was last backed up by
        # checking to see if there is already a backup folder by the same name.
        If (!(Test-Path $path)) {
            mkdir $path
            Backup-GPO -Name $name -Path $path
            Write-Output ("{0} has been backed up." -f $name.PadRight(40,"-")) | Tee-Object -FilePath $log -Append
        }
        Else {Write-Output ("{0} not backed up." -f $name.PadRight(40,"-")) | Tee-Object -FilePath $log -Append}
    }
}
function Backup-MSSQL {}

# Automatically delete backups as per retention policies
function Remove-Backup {}

# Manage secure storage and retieval of passwords
function Get-SecurePass {
        <#
    .SYNOPSIS
    Retrieves a password from a secure password file and creates a PSCredential object.

    .DESCRIPTION
    This is a Powershell function to retrieve a password from a secure password file and
    create a PSCredential object. It is used in conjunction with files created using 
    ConvertFrom-SecureString (I recommend using New-SecurePassFile).
    
    You can optionally supply a username to include in the PSCredential object.

    This function must be run on the same computer and by the same user account that were
    used to create the secure password file. 

    A plain text password can be gotten from a secure password file by running:
        (Get-SecurePassword $encryptionKeyFile).GetNetworkCredential().Password

    See New-SecurePassFile to create a new secure password file.

    .OUTPUTS
    [PSCredential] or [string]

    .EXAMPLE
    Get-SecurePassword "C:\Scripts\837839423"
    Returns a PSCredential object made from the password in "C:\Scripts\837839423".

    .EXAMPLE
    $creds = Get-SecurePassword -PwdFile "\\svr\pwds\password.txt" -userName "Eric Claus"
    Sets $creds to a PSCredential object made from the password in "\\svr\pwds\password.txt"
    and the username "Eric Claus".

    .EXAMPLE
    (Get-SecurePassword "C:\path\to\file").GetNetworkCredential().Password
    Converts a secure password in "C:\path\to\file" to plain text.

    .NOTES
    Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
    Last Modified: 2/6/2019
    Based on code from Shawn Melton (@wsmelton), http://blog.wsmelton.com

    .LINK
    https://www.sqlshack.com/how-to-secure-your-passwords-with-powershell/
    #>

    Param(
    [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType 'leaf'})]
        [string]$PwdFile,
    [string]$userName="tempPlaceHolder"
    )

    $ErrorActionPreference = "Stop"

    Try {
        $pwd = Get-Content $PwdFile | ConvertTo-SecureString
    }
    Catch [System.Security.Cryptography.CryptographicException] {
        Throw "Error: The secure password file needs to be created by the same user and on the same computer as this script is being run."
        Exit 5
    }

    $mycred = New-Object System.Management.Automation.PSCredential($userName,$pwd)

    $mycred

    Remove-Variable userName,PwdFile,pwd,mycred
}
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