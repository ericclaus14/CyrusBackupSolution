<#
.SYNOPSIS
    Powershell module for the Cyrus Backup Solution

    .DESCRIPTION
    This module contains functions used for the Cyrus Backup Solution.

.NOTES
    Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
    Last Modified: 4/4/2019
    Licensed under GNU General Public License v3 (GPL-3)

.LINK
    https://github.com/ericclaus14/CyrusBackupSolution
#>

# Import required modules
Import-Module Posh-SSH
Import-Module 7Zip4PowerShell

# Configurable variables used by functions below. Change these to the correct values when implemented in a new environment

##### CHANGE BELOW WHEN INSTALLING CYRUS BACKUP SOLUTION ON A NEW SERVER #####
$CBSRootDirectory = "C:\CyrusBackupSolution"
$HelpDeskEmail = "help@domain.com"
##### CHANGE ABOVE WHEN INSTALLING CYRUS BACKUP SOLUTION ON A NEW SERVER #####

$WebDashboardRootDirectory = "$CBSRootDirectory\Dashboard"

# Thanks to Trevor Sullivan for this regular expression!
# https://stackoverflow.com/a/48253796
$ValidEmailAddress = '^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$'

# Send alert emails upon backup failure
function Send-AlertEmail{
    Param(
        [Parameter(Mandatory=$true)]
            [string]$ItemBeingBackedUpName,
    
        [string]$ProductOwnerEmail 
    )

    Write-Output $_

    # Send an email to the help desk and to the product owner with the error
    # Thanks to https://www.pdq.com/blog/powershell-send-mailmessage-gmail/ for the bulk of the code below. 
    $From = "fortigate-log@collegedaleacademy.com"
    $To = @($HelpDeskEmail)
    if ($ProductOwnerEmail) {$To += $ProductOwnerEmail}
    $Subject = "$ItemBeingBackedUpName Backup Error"
    $Body = "There has been an error with the automatic backup of $ItemBeingBackedUpName. -- $_"
    $SMTPServer = "aspmx.l.google.com"
    $SMTPPort = "25"
    Send-MailMessage -From $From -to $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -port $SMTPPort -UseSsl
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
        [int]$compressionLevel = 5,
    
    [validatescript({$_ -match $ValidEmailAddress})]
        [string]$ProductOwnerEmail
    
    )

    # Add Veeam Powershell snapin
    Add-PSSnapIn VeeamPSSnapin

    ########## Begin Error Handling ##########
    # Thanks to Keith Hill for this trap idea.
    # https://stackoverflow.com/questions/14246512/send-an-email-if-a-powershell-script-gets-any-errors-at-all-and-terminate-the-sc
    # If any terminating error occurs, invoke the Send-AlertEmail function and stop the script
    trap {Send-AlertEmail -ItemBeingBackedUpName "$vmName-VM" -ProductOwnerEmail $ProductOwnerEmail; Exit 1}
    # Treat all errors as terminating, useful for the trap statement above
    $ErrorActionPreference = "Stop"
    ########## End Error Handling ##########
    
    if (!(Test-Path $backupDirectory)) {mkdir $backupDirectory}
    if (!(Test-Path "$backupDirectory\Logs")) {mkdir "$backupDirectory\Logs"}

    # Convert the secure password file to a Veeam encryption key
    $encryptionKey = Get-Content $encryptionKeyFile | ConvertTo-SecureString
    $encryptionKey = Add-VBREncryptionKey -Password $encryptionKey

    # Get the hypervisor Veeam object
    $hypervisor = Get-VBRServer -name $hypervisorName

    # Get the VM object and perform the backup
    Write-Verbose "Getting the VM as a VBRHvEntity object."
    $vm = Find-VBRHvEntity -Name $vmName -Server $hypervisor
    # The Veeam job output is stored in a variable so as not to clutter the output (comment out this line and uncomment the below line to display the output
    #$backupJob = Start-VBRZip -Entity $vm -Folder $backupDirectory -Compression $CompressionLevel -DisableQuiesce:($DisableQuiesce) -EncryptionKey $encryptionKey
    Start-VBRZip -Entity $vm -Folder $backupDirectory -Compression $CompressionLevel -DisableQuiesce:($DisableQuiesce) -EncryptionKey $encryptionKey | Out-Null
    Write-Output "Completed VM backup on $($vm.Path)."
    
    Remove-Variable vm, hypervisor, encryptionKey, encryptionKeyFile, backupDirectory, hypervisorName
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
        [string]$Exclude = "SomethingThatisNotgoingTobinanactuallpathnameIhope!!!th!s is gh3tt0!",

        # What compression level to use
        [ValidateSet("Ultra", "High", "Fast", "Low", "None", "Normal")]
            [string]$compressionLevel = "Fast",
    
        [validatescript({$_ -match $ValidEmailAddress})]
            [string]$ProductOwnerEmail
    )
    
    ########## Begin Error Handling ##########
    # If any terminating error occurs, invoke the Send-AlertEmail function and stop the script
    trap {Send-AlertEmail -ItemBeingBackedUpName "$Name-Directory" -ProductOwnerEmail $ProductOwnerEmail; Exit 1}
    # Treat all errors as terminating, useful for the trap statement above
    $ErrorActionPreference = "Stop"
    ########## End Error Handling ##########

    $date = Get-Date -Format MM-dd-yyyy-HHmm
    
    # Get the password to encrypt the backup with
    $backupZipPassword = (Get-SecurePass -PwdFile $EncryptionKey).Password
    
    Write-Verbose "Encryption password retrieved. Starting backup."

    Write-Output "Backing up $BackupSource..."

    if (!(Test-Path $BackupDestinationDir)) {mkdir $BackupDestinationDir}
    if (!(Test-Path "$BackupDestinationDir\Logs")) {mkdir "$BackupDestinationDir\Logs"}

    if ($Type -eq "Incremental") {
        
        Write-Output "Incremental backup selected."

        $backupLog = "$BackupDestinationDir\Logs\$Name-INCREMENTAL-BackupLog-$date.txt"
        
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
        
        $backupLog = "$BackupDestinationDir\Logs\$Name-FULL-BackupLog-$date.txt"
        
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
    <#
    .SYNOPSIS
        Performs a full or incremental backup on an SSH appliance using TFTP.    

    .DESCRIPTION
        This function uses the Posh-SSH module to SSH into a target device and run a command, or list of commands, 
        specified when calling the function. It starts and stops an installed TFTP server and enables and disables
        an existing TFTP inbound firewall rule.

        When an incremental backup is performed, only files modifed since the last backup was completed will be backed up. If no 
        files have been modied since the last backup. The Compare-Files function is used to check for any differences between
        the new backup and the most recent backup to see if the device has been changed. 
        
        Requirements:
            * Must have access to (ie. on the same user account and computer as) the secure password file containing the password for the SSH user.
            * Solarwinds TFTP server must be installed.
            * An inbound firewall rule named "TFTP" allowing UDP port 69 must exist in the Windows Firewall.

    .EXAMPLE
        # Backups up device 10.7.2.3 by running the two commands specified in the array in the -CommandList parameter. Performs an incremental backup and uses an SSH Shell Stream.
        Backup-SshAppliance -DeviceIPs "10.7.2.3" -CommandList ("command one", "command two") -BackupDirectory C:\Backups -LogDirectory C:\BackupLogs -Username root -SecurePasswordFile C:\path\to\secure\pass\file -Incremental -SshShellStream -PrependDate
    
    .EXAMPLE
        # Backups up devices 10.7.2.3 and 10.7.2.4 by running command specified. Performs an full backup and doesn't use an SSH Shell Stream.
        Backup-SshAppliance -DeviceIPs "10.7.2.3" -CommandList "command two" -BackupDirectory C:\Backups -LogDirectory C:\BackupLogs -Username root -SecurePasswordFile C:\path\to\secure\pass\file -PrependDate -PrependIP
    
    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/15/2019

    .COMPONENT
        Posh-SSH, Compare-Files
    #>
    
    [CmdletBinding()]

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "SecurePasswordFile")]

    Param(
        # IP, or list of IPs, to perform the backup on
        [Parameter(Mandatory=$true)]
            [string[]]$DeviceIPs,

        # Array of commands to be run via SSH on remote device
        [Parameter(Mandatory=$true)]
            [string[]]$CommandList,

        # Directory to store the backups
        [Parameter(Mandatory=$true)]
            [string]$BackupDirectory,

        # Directory to store the logs
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
        [int]$CommandWaitTime = 10,

        # Don't prepend the date time stamp and/or the device's IP to the backup file name?
        [switch]$DoNotPrependDate,

        [switch]$DoNotPrependIP,
    
        [validatescript({$_ -match $ValidEmailAddress})]
            [string]$ProductOwnerEmail
    )

    #Requires -Modules Posh-SSH

    ########## Begin Error Handling ##########
    # If any terminating error occurs, invoke the Send-AlertEmail function and stop the script
    trap {Send-AlertEmail -ItemBeingBackedUpName "$DeviceIPs-SSH" -ProductOwnerEmail $ProductOwnerEmail; Exit 1}
    # Treat all errors as terminating, useful for the trap statement above
    $ErrorActionPreference = "Stop"
    ########## End Error Handling ##########

    if (!(Test-Path $backupDirectory)) {mkdir $backupDirectory}
    if (!(Test-Path $LogDirectory)) {mkdir $LogDirectory}

    $date = (Get-Date).ToString("MMddyyHHmm")

    $credentials = Get-SecurePass -PwdFile $SecurePasswordFile -userName $Username

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
        
        $PrependDate = $true
        $PrependIP = $true

        if (($DoNotPrependDate)) {$PrependDate = $false}
        if (($DoNotPrependIP)) {$PrependIP = $false}

        # Rename if file if the $PrependDate and/or $PrependIP switches are set
        if ($PrependDate) {
            Rename-Item $($newFileName.FullName) -NewName "$date-$($newFileName.Name)"
            Write-Verbose "Prepended date to file name."
            $newFileName = (Get-ChildItem $tftpRoot | Sort-Object LastWriteTime | Select-Object -Last 1)
        }
        if ($PrependIP) {
            Rename-Item $($newFileName.FullName) -NewName "$IP-$($newFileName.Name)"
            Write-Verbose "Prepended IP to file name."
        }
        $newFileName = (Get-ChildItem $tftpRoot | Sort-Object LastWriteTime | Select-Object -Last 1).FullName

        # Get the name of the most recent copy of the device's backup file
        $oldFileName = (Get-ChildItem "$deviceBackupDir" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName

        # If the -Incremental flag is set and there is a previous backup file
        if ($Incremental -and $oldFileName) {
            Write-Verbose "Beginning incremental (Compare-Files) portion..."
        
            Write-Output "Type: Incremental." | Out-File -Append $log
        
            Write-Verbose "Old file: $oldFileName; new file: $newFileName"

            # Check to see if there has been a change to the device since last backup
            # If so, store the changed lines in $compareResults
            $compareResults = Compare-Files $oldFileName $newFileName

            # If there has been a change to the backup file 
            If ($compareResults) {
                # Move the backup file to the backup directory
                Move-Item $newFileName $deviceBackupDir

                Write-Output "Device $IP has been backed up. A change has been detected." | Tee-Object -filepath $log -Append

                # Write the backup file's changes (the results of Compare-Files) to the change log
                Write-Output $compareResults | Out-File $log -Append
            }

            # If there has not been a change to the config
            Else {
                # Delete the newly created backup file
                #Remove-Item $newFileName
                Write-Output "Device $IP has not been backed up. No change has been detected." | Tee-Object -filepath $log -Append
            }
        }
        else {
            Write-Verbose "Incremental switch not set, or no previous backup present, moving new backup file to backup directory."
        
            Write-Output "Type: Full." | Out-File -Append $log

            # Move the backup file to the backup directory
            Move-Item $newFileName $deviceBackupDir

            $newlyMovedFile = (Get-ChildItem "$deviceBackupDir" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName

            Write-Verbose "Newly created file name: $newlyMovedFile."
        }

        Write-Output "Backup of $IP as $newFileName complete - $date." | Tee-Object -Append $log
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
            [string]$BackupDirectory,
    
        # Where is the log file to be stored?
        [string]$LogDirectory = "$BackupDirectory\Logs",
    
        [validatescript({$_ -match $ValidEmailAddress})]
            [string]$ProductOwnerEmail
    )

    ########## Begin Error Handling ##########
    # If any terminating error occurs, invoke the Send-AlertEmail function and stop the script
    trap {Send-AlertEmail -ItemBeingBackedUpName "Group Polcy" -ProductOwnerEmail $ProductOwnerEmail; Exit 1}
    # Treat all errors as terminating, useful for the trap statement above
    $ErrorActionPreference = "Stop"
    ########## End Error Handling ##########

    Write-Output "Beginning Group Policy backup..."

    if (!(Test-Path $backupDirectory)) {mkdir $backupDirectory}
    if (!(Test-Path $LogDirectory)) {mkdir $LogDirectory}

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
            Write-Output ("GPO {0} has been backed up." -f $name.PadRight(40,"-")) | Tee-Object -FilePath $log -Append
        }
        Else {Write-Output ("GPO {0} not backed up." -f $name.PadRight(40,"-")) | Tee-Object -FilePath $log -Append}
    }
}
function Backup-MSSQL {
    <#
    .SYNOPSIS
        Performs a full backup on an SQL Server database.    

    .DESCRIPTION
        This function performs a full backup of an SQL Server database using the Backup-SQLDatabase cmdlet.
        
        Requirements:
            * A user account with permissions on the SQL server.

    .EXAMPLE
        # Backs up the VeeamBackup database on the CBS1\VEEAMSQL2016 using the credentials being used by the current Powershell session.
        Backup-MSSQL -ServerAndInstance "CBS1\VEEAMSQL2016" -Database "VeeamBackup" -BackupDirectory "C:\Backup\DB"

    .EXAMPLE
        # Backs up the database named VeeamBackup on the VEEAMSQL2016 instance on the CBS1 server using the sa account.
        Backup-MSSQL -ServerAndInstance "CBS1\VEEAMSQL2016" -Database "VeeamBackup" -BackupDirectory "C:\Backup\DB" -Username "sa" -SecurePasswordFile "C:\path\to\file"
    
    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/15/2019

    .COMPONENT
        Backup-SQLDatabase
    #>
    
    [CmdletBinding(DefaultParameterSetName="None")]

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "SecurePasswordFile")]

    Param(
        # SQL Server and instance name (ie. "Server\Instance")
        [Parameter(Mandatory=$true)]
            [string]$ServerAndInstance,

        # Database name to be backed up (can be an array of multiple database names)
        [Parameter(Mandatory=$true)]
            [string[]]$Database,

        [Parameter(Mandatory=$true)]
            [string]$BackupDirectory,

        [Parameter(ParameterSetName="Creds",Mandatory=$false)]
        [string]$Username,

        [Parameter(ParameterSetName="Creds",Mandatory=$true)]
            [ValidateScript({Test-Path $_ -PathType 'leaf'})] 
            [string]$SecurePasswordFile,
    
        [validatescript({$_ -match $ValidEmailAddress})]
            [string]$ProductOwnerEmail
    )

    ########## Begin Error Handling ##########
    # If any terminating error occurs, invoke the Send-AlertEmail function and stop the script
    trap {Send-AlertEmail -ItemBeingBackedUpName "$Database-MSSQL" -ProductOwnerEmail $ProductOwnerEmail; Exit 1}
    # Treat all errors as terminating, useful for the trap statement above
    $ErrorActionPreference = "Stop"
    ########## End Error Handling ##########

    if (!(Test-Path $backupDirectory)) {mkdir $backupDirectory}
    if (!(Test-Path "$backupDirectory\Logs")) {mkdir "$backupDirectory\Logs"}

    $date = (Get-Date).ToString("MMddyyHHmm")

    foreach ($db in $Database) {
        $backupFile = "$BackupDirectory\$db-$date.bak"

        Write-Output "Backing up $db on $ServerAndInstance to $backupFile..."

        Try {
            # If a username is specified 
            # (and if it is, a path to a secure password file containing the password for the account will be required)
            if ($Username) {
                $creds = Get-SecurePass -PwdFile $SecurePasswordFile -userName $Username
                Backup-SqlDatabase -ServerInstance $ServerAndInstance -Database $db -BackupFile $backupFile -Credential $creds
            }
            # If a username and password are not specified, use the same credentials as the current Powershell session
            else {
                Backup-SqlDatabase -ServerInstance $ServerAndInstance -Database $db -BackupFile $backupFile
            }

            Write-Output "Backup of $db complete. "
        }
        
        Catch {
            Write-Output "There has been an error and the backup has not been completed."
            Write-Error "$_"
        }
    }
}

