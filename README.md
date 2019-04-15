# Cyrus Backup Solution (either CBS or Cyrus for short)

## System Requirements
Cyrus supports Windows Server 2016. While it can run in a VM, it is recommended to run Cyrus on a physical server because it will have easier access to removable storage media. 

Below are the minimum recommended hardware specs (but, the higher the specs, the better, especially for virtual machine backups!):
* 4 GB of memory
* 4 CPU cores (or vCPUs)
* 80 GB of storage

## Installing Prerequisites
CBS needs the following prerequisites to fully work.

* Veeam Backup & Replication Community Edition ( https://www.veeam.com/virtual-machine-backup-solution-free.html). You can use a paid version, but it is not necessary as all CBS needs is VeeamZIP, which is included in the free version. Once installed, add any hypervisors to it that you will be backing up virtual machines (VMs) from.
* SolarWinds TFTP Server (https://www.solarwinds.com/free-tools/free-tftp-server). This requires .NET Framework 3.5. If this is not already installed, install it from the "Add roles and features" wizard in the Server Manager.
* A Windows Firewall rule allowing UDP port 69 inbound (this rule can be disabled). This rule MUST be named "TFTP" (without the quotes).
* Microsoft IIS. Create new site in IIS pointing to the Dashboard folder inside of Cyrus's root directory (C:\CyrusBackupSolution\Dashboard).
* The Posh-SSH PowerShell module. Install this by running 'Install-Module Posh-SSH' from an elevated PowerShell session.
* Storage media to hold the backups (at least two external hard drives are recommended).
* A domain account with permissions for the following (it is recommended to have a domain account dedicated to Cyrus that is only used by Cyrus):
   * Read permissions on all Group Policy Objects (if backing up Group Policy Objects)
   * Read permissions on all Microsoft SQL databases being backed up
   * Full permissions for the instance Veeam Backup & Replication being used to backup virtual machines
   * Read permissions on all directories/file shares being backed up

## Installing Cyrus Backup Solution
Cyrus can be found in its GitHub repo here: https://github.com/ericclaus14/CyrusBackupSolution
* The easiest way is to download the repo as a ZIP file and then extract the contents to Cyrus's new root directory: 'C:\CyrusBackupSolution'.
* Feel free to clone the repo to your server as well.

Once Cyrus's source files are located on your server, there are a few additional things you'll need to do to complete the installation.

First, you'll need to add Cyrus's root directory ('C:\CyrusBackupSolution') to the PSModulePath system environment variable in Windows.
1. Search for 'system environment variables' in the Start Menu and open "Edit the system environment variables".
2. From the "Advanced" tab of the System Properties window (that has hopefully now opened), click "Environment Variables".
3. In the "System variables" section near the bottom of the window (NOT the "user variables" section!), scroll down to the "PSModulePath" variable.
4. Edit the "PSModulePath" variable and add a new entry to the list inside of the variable. Add the path to Cyrus's root directory.
  * IMPORTANT: Inside of Cyrus's root directory, the PowerShell module file (.psm1) must be inside of a folder of the same name. By defaut the module file is named 'Cyrus.psm1' and is inside of a folder named 'Cyrus' (i.e. 'C:\CyrusBackupSolution\Cyrus\Cyrus.psm1').

Next, create a new scheduled task in the Windows Task Scheduler to run Cyrus's core script, Cyrus.ps1, every 30 minutes.
1. From the Task Scheduler, click "Create Task" in the right-hand menu.
2. From the 'General' tab of the 'Create Task' window:
   1. Set the name of the task to something relevant (e.g. "Cyrus Backup Solution"),
   2. Check the box to "Run with highest privileges",
   3. Check the radio button to select "Run whether user is logged on or not",
   4. Change the user whom the task is run under to the correct account (idealy a domain admin account used only by Cyrus),
   5. Change the "Configure for" option to "Windows Server 2016".
3. Switch to the 'Triggers' tab of the 'Create Task' window and create a new trigger:
   1. Make sure that the "Begin the task" option is set to "On a schedule",
   2. Check the radio button to select "Daily",
   3. Change the start time to 12:00:00 AM,
   4. Make sure it is set to recur every 1 days,
   5. Check the box to "Repeat task every" and set its value to 30 minutes,
   6. Make sure the checkbox to enable the trigger is checked and click "OK".
4. Switch to the 'Actions' tab of the 'Create Task' window and create a new action:
   1. Make sure the "Action" is set to "Start a program",
   2. Set the "Program/script" field to "powershell" (without the quotes),
   3. Set the "Add arguments" field to the path of Cyrus's core script, Cyrus.ps1 (this should be 'C:\CyrusBackupSolution\Cyrus.ps1').
   4. Click "OK" to return to the 'Create Task' window.
5. To save the task, click "OK" in the 'Create Task' window and enter the password for the domain account the task is set to run for (again, ideally this should be a domain admin account that only Cyrus uses).

### Initial Configuration
If you have been following these instructions so far, Cyrus should now be installed. Congratulations! 

Now, on to the initial configuration of Cyrus!

Almost all of the configuration is done in the config file, Cyrus-Config.ini. This should be located Cyrus's root directory.

But, when you are initially installing Cyrus there are a few changes that must be made to the core script, Cyrus.ps1, and the PowerShell module, Cyrus.psm1. The core script should be located in Cyrus's root directory and the module in the 'Cyrus' subfolder inside of Cyrus's root directory.

Inside of the core script, Cyrus.ps1, change the value being assigned to the variable named "$CBSRootDirectory" to match Cyrus's root directory ('C:\CyrusBackupSolution').

Next, inside of the PowerShell module, Cyrus.psm1, change the following variables:
* $CBSRootDirectory 
   * Set the value being assigned to this variable to the path of Cyrus's root directory (the same as in Cyrus.ps1). This should be 'C:\CyrusBackupSolution'.
* $HelpDeskEmail
   * Set the value being assigned to this variable whatever email address you want ALL backup alerts to be sent to (secondary email addresses for specific backup jobs (e.g. the product owner's email address) are set individually for each backup job).

## Defining a New Backup Bob (backing up a new item)
All backup jobs are defined in Cyrus-Config.ini. Documentation is included inside of the config file. Below are a couple example backup job definitions with explanations. Comments are included as sub-bullets.

### Example one
* **[CyrusRepoFull]**                             
   * This must be a unique value!
* **Name=CyrusRepo**                              
   * This is the name of the item being backed up. It will be displayed on the web dashboard. In the case of a directory that has both incremental and full backup jobs defined for it, this name must be the same for both backup jobs.
* **Type=DirectoryFull**                          
   * The type of backup job it is. See the comments at the top of the config file for a list. This determines how the item will be backed up. In this example, a full backup is being completed on a directory.
* **Frequency=Weekly,Sunday,20,top**              
   * How often this backup job is to be run. See the comments at the top of the config file for the syntax for this. In this example, the backup job is to run weekly, every Sunday, at 8:00 pm (at the top of the hour).
* **Retention=1**                                 
   * How long the backup file are to be kept for in days. After this amount of time, backup files will be deleted.
* **BkDir=\\fileSvr-01\fileShare**       
   * Where the backups are to be stored.
* **SourcePath=C:\Repos\CyrusBackupSolution**      
   * The path to the directory being backed up. Note that different backup job types may have different names for this parameter. See the comments at the top of the config file for the correct syntax.
* **Owner=user1@domain.com**      
   * The product owner's email address. This is an address that should receive alerts if the backup job fails.
* **EncryptionKeyFile=C:\CyrusBackupSolution\SecurePasswordFiles\dirEncryption.pass**     # The path to the secure password file containing the encryption key to be used when encrypting the backup. See the "Generating secure password files with New-SecurePassFile" section of this document for details on how to generate this file.

### Example two
* **[HDSwitch]**                                  
   * This must be a unique value!
* **Name=HDSwitch**                               
   * This is the name of the item being backed up. It will be displayed on the web dashboard.
* **Type=SSH-Incremental-SSHShellStream**         
   * The type of backup job it is. See the comments at the top of the config file for a list. This determines how the item will be backed up. In this example, an incremental backup is being performed on an SSH-enabled appliance that uses an SSH Shell Stream.
* **Frequency=Hourly,bottom**                     
   * How often this backup job is to be run. See the comments at the top of the config file for the syntax for this. In this example, the backup job is to run every hour at the bottom of the hour. 
* **Retention=90**                                
   * How long the backup file are to be kept for in days. After this amount of time, backup files will be deleted.
* **BkDir=C:\Backup\SSH\Switches\6**              
   * Where the backups are to be stored.
* **NetPath=10.190.19.6**                          
   * The IP address of the device being backed up.
* **Owner=user2@domain.com**      
   * The product owner's email address. This is an address that should receive alerts if the backup job fails.
* **CommandList=write mem,copy startup-config tftp 10.180.27.30 6-config.cfg**
   * The command, or list of commands, to be run on the target device once an SSH connection is established. If multiple commands are needed, seperate them with commas (','). Cyrus will run each command in order.
* **Username=admin**
   * The username of the account to be used to SSH into the device being backed up.
* **PasswordFile=C:\Repos\CyrusBackupSolution\Other\SecurePasswordFiles\22134658.pass**   
   * The path to the secure password file containing the password of the account to be used to SSH into the device being backed up (should correspond with the username specified above!). See the "Generating secure password files with New-SecurePassFile" section of this document for details on how to generate this file.
* **BackupFileExtension=cfg** 
   * What extension the backup file will have. This is only required for some backup types. See the comments at the top of the config file for details as to which backup types need this parameter.

### Generating secure password files with New-SecurePassFile
New-SecurePassFile is a PowerShell function defined in Cyrus's PowerShell module, Cyrus.psm1. It can be run to create a secure password that will be used in backup jobs (as defined in the config file, Cyrus-Config.ini).

When run, it prompts for a password to be entered. This password is encrypted as a secure string and then exported to an encrypted file. The file name is randomly generated and the directory it is located in can be either be left to the default directory, Cyrus's root directory, or set to a directory specified with the -PwdFileDir parameter. 

It returns the path to the secure password file as a string. This is used to securely store passwords such as the encryption keys for virtual machine and directory backups and the passwords for accounts used to SSH into network appliances.

This function must be run on the same computer and by the same user account that will run the scheduled task used to run Cyrus! For example, if the scheduled task that runs Cyrus.ps1 is configured to run under an account named "Cyrus", you must use this same account when running New-SecurePassFile and creating the secure password files.

#### Example one
New-SecurePassFile.ps1 # Prompts for a password, then converts it to a secure string and saves the file to Cyrus's root directory.

#### Example two
New-SecurePassFile -PwdFileDir "C:\myPwds\" # Prompts for a password, then converts it to a secure string and saves the file to the "C:\myPwds\" directory.

## Creating a New Backup Type (Backing Up A Different Type of Item)
So, you want to back up something that is not already covered by Cyrus Backup Solution? Great! Here are the high level steps needed to create a new backup type and incorporate into Cyrus.

1. Write a PowerShell function to perform the backup. Feel free to look over the existing backup functions in Cyrus.psm1 for examples. 
2. Name your new function "Backup-<item being backed up>" (e.g. "Backup-Spiceworks"). Place this function in the bottom of the PowerShell module file, Cyrus.psm1.
3. If your new backup function accepts parameters that have different names than any of the parameters used in the existing functions, add these new paramaters to the #### Backup Job Properties #### section in the core script, Cyrus.ps1. Follow the syntax used with the existing parameters defined in the Backup Job Properties section of Cyrus.ps1.
4. Add the new backup job type to the #### Backup Job Types #### section in the core script, Cyrus.ps1. This section consists of a Switch (case) statement. Follow the syntax of the existing backup job types in the Switch statement in Cyrus.ps1. A skelton of a new backup type Switch statement is included in Cyrus.ps1.
5. Add the new backup job(s) to the config file, Cyrus-Config.ini. Follow the syntax of the existing backup job definitions in Cyrus-Config.ini. Make sure:
   1. That the following properties are included in your new backup job definition:
      1. Name
      2. Type
      3. Frequency
      4. Retention
      5. BkDir
      6. Owner
   2. That the Type property is identical to the cooresponding value in the Switch statement in the Backup Job Type section of Cyrus.ps1.
6. Test, test, test! 

## Using the Web Dashboard
The web dashboard for Cyrus Backup Solution should be accessible at http://<ip address of server>:<port defined for the site in IIS (typically 80)>

The dashboard consists of a home page with links to pages for each item being backed up with Cyrus. On these individual pages are tables containing a list of each backup for that item.