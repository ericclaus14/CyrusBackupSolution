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

function Test-ModuleEcho {
    [CmdletBinding()]
    
    Param(
    [Parameter(Mandatory=$true)]
        [string]$vmName
    )

    Write-Verbose $vmName
}
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
        Backup-VM -vmName "Centurion1" -hypervisorName "Isaac" -backupDirectory "\\nas1\v$\VM Backups\Centurion1" -encryptionKeyFile "C:\keys\vmEncryption.txt"
        Backs up a VM named "Centurion1" on a hypervisor named "Isaac" and saves the backup file to "\\nas1\v$\VM Backups\Centurion1".

    .EXAMPLE
        Backup-VM -vmName "Dokuwiki1" -hypervisorName "172.17.0.96" -backupDirectory "E:\VM Backups\Dokuwiki1" -encryptionKeyFile "C:\Scripts\securePassFiles\vmEncryption.txt -disableQuiesce $true
        Backs up a VM named "Dokuwiki1" on a hypervisor named "172.17.0.96", disable quiesce (useful for Linux guests), and saves the backup 
        file to "E:\VM Backups\Dokuwiki1". 

    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/11/2019
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
    #$encryptionKeyFile = "C:\Repos\CyrusBackupSolution\Other\280299234"
    
    # Convert the secure password file to a Veeam encryption key
    $encryptionKey = Get-Content $encryptionKeyFile | ConvertTo-SecureString
    $encryptionKey = Add-VBREncryptionKey -Password $encryptionKey

    # Get the hypervisor Veeam object
    $hypervisor = Get-VBRServer -name $hypervisorName

    # Get the VM object and perform the backup
    Write-Verbose "Getting the VM as a VBRHvEntity object."
    $vm = Find-VBRHvEntity -Name $vmName -Server $hypervisor
    # The Veeam job output is stored in a variable so as not to clutter the output (it's displayed if -Verbose is set)
    $backupJob = Start-VBRZip -Entity $vm -Folder $backupDirectory -Compression $CompressionLevel -DisableQuiesce:($DisableQuiesce) -EncryptionKey $encryptionKey
    Write-Output "Completed VM backup on $($vm.Path)."
    
    Remove-Variable backupJob, vm, hypervisor, encryptionKey, encryptionKeyFile, backupDirectory, hypervisorName
}
function Backup-Directory{
    <#
    .SYNOPSIS
        Performs Full or Incremental backups on the NAS.    

    .DESCRIPTION
        This function uses the 7Zip4PowerShell module to compress, encrypt, and backup the file shares on NAS1.
        All folders inside of the NASShare folder on NAS1 are backed up.

        When an incremental backup is performed, only files modifed since the last backup was completed will be backed up. If no 
        files have been modied since the last backup, an error will occur. The backup name (specified with the -Name parameter) 
        MUST be the same everytime you perform a backup in order for the previous backup to be found.
        
        Requirements:
            * Must have access to (ie. on the same user account and computer as) the secure password file containing the backup encryption key.

    .EXAMPLE
        Backup-Directory -BackupSource "C:\myfiles\dirToBeBackedUp" -BackupDestinationDir "C:\Backup\myfiles" -Name "My Files" -Type Full -EncryptionKey "C:\Repos\CyrusBackupSolution\Other\SecurePasswordFiles\dirEncryption"
        Perform a full backup of "C:\myfiles\dirToBeBackedUp"

    .EXAMPLE
        Backup-Directory -BackupSource "\\filesvr\NetworkShare" -BackupDestinationDir "C:\Backup" -Name "Network Share" -Type Incremental -EncryptionKey "C:\Repos\CyrusBackupSolution\Other\SecurePasswordFiles\dirEncryption" -Exclude "\\*.txt|\\git"
        Perform an incremental backup of "\\filesvr\NetworkShare" and exclude any files or folders with a .txt file type or with "git" in the path name.

    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/11/2019
        Thanks to Thomas Freudenberg for his module and his help with getting the incremental backup to work.

    .LINK
        https://github.com/thoemmi/7Zip4Powershell

    .COMPONENT
        7Zip4PowerShell
    #>

    #Requires –Modules 7Zip4PowerShell
    #Uncomment line below to install the module
    #Install-Module -Name 7Zip4PowerShell

    [CmdletBinding()]

    Param(
        # What is being backed up
        [Parameter(Mandatory=$true)]
            # Thanks to Graham Gold for this line https://stackoverflow.com/a/29956099
            [ValidateScript({Test-Path $_})] 
            [string]$BackupSource,
        
        # Folder the backup file will reside in
        [Parameter(Mandatory=$true)]
            [ValidateScript({Test-Path $_})] 
            [string]$BackupDestinationDir,

        # What to name the backup file (will have -<FULL|INCREMENTAL>-<date>.7z added to the end of it)
        [Parameter(Mandatory=$true)]
            [string]$Name,

        [Parameter(Mandatory=$true)]
            [ValidateSet("Full", "Incremental")]
            [string]$Type,

        # Secure password file containing the encryption key for the backup
        [ValidateScript({Test-Path $_ -PathType 'leaf'})]
            [string]$EncryptionKey,

        # Files/folders to exclude from being backed up, regular expression
        [string]$Exclude = "SomethingThatisNotgoingTobinanactuallpathnameIhope!!!!!",

        # What compression level to use
        [ValidateSet("Ultra", "High", "Fast", "Low", "None", "Normal")]
            [string]$compressionLevel = "Fast"
    )
    
    $date = Get-Date -Format MM-dd-yyyy-HHmm
    
    # Get the password to encrypt the backup with
    $backupZipPassword = (Get-SecurePass -PwdFile $EncryptionKey).Password
    
    Write-Verbose "Encryption password retrieved. Starting backup."

    if ($Type -eq "Incremental") {
        
        Write-Output "Incremental backup selected."

        $backupLog = "$BackupDestinationDir\$Name-INCREMENTAL-BackupLog-$date.txt"
        
        # Get the creation time of the most recent backup
        $lastWrite = (Get-ChildItem -Path $BackupDestinationDir -Filter "$Name-*").CreationTime | Sort-Object | Select-Object -Last 1
        Write-Output "Backing up files modifed since: $lastWrite"
    
        $destinationFile = "$BackupDestinationDir\$Name-INCREMENTAL-$date.7z"
        
        Write-Verbose "Backup log=$backupLog; Most recent backup=$lastWrite; Backup file=$destinationFile"

        Get-ChildItem $BackupSource -Recurse -File |              # Get a list of files in the backup source folder
            Where-Object {$_.FullName -notmatch $exclude} | # Filter out the items listed in the exclude list above
            Where-Object {$_.LastWriteTime -ge $LastWrite} |     # Only get the files that have been modified since the last backup
            ForEach-Object {$_.FullName} |                               # Get their full path names
            Compress-7Zip -Format SevenZip -ArchiveFileName $destinationFile -SecurePassword $backupZipPassword -CompressionLevel $compressionLevel
        
        Write-Output "Incremental backup complete."
    }
    elseif ($Type -eq "Full") {
        Write-Output "Full backup selected."
        
        $backupLog = "$BackupDestinationDir\$Name-FULL-BackupLog-$date.txt"
        
        $destinationFile = "$BackupDestinationDir\$Name-FULL-$date.7z"
        
        Write-Verbose "Backup log=$backupLog; Backup file=$destinationFile"

        Get-ChildItem $BackupSource -Recurse -File |              # Get a list of files in the backup source folder
            Where-Object {$_.FullName -notmatch $exclude} | # Filter out the items listed in the exclude list above
            ForEach-Object {$_.FullName} |                               # Get their full path names
            Compress-7Zip -Format SevenZip -ArchiveFileName $destinationFile -SecurePassword $backupZipPassword -CompressionLevel $compressionLevel
        
        # Delete any previous incremental backups (restart incremental backups every time a full backup is run)
        Remove-Item -Path "$BackupDestinationDir\*" -Filter "*INCREMENTAL*"

        Write-Output "Full backup complete."
    }
    
    Write-Verbose "Getting list of items backed up (ie. all items in the backup zip file)."
    # Get a list of items in the new backup file (files that were backed up) and send the list to the backup log
    (Get-7Zip -ArchiveFileName $destinationFile).FileName | Out-File $backupLog -Append

    Write-Output "Directory backup of $backupSource complete."
}
function Backup-SshAppliance{
    [CmdletBinding()]

    Param(
        # IP, or list of IPs, to perform the backup on
        [Parameter(Mandatory=$true)]
            [string[]]$DeviceIPs,

        # Array of commands to be run via SSH on remote device
        [Parameter(Mandatory=$true)]
            [string[]]$CommandList,

        # Directory to store the backups
        [Parameter(Mandatory=$true)]
            [ValidateScript({Test-Path $_})]
            [string]$BackupDirectory,

        # Directory to store the logs
        [ValidateScript({Test-Path $_})]
            [string]$LogDirectory = "$BackupDirectory\Logs",

        # Username to SSH with
        [Parameter(Mandatory=$true)]
            [string]$Username,
    
        # Secure password file containing the password for the above user
        [Parameter(Mandatory=$true)]
            [ValidateScript({Test-Path $_ -PathType 'leaf'})] 
            [string]$SecurePasswordFile,

        # Is this an incremental backup that will use Compate-Files to only perform
        # the backup if there has been a change? 
        # ONLY WORKS FOR BACKUPS THAT CONSIST OF ONLY ONE FILE.
        # ONLY WORKS IF TFTP IS BEING USED.
        [switch]$Incremental,

        # Does this SSH appliance require an SSH Shell Stream?
        [switch]$SshShellStream,

        # Time to wait (sleep) in seconds between sending commands to the Shell Stream
        [int]$CommandWaitTime = 10
    )


    #Requires -Modules Posh-SSH
    . C:\Scripts\Cyrus-Backup-Client\Other\Get-SecurePassword.ps1
    . C:\Scripts\Cyrus-Backup-Client\Other\Compare-Files.ps1

    ########## Begin Error Handling ##########
    ########## End Error Handling ##########


    $date = (Get-Date).ToString("MMddyyHHmm")

    $credentials = Get-SecurePassword -PwdFile $SecurePasswordFile -userName $Username

    # TFTP root directory. For SolarWinds: C:\TFTP-Root
    $tftpRoot = "C:\TFTP-Root"

    # Start SolarWinds TFTP Server and enable firewall rule
    Start-TftpServer

    # Loop through each device
    foreach ($IP in $DeviceIPs) {
        Write-Output "Backing up $IP..."

        $log = "$LogDirectory\$IP.log"
        Write-Output "-----------------------------------------------------------" | Out-File -Append $log
        Write-Output "-----------------------------------------------------------" | Out-File -Append $log
        Write-Output "Date: $date" | Out-File -Append $log

        # Set, and if needed create, the device's backup directory
        $deviceBackupDir = "$BackupDirectory\$IP"
        if (!(Test-Path $deviceBackupDir)) {
            New-Item $deviceBackupDir -ItemType Directory | Out-Null
        }

        # Create a new SSH session
        $session = New-SSHSession -ComputerName $IP -Credential $credentials -AcceptKey:$True

        if ($SshShellStream) {
            # Initiate an SSH Shell Stream
            $shellStream = New-SSHShellStream -SSHSession $session

            # Send a space to get past possible "Press any key to continue" screen (could be any key)
            $shellStream.WriteLine(" ")
            Start-Sleep 5

            # Loop through the list of commands and execute them through the SSH session
            foreach ($cmd in $CommandList) {
                $shellStream.WriteLine($cmd)
                Start-Sleep $CommandWaitTime
            }
        }
        else {
            # Loop through the list of commands and execute them through the SSH session
            foreach ($cmd in $CommandList) {
                Invoke-SSHCommand -Command $cmd -SSHSession $session
            }
        }

        # Close the SSH session
        Remove-SSHSession -SSHSession $session

        # Get the name of the new backup file
        $newFileName = (Get-ChildItem $tftpRoot | Sort-Object LastWriteTime | Select-Object -Last 1)
        Rename-Item $($newFileName.FullName) -NewName "$date-$($newFileName.Name)"
        $newFileName = (Get-ChildItem $tftpRoot | Sort-Object LastWriteTime | Select-Object -Last 1).FullName


        if ($Incremental) {
            Write-Verbose "Beginning incremental (Compare-Files) portion..."
        
            Write-Output "Type: Incremental." | Out-File -Append $log

            # Get the name of the most recent copy of the device's backup file
            $oldFileName = (Get-ChildItem "$deviceBackupDir" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
        
            Write-Verbose "Old file: $oldFileName; new file: $newFileName"

            # Check to see if there has been a change to the device since last backup
            # If so, store the changed lines in $compareResults
            $compareResults = Compare-Files $oldFileName $newFileName

            # If there has been a change to the backup file 
            If ($compareResults) {
                # Move the backup file to the backup directory
                Move-Item $newFileName $deviceBackupDir

                # Write the backup file's changes (the results of Compare-Files) to the change log
                Write-Output $compareResults | Out-File $log -Append
            }

            # If there has not been a change to the config
            Else {
                # Delete the newly created backup file
                Remove-Item $newFileName
                Write-Output "Device $IP has not been backed up. No change has been detected." | Tee-Object -filepath $log #Out-File -Append $log
            }
        }
        else {
            Write-Verbose "Incremental switch not set, moving new backup file to backup directory."
        
            Write-Output "Type: Full." | Out-File -Append $log

            Write-Verbose "Newly created file name: $newFileName"

            # Move the backup file to the backup directory
            Move-Item $newFileName $deviceBackupDir
        }

        Write-Output "Backup of $IP is complete - $date." | Tee-Object -Append $log
    }

    # Stop SolarWinds TFTP Server and disable firewall rule
    Stop-TftpServer

}
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
        Last Modified: 2/13/2019

    .LINK
        https://gallery.technet.microsoft.com/scriptcenter/Incremental-GPO-Backup-ccc0856f

    .COMPONENT
        RSAT, PS module grouppolicy
    #>

    [CmdletBinding()]

    Param(
        # Where to store the backups
        [Parameter(Mandatory=$true)]
            [ValidateScript({Test-Path $_})]
            [string]$BackupDirectory,
    
        # Where is the log file to be stored?
        [ValidateScript({Test-Path $_})] 
            [string]$LogDirectory = "$BackupDirectory\Logs"
    )

    Write-Output "Begennning Group Policy backup..."

    $date = Get-Date -Format MM-dd-yyyy-HHmm

    $log = "$LogDirectory\GPO-BackupLog-$date.log"
    
    Write-Output $date | Out-File $log
      
    Write-Verbose "Importing grouppolicy module."
    # Import required module
    Import-Module grouppolicy

    # Get all GPOs and loop through them
    Foreach ($GPO in $(Get-GPO -All)) {
        $name = $GPO.DisplayName
        $lastModified = $GPO.ModificationTime
    
        # Set the path to the backup directory, named for the GPO and it's modification date
        $path = "$BackupDirectory\Backups\$name\$lastModified"
        
        # GPO name and last modified date might include chatacters not legal in a file path
        $path = $path -replace ':','-'
        $path = $path -replace 'C-','C:'
        $path = $path -replace '/','-'
        $path = $path -replace ' ','_'
    
        Write-Verbose "GPO name=$name; Last modified=$lastModified; Backup path=$path."

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