# Automatically delete backups as per retention policies
function Remove-Backups {
    <#
    .SYNOPSIS
        This is a Powershell script which cleans up old files.
        Used to comply with retention policies for various backups.
    
    .DESCRIPTION
        This script can be used in order to comply with the retention policy for backups stored on NAS1. The script      
        removes backups that are outside the time frame for the corresponding retention policy. For example, if a 
        retention policy states that a particular backup should be kept for 31 days, this script can delete any 
        backups that are more than 31 days old. It can be used in conjunction with Task Scheduler to automate the 
        process. Multiple backups can be configured in this script, each with their own retention policy settings.
    
        Each seperate item being backed up (eg. software, files, configurations, or other items) can be listed in the
        script, along with the directory its backups are located in, the time span (in days) of backups to keep, and
        optionally, a specific extension to delete and a custom log file location. 
    
        The function which performs the deletion, Cleanup-Backups (not to be confused with the name of the script...),
        is called seperately for each item who's backups are being cleaned up. See the script for examples.
    
    .NOTES
        Author: Eric Claus, System Administrator, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last Modified: 2/18/2019
        Modified from: http://www.networknet.nl/apps/wp/published/powershell-delete-files-older-than-x-days
    
    .LINK
        http://doku/doku.php?id=dr:cleanup-backups
    #>

    [CmdletBinding(DefaultParameterSetName="None")]

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "SecurePasswordFile")]
    
    Param(
        [Parameter(Mandatory=$true)]
            [string]$BackupName,
        
        [Parameter(Mandatory=$true)]
            [int]$DaysOldToKeep,
        
        [Parameter(Mandatory=$true)]
            [ValidateScript({Test-Path $_})]
            [string]$BackupFolder,
        
        [string]$Extension="*",
        
        [ValidateScript({Test-Path $_})]
            [string]$LogFile="$BackupFolder\Logs\Remove-Backups-$BackupName.log",
        
        [Parameter(ParameterSetName="Creds",Mandatory=$false)]
            [switch]$UseOtherCredentials,
        
        [Parameter(ParameterSetName="Creds",Mandatory=$true)] 
            [string]$Username,
        
        [Parameter(ParameterSetName="Creds",Mandatory=$true)] 
            [string]$SecurePasswordFile
    )
    
    if ($UseOtherCredentials) {
        # Create a PSCredential object with the password for the domain backup VLAN admin account
        $creds = Get-SecurePassword -PwdFile $SecurePasswordFile -userName $Username

        # Create a temporary mapped drive, connecting to the backup source folder with the credentials from above
        Remove-PSDrive -Name "myTempSource" -ErrorAction SilentlyContinue
        New-PSDrive -Name "myTempSource" -PSProvider FileSystem -Root $BackupFolder -Credential $creds
        $source = "myTempSource:\"
    }
    else {$source = $BackupFolder}
        
    $date = Get-Date

    # Set $lastWrite to a DateTime object that is the current date minus $DaysOldToKeep
    # This is the oldest date of files to be kept
    $lastWrite = $date.AddDays(-$DaysOldToKeep)

    # For the log
    Write-Output "------------------------------------------------------" >>$LogFile
    Write-Output "Performing cleanup of the $BackupName backups." | Tee-Object $LogFile -Append  
    Write-Output $date | Out-File $LogFile -Append
    Write-Output "Last write date: $lastWrite" | Out-File $LogFile -Append

    Write-Verbose "Last write date: $lastWrite"

    # Get files from the backup folder with the specified extension, if it is older than the time specified in $DaysOldToKeep
    $Files = Get-Childitem $source -Recurse -Filter "*.$Extension" | Where-Object {$_.LastWriteTime -le "$LastWrite"}	 

    # If there are no files to be deleted
    if ($NULL -eq $Files) {
        Write-Output "No files to delete today!" | Out-File $LogFile -Append
        Write-Verbose "No files to delete today!"
    }

    # Loop through each file and delete it.
    foreach ($File in $Files) {
        if ($NULL -ne $File) {
            Write-Output "Deleting File $File" | Out-File $LogFile -Append
            Write-Verbose "Deleting File $File"
            Remove-Item -LiteralPath $File.FullName -Recurse
        }
    }
}

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
    defined in the script (by default this is the path to Cyrus's root directory as defined at the 
    top of the Cyrus.psm1 module file), or a directory specified with the -PwdFileDir parameter.
    
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
    Prompts for a password, then converts it to a secure string and saves the file to Cyrus's root directory.
    
    .EXAMPLE
    New-SecurePassFile "C:\myPwds\"
    Prompts for a password, then converts it to a secure string and saves the file to the "C:\myPwds\" directory.
    
    .NOTES
    Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
    Last Modified: 11/07/2017
    Based on code from Shawn Melton (@wsmelton), http://blog.wsmelton.com
    
    .LINK
    https://www.sqlshack.com/how-to-secure-your-passwords-with-powershell/
    #>

    Param(
        [ValidateScript({Test-Path $_})]
            [string]$PwdFileDir = "$CBSRootDirectory\SecurePassFiles"
    )
    
    $PwdFile = "$PwdFileDir\$(Get-Random).pass"
       
    $Password = (Read-Host -Prompt "Enter the password to add to the file" -AsSecureString)
    
    ConvertFrom-SecureString -SecureString $Password | Out-File $PwdFile
    
    Write-Output $PwdFile
}

