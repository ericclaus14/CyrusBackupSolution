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

# Perform backups
function Backup-VM {}
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