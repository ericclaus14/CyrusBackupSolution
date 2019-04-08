# Cyrus Backup Solution (CBS)

## System Requirements
CBS supports Windows Server 2016. While it can run in a VM, it is recommended to run CBS on a physical server because it will have easier access to removable storage media. 

Below are the minimum recommended hardware specs (but, the higher the specs the better, especially for virtual machine backups!):
* 4 GB of memory
* 4 CPU cores (or vCPUs)
* 80 GB of storage

## Installing Prerequisites
CBS needs the following prerequisites to fully work. Follow the steps listed under each prerequisite to install the prerequisite.

* Veeam Backup & Replication Community Edition ( https://www.veeam.com/virtual-machine-backup-solution-free.html). You can use a paid version, but it is not necessary as all CBS needs is VeeamZIP, which is included in the free version. Once installed, add any hypervisors to it that you will be backing up virtual machines (VMs) from.
* SolarWinds TFTP Server (https://www.solarwinds.com/free-tools/free-tftp-server). Once installed, create a Windows Firewall rule allowing UDP port 69 inbound (this rule can be disabled).
* Microsoft IIS. Create new site in IIS pointing to the Dashboard folder inside of CBS's root directory.
* Storage media to hold the backups (at least two external hard drives are recommended).