# Automatically assign drive letters for rotating external hard drives
function Set-DriveLetter{
    <#
.SYNOPSIS
    This function changes the assigned drive letters of the NAS and VM backup partitions on the Backup External Hard Drives.
 
.DESCRIPTION
    This function can be called from the Cyrus Backup Solution core script to make sure that all drives and partitions
    on any removable media (such as external hard drives) that are rotated out have the correct assigned drive letters.
    This eliminates the need to manually change the assigned drive letters. 

    Drives are selected via a wild card match of their name, with the percent (%) sign being a wild card character. 
    For example, if you wish to change the drive letter of a drive named "SSS_7829DH", pass the following into the 
    $DriveOrPartitionName parameter (without the quotes): "SSS%"".

.EXAMPLE
    # Set the assigned drive letter of drive "VM Backup Partition [1|2|3]" to "V".
    Set-DriveLetter -DriveOrPartitionName "VM Backup %" -DriveLetter "v"
 
.NOTES
    Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
    Last Modified: 2/18/2019
 
.LINK
    https://blogs.technet.microsoft.com/heyscriptingguy/2011/03/14/change-drive-letters-and-labels-via-a-simple-powershell-command/
    https://stackoverflow.com/questions/46557186/wildcard-search-in-filter
 
.COMPONENT
    Get-WmiObject -Class win32_volume
#>
 
[CmdletBinding()]

Param(
    [Parameter(Mandatory=$true)]
        [string]$DriveOrPartitionName,

    [Parameter(Mandatory=$true)]
        [string]$DriveLetter
)

$filterString = "Label like '$DriveOrPartitionName'"

$drive = Get-WmiObject -Class win32_volume -Filter $filterString
$drive.DriveLetter = "$($DriveLetter):"
$drive.Put() | Out-Null
}

