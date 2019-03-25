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
    $sourcePath = $configFile[$backupJob].SourcePath
    $netPath = $configFile[$backupJob].NetPath
    $serverInstance = $configFile[$backupJob].ServerInstance
    $database = $configFile[$backupJob].Database
    $passwordFile = $configFile[$backupJob].PasswordFile
    $userName = $configFile[$backupJob].UserName
    $encryptionKeyFile = $configFile[$backupJob].EncryptionKeyFile
    $backupFileExetnsion = $configFile[$backupJob].BackupFileExtension
    $commandList = $configFile[$backupJob].CommandList
    # Convert command list from string to array so it can be iterated through
    if ($commandList) {$cmdList = $commandList.split(",")}

    if ($backupJob -eq "No-Section") {Continue}

    # Frequency: [Hourly,top|bottom], [Daily,<hour>,top|bottom], [Weekly,<day of week>,<hour>,top|bottom]
    $dateTime = Get-Date
    $dayOfWeek = $dateTime.DayOfWeek
    $hour = $dateTime.Hour
    $minute = $dateTime.Minute

    $toBeRun = $false

    if ($frequency -like "Hourly*") {
        if ($frequency -eq "Hourly,top") {
            if ($minute -lt 30) {$toBeRun = $true}
        }
        elseif ($frequency -eq "Hourly,bottom") {
            if ($minute -gt 30) {$toBeRun = $true}
        }
        else {Throw "Error: Valid frequency value not set for backup $name."}
    }
    elseif ($frequency -like "Daily*") {
        if ($frequency -eq "Daily,$hour,top") {
            if ($minute -lt 30) {$toBeRun = $true}
        }
        elseif ($frequency -eq "Daily,$hour,bottom") {
            if ($minute -gt 30) {$toBeRun = $true}
        }
    }
    elseif ($frequency -like "Weekly*") {
        if ($frequency -eq "Weekly,$dayOfWeek,$hour,top") {
            if ($minute -lt 30) {$toBeRun = $true}
        }
        elseif ($frequency -eq "Weekly,$dayOfWeek,$hour,bottom") {
            if ($minute -gt 30) {$toBeRun = $true}
        }
    }
    else {Throw "Error: Valid frequency value not set for backup $name."}

    Write-Output "$name --------------- $frequency --------------- $toBeRun"

    #if ($toBeRun) {
        
    #}
}