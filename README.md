# Cyrus Backup Solution (either CBS or Cyrus for short)

## System Requirements
Cyrus supports Windows Server 2016. While it can run in a VM, it is recommended to run Cyrus on a physical server because it will have easier access to removable storage media. 

Below are the minimum recommended hardware specs (but, the higher the specs the better, especially for virtual machine backups!):
* 4 GB of memory
* 4 CPU cores (or vCPUs)
* 80 GB of storage

## Installing Prerequisites
CBS needs the following prerequisites to fully work. Follow the steps listed under each prerequisite to install the prerequisite.

* Veeam Backup & Replication Community Edition ( https://www.veeam.com/virtual-machine-backup-solution-free.html). You can use a paid version, but it is not necessary as all CBS needs is VeeamZIP, which is included in the free version. Once installed, add any hypervisors to it that you will be backing up virtual machines (VMs) from.
* SolarWinds TFTP Server (https://www.solarwinds.com/free-tools/free-tftp-server). Once installed, create a Windows Firewall rule allowing UDP port 69 inbound (this rule can be disabled).
* Microsoft IIS. Create new site in IIS pointing to the Dashboard folder inside of Cyrus's root directory.
* Storage media to hold the backups (at least two external hard drives are recommended).

## Installing Cyrus Backup Solution
Cyrus can be found in its GitHub repo here: https://github.com/ericclaus14/CyrusBackupSolution
* The easiest way is to download the repo as a ZIP file and then extract the contents to Cyrus's new root directory (e.g. 'C:\CyrusBackupSolution').
* Feel free to clone the repo to your server as well.

Once Cyrus's source files are located on your server, there are a few additional things you'll need to do to complete the installation.

First, you'll need to add Cyrus's root directory (e.g. 'C:\CyrusBackupSolution') to the PSModulePath system environment variable in Windows.
1. Search for 'system environment variables' in the Start Menu and open "Edit the system environment variables".
2. From the "Advanced" tab of the System Properties window (that has hopefully now opened), click "Environment Variables".
3. In the "System variables" section near the bottom of the window (NOT the "user variables" section!), scroll down to the "PSModulePath" variable.
4. Edit the "PSModulePath" variable and add a new entry to the list inside of the variable. Add the path to Cyrus's root directory.
  * IMPORTANT: Inside of Cyrus's root directory, the PowerShell module file (.psm1) must be inside of a folder of the same name. By defaut the module file is named 'Cyrus.psm1' and is inside of a folder named 'Cyrus' (i.e. '<Cyrus root directory>\Cyrus\Cyrus.psm1').

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
   3. Set the "Add arguments" field to the path of Cyrus's core script, Cyrus.ps1 (this should be '<Cyrus root directory>\Cyrus.ps1', e.g. 'C:\CyrusBackupSolution\Cyrus.ps1').
   4. Click "OK" to return to the 'Create Task' window.
5. To save the task, click "OK" in the 'Create Task' window and enter the password for the domain account the task is set to run for (again, ideally this should be a domain admin account that only Cyrus uses).

## Initial Configuration
If you have been following these instructions so far, Cyrus should now be installed. Congratulations! 

Now, on to the initial configuration of Cyrus!

Almost all of the configuration is done in the config file, Cyrus-Config.ini. This should be located Cyrus's root directory.

But, when you are initially installing Cyrus there are a few changes that must be made to the core script, Cyrus.ps1, and the PowerShell module, Cyrus.psm1. The core script should be located in Cyrus's root directory and the module in the 'Cyrus' subfolder inside of Cyrus's root directory.

Inside of the core script, Cyrus.ps1, change the value being assigned to the variable named "$CBSRootDirectory" to match Cyrus's root directory (e.g. 'C:\CyrusBackupSolution').

Next, inside of the PowerShell module, Cyrus.psm1, change the following variables:
* $CBSRootDirectory 
   * Set the value being assigned to this variable to the path of Cyrus's root directory (the same as in Cyrus.ps1)
* $HelpDeskEmail
   * Set the value being assigned to this variable whatever email address you want ALL backup alerts to be sent to (secondary email addresses for specific backup jobs (e.g. the product owner's email address) are set individually for each backup job).