# Read in the config file, return hash table of hash tables
# Thanks to Oliver Lipkau for this function
# https://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91/
Function Get-IniContent {  
    <#  
    .Synopsis  
        Gets the content of an INI file  
          
    .Description  
        Gets the content of an INI file and returns it as a hashtable  
          
    .Notes  
        Author        : Oliver Lipkau <oliver@lipkau.net>  
        Blog        : http://oliver.lipkau.net/blog/  
        Source        : https://github.com/lipkau/PsIni 
                      http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91 
        Version        : 1.0 - 2010/03/12 - Initial release  
                      1.1 - 2014/12/11 - Typo (Thx SLDR) 
                                         Typo (Thx Dave Stiff) 
          
        #Requires -Version 2.0  
          
    .Inputs  
        System.String  
          
    .Outputs  
        System.Collections.Hashtable  
          
    .Parameter FilePath  
        Specifies the path to the input file.  
          
    .Example  
        $FileContent = Get-IniContent "C:\myinifile.ini"  
        -----------  
        Description  
        Saves the content of the c:\myinifile.ini in a hashtable called $FileContent  
      
    .Example  
        $inifilepath | $FileContent = Get-IniContent  
        -----------  
        Description  
        Gets the content of the ini file passed through the pipe into a hashtable called $FileContent  
      
    .Example  
        C:\PS>$FileContent = Get-IniContent "c:\settings.ini"  
        C:\PS>$FileContent["Section"]["Key"]  
        -----------  
        Description  
        Returns the key "Key" of the section "Section" from the C:\settings.ini file  
          
    .Link  
        Out-IniFile  
    #>  
      
    [CmdletBinding()]  
    Param(  
        [ValidateNotNullOrEmpty()]  
        [ValidateScript({(Test-Path $_) -and ((Get-Item $_).Extension -eq ".ini")})]  
        [Parameter(ValueFromPipeline=$True,Mandatory=$True)]  
        [string]$FilePath  
    )  
      
    Begin  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"}  
          
    Process  
    {  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Processing file: $Filepath"  
              
        $ini = @{}  
        switch -regex -file $FilePath  
        {  
            "^\[(.+)\]$" # Section  
            {  
                $section = $matches[1]  
                $ini[$section] = @{}  
                $CommentCount = 0  
            }  
            "^(;.*)$" # Comment  
            {  
                if (!($section))  
                {  
                    $section = "No-Section"  
                    $ini[$section] = @{}  
                }  
                $value = $matches[1]  
                $CommentCount = $CommentCount + 1  
                $name = "Comment" + $CommentCount  
                $ini[$section][$name] = $value  
            }   
            "(.+?)\s*=\s*(.*)" # Key  
            {  
                if (!($section))  
                {  
                    $section = "No-Section"  
                    $ini[$section] = @{}  
                }  
                $name,$value = $matches[1..2]  
                $ini[$section][$name] = $value  
            }  
        }  
        Write-Verbose "$($MyInvocation.MyCommand.Name):: Finished Processing file: $FilePath"  
        Return $ini  
    }  
          
    End  
        {Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"}  
} 

# Get the histories of each backup
function Show-HumanReadableSize {
    <#
    .SYNOPSIS
        Converts a file's size, specified in bytes as an int, to a human readable form.  

    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/25/2019
    #>

    param(
        [Parameter(Mandatory=$True)][long]$SizeInBytes
    )

    if ($SizeInBytes -ge 1GB) {
        $humanReadableSize = "$([math]::Round($SizeInBytes / 1GB,2)) GB"
    }
    elseif ($SizeInBytes -ge 1MB) {
        $humanReadableSize = "$([math]::Round($SizeInBytes / 1MB,2)) MB"
    }
    elseif ($SizeInBytes -ge 1KB) {
        $humanReadableSize = "$([math]::Round($SizeInBytes / 1KB,2)) KB"
    }

    return $humanReadableSize
}
function Get-BackupFileHistory{
    <#
    .SYNOPSIS
        Gets a list of all backup files in a specified backup directory.   

    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/25/2019

    .COMPONENT
        Show-HumanReadableSize
    #>

    param(
        [Parameter(Mandatory=$True)]
            [ValidateScript({Test-Path $_})]
            [string]$BackupDir,

        [string]$FileExtensionWithoutPeriod="*"
    )

    Get-ChildItem $BackupDir -Filter "*.$FileExtensionWithoutPeriod" | 
        Sort-Object CreationTime -Descending |  ForEach-Object {
            [PSCustomObject]@{
                Name = $_.FullName
                CreationTime = $_.CreationTime
                LastModified = $_.LastWriteTime
                Size = (Show-HumanReadableSize $_.Length)
            }
        }
}

# Dynamically create HTML pages for the web dashboard
function Write-HtmlContent{
    <#
    .SYNOPSIS
        Builds the HTML header and other parts of HTML pages excluding the tables created
        dynamically via the Write-HtmlPages funtion.   

    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/25/2019
    #>

    param(
        [Parameter(Mandatory=$True)]
            [string]$PageTitle,
        [Parameter(Mandatory=$True)]
            [string]$PageHeader,
        [Parameter(Mandatory=$True)]
            [string]$Frequency
    )

    $Head = @"
        <title>$PageTitle</title>
        <link href="style.css" rel="stylesheet" type="text/css" />
        <!-- Sorting Javascript script from: https://www.kryogenix.org/code/browser/sorttable/ -->
        <script src="./Scripts/sorttable.js"></script>
        <!--JS from https://stackoverflow.com/a/42333464 -->
        <script src="./Scripts/jquery-1.10.2.js"></script>
"@

    $PreContent = @"
    <!--Nav bar (code modified from https://stackoverflow.com/a/42333464)-->
    <div id="nav-placeholder"></div>
    <script>`$(function(){`$("#nav-placeholder").load("./page_elements/nav-bar.html");});</script>
    <!--end of Navigation bar-->

    <div class="page-header">
        <h1>$PageHeader</h1>
        <p>Frequency: $Frequency</p>
    </div>
    <div class="page-content">
    <div class="table-container">

"@

    $PostContent = @"
    </div>
    </div>

    <!--Footer (code modified from https://stackoverflow.com/a/42333464)-->
    <div id="foot-placeholder"></div>
    <script>`$(function(){`$("#foot-placeholder").load("./page_elements/foot.html");});</script>
    <!--end of Footer-->
"@

    return @($Head,$PreContent,$PostContent)
}
function Write-HtmlPage{
    <#
    .SYNOPSIS
        Creates HTML pages containing histories of various items backup history.    

    .DESCRIPTION
        This script contains a list of all backups, and their backup directories, to check the
        history of. The script takes this list and uses the Show-BackupStatusHistory function
        to get a table containing all backup files for each item being checked. It then creates
        HTML pages containing these tables, one for each backed up item listed in the script.

    .NOTES
        Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last modified: 2/26/2019

    .COMPONENT
        Get-BackupFileHistory, Write-HtmlContent, ConvertTo-Html
    #>

    param(
        [Parameter(Mandatory=$True)]
            [ValidateScript({Test-Path $_})]
            [string]$BackupDirPath,
        [Parameter(Mandatory=$True)]
            [string]$HtmlFileName,
        [Parameter(Mandatory=$True)]
            [string]$HtmlPageTitle,
        [Parameter(Mandatory=$True)]
            [string]$Frequency,
        [string]$FileExtensionWithoutPeriod = "*"
    )

    $Head, $PreContent, $PostContent = Write-HtmlContent -PageTitle $HtmlPageTitle -PageHeader $HtmlPageTitle -Frequency $Frequency

    if ($HtmlFileName -notlike "*.html") {
        $HtmlFileName = "$HtmlFileName.html"
    }

    Get-BackupFileHistory -BackupDir $BackupDirPath -FileExtensionWithoutPeriod $FileExtensionWithoutPeriod | 
        ConvertTo-Html -Head $Head -PreContent $PreContent -PostContent $PostContent | 
        Out-File -Encoding ascii "$WebDashboardRootDirectory\$HtmlFileName"
}
function Write-IndexPage{   
<#
.SYNOPSIS
    Builds the home page (index.html) for the Cyrus Backup Solution Dashboard.   

.DESCRIPTION
    This function gets a list of all of the backup history pages in the Cyrus Dashboard directory 
    (all HTML files whose names start with "History_"). Then, it compiles the HTML for the index
    page and creates index.html. 

.NOTES
    Author: Eric Claus, Sys Admin, Collegedale Academy, ericclaus@collegedaleacademy.com
    Last modified: 2/26/2019

.COMPONENT
    Get-ChildItem, Out-File
#>

param(
    [string]$RootDirectory = $WebDashboardRootDirectory
)

$PageTitle = "Cyrus Dashboard"
$PageHeader = "Welcome to the Dashboard for the Cyrus Backup Solution!"

$vmList = ""

Get-ChildItem $RootDirectory -Filter "History_VM*.html" | Select-Object Name | 
    ForEach-Object {
        $FileName = $_.Name
        $DisplayName = ($_.Name).Split("-")[1]
        $DisplayName = $DisplayName.Split(".")[0]
        $vmList += "<a class='history-link' href='$FileName' title='$DisplayName'>$DisplayName</a><br/>"
    }

$dirSshList = ""

Get-ChildItem $RootDirectory -Filter "History_Dir*.html" | Select-Object Name | 
    ForEach-Object {
        $FileName = $_.Name
        $DisplayName = ($_.Name).Split("-")[1]
        $DisplayName = $DisplayName.Split(".")[0]
        $dirSshList += "<a class='history-link' href='$FileName' title='$DisplayName'>$DisplayName</a><br/>"
    }

Get-ChildItem $RootDirectory -Filter "History_SSH*.html" | Select-Object Name | 
    ForEach-Object {
        $FileName = $_.Name
        $DisplayName = ($_.Name).Split("-")[1]
        $DisplayName = $DisplayName.Split(".")[0]
        $dirSshList += "<a class='history-link' href='$FileName' title='$DisplayName'>$DisplayName</a><br/>"
    }

$otherList = ""

Get-ChildItem $RootDirectory -Filter "History_*.html" | 
    Where-Object {($_.Name -NotLike "History_SSH*") -and ($_.Name -NotLike "History_VM*") -and ($_.Name -NotLike "History_Dir*")} | 
    Select-Object Name | 
    ForEach-Object {
        $FileName = $_.Name
        $DisplayName = ($_.Name).Split("_")[1]
        $DisplayName = $DisplayName.Split(".")[0]
        $otherList += "<a class='history-link' href='$FileName' title='$DisplayName'>$DisplayName</a><br/>"
    }

$Page = @"
<head>
        <title>$PageTitle</title>
        <link href="style.css" rel="stylesheet" type="text/css" />
        <!--JS from https://stackoverflow.com/a/42333464 -->
        <script src="./Scripts/jquery-1.10.2.js"></script>
</head>
<body id="index-page">
    <!--Nav bar (code modified from https://stackoverflow.com/a/42333464)-->
    <div id="nav-placeholder"></div>
    <script>`$(function(){`$("#nav-placeholder").load("./page_elements/nav-bar.html");});</script>
    <!--end of Navigation bar-->
    
    <div class="page-header">
        <h1>$PageHeader</h1>
        <p>Last updated: $(Get-Date)</p>
    </div>
    
    <div class="page-content">
        <div class="sub-content">
            <div class="sub-content-head">
                <h3>VM Backup History</h3>
            </div>
            <div class="history-link-container">
                $vmList
            </div>
        </div>
        <div class="sub-content">
            <div class="sub-content-head">
                <h3>Directory and SSH Backup History</h3>
            </div>
            <div class="history-link-container">
                $dirSshList
            </div>
        </div>
        <div class="sub-content">
            <div class="sub-content-head">
                <h3>Other Backup History</h3>
            </div>
            <div class="history-link-container">
                $otherList
            </div>
        </div>
    </div>
        
    <!--Footer (code modified from https://stackoverflow.com/a/42333464)-->
    <div id="foot-placeholder"></div>
    <script>`$(function(){`$("#foot-placeholder").load("./page_elements/foot.html");});</script>
    <!--end of Footer-->
</body>
"@

$Page | Out-File "$RootDirectory\Index.html" -Encoding ascii
}

# Manage the TFTP server
function Start-TftpServer {
    # Start SolarWinds TFTP Server
    Write-Output "Starting TFTP server..."
    Start-Service -Name "SolarWinds TFTP Server"

    # Enable the TFTP firewall rule
    Write-Output "Enabling TFTP firewall rule..."
    netsh advfirewall firewall set rule name="TFTP" new enable=yes
}
function Stop-TftpServer {
    # Stop Solarwinds TFTP Server
    Write-Output "Stopping TFTP server..."
    Stop-Service -Name "SolarWinds TFTP Server"

    # Disable the TFTP firewall rule
    Write-Output "Disabling TFTP firewall rule..."
    netsh advfirewall firewall set rule name="TFTP" new enable=no
}

# Compare files for incremental backups
function Compare-Files{
    <#
    .SYNOPSIS
        Compare two files and return any changes.
    
    .DESCRIPTION
        Compare-Files uses Compare-Object to compare two files. It outputs
        the differences between the two files in a formatted table. By
        setting the -IncludeEqual flag, it can return all of the lines 
        that are unchanged, as well. 

        If differences between the two files are found, an array containing
        the differences is returned. The output has the format:

        Line Number    <name of older file>    <name of newer file>    Action
        -----------    --------------------    --------------------    ------
                  4    This is a line of text                          Removed
                 12                            A new line of text      Added    

    .INPUTS
        This script does not accept any piped inputs.
    
    .OUTPUTS
        None, or [System.Array]
    
    .NOTES
        Author: Eric Claus, IT Assistant, Collegedale Academy, ericclaus@collegedaleacademy.com
        Last Modified: 05/04/2018
    
        Thanks to Lee Holmes for his Compare-File script, from which this is based.
    
    .LINK
        http://doku/doku.php?id=other:compare-files
        http://www.leeholmes.com/blog/2013/11/29/using-powershell-to-compare-diff-files/
    
    .COMPONENT
        Compare-Object
    #>
    
    Param(
        [Parameter(Mandatory=$True)][string]$oldFile,
        [Parameter(Mandatory=$True)][string]$newFile,
        [switch]$IncludeEqual
    )

    # Get the file names from the full paths
    $oldName = Split-Path -Path $oldFile -Leaf
    $newName = Split-Path -Path $newFile -Leaf

    $oldContents = Get-Content $oldFile
    $newContents = Get-Content $newFile
    
    # Compare the two files, sort the lines by line number, and loop through them
    Compare-Object $oldContents $newContents -IncludeEqual:$IncludeEqual | Sort-Object {$_.InputObject.ReadCount} | ForEach-Object {
        
        $line = "$($_.InputObject)"
        
        # What change was made to the line
        Switch ($_.SideIndicator) {
            "==" {$action = ""; $oldLine = $newLine = $line}
            "=>" {$action = "Added"; $oldLine = ""; $newLine = $line}
            "<=" {$action = "Removed"; $oldLine = $line; $newLine = ""}
        }
    
        # Return a PSCustomObject, creates an array when returned multiple times
        [PSCustomObject] @{
            "Line Number" = $_.InputObject.ReadCount
            $oldName = $oldLine
            $newName = $newLine
            Action = $action
        }
    }
}


##################################################################################################
############# Insert Additional Functions Below This #############################################
