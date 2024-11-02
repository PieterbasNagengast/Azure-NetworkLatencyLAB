#  Description: This script downloads PsTools from Microsoft Sysinternals website and sets up firewall rules to allow ICMPv4 and PsPing to work.
$PsToolsUrl = "https://download.sysinternals.com/files/PSTools.zip"
$PsToolsOutputFile = "C:\temp\PSTools.zip"
$PsToolsOutputPath = "C:\temp"
$PsPingTcpPort = 1515

# download, save and extract PsTools archive from Microosft Sysinternals website
try {
    Write-Host "Checking if PsPing exists..."
    # check if PsPing exists
    if (-not (Test-Path "C:\temp\psping64.exe")) {
        Write-Host "PsPing not found, downloading..."     
        # download PsTools archive
        Invoke-WebRequest -Uri $PsToolsUrl -OutFile $PsToolsOutputFile
        write-host "PsTools downloaded" -ForegroundColor Green     
        Expand-Archive -Path $PsToolsOutputFile -DestinationPath $PsToolsOutputPath -Force
        write-host "PsTools extracted" -ForegroundColor Green
    } else {
        write-host "PsPing already exists" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error downloading PsPing" -ForegroundColor Red
    write-host $_.Exception.Message
    # exit with error code
    exit 1
}

# enable ICMPv4 on Windows Firewall
try {
    write-host "Checking ICMPv4 Firewall rule"
    $rule = Get-NetFirewallRule -Name "vm-monitoring-icmpv4" -ErrorAction SilentlyContinue
    if (-not $rule) {
        $rule | Enable-NetFirewallRule
        write-host "ICMPv4 rule enabled" -ForegroundColor Green
    } else {
        write-host "ICMPv4 rule already enabled" -ForegroundColor Green
    }
} catch {
    Write-Host "Error enabling ICMPv4 rule" -ForegroundColor Red
    write-host $_.Exception.Message
    # exit with error code
    exit 1
}

# create new firewall rule for psping64.exe
try {
    write-host "Checking PsPing Firewall rule"
    $rule = Get-NetFirewallRule -DisplayName "PsPing" -ErrorAction SilentlyContinue
    if (-not $rule) {
        New-NetFirewallRule -DisplayName "PsPing" -Direction Inbound -Program "C:\temp\psping64.exe" -Action Allow
        write-host "PsPing rule created" -ForegroundColor Green
    } else {
        write-host "PsPing rule already exists" -ForegroundColor Green
    }
    
} catch {
    Write-Host "Error creating PsPing rule" -ForegroundColor Red
    write-host $_.Exception.Message
    # exit with error code
    exit 1
}


# disable server manager to start at logon
try {
    # get server manager task state
    Write-Host "Checking Server Manager scheduled task"
    $taskState = Get-ScheduledTask -TaskName "ServerManager" -ErrorAction SilentlyContinue
    if ($taskState.state -ne "Disabled") {
        $taskState | Disable-ScheduledTask
        write-host "Server Manager disabled" -ForegroundColor Green
    } else {
        write-host "Server Manager is already disabled" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error disabling Server Manager" -ForegroundColor Red
    write-host $_.Exception.Message
    # exit with error code
    exit 1
}

# run PsPing64.exe as a scheduled task on port 1515
try {
    # get PsPing task state
    Write-Host "Checking PsPing scheduled task"
    # get IPv4 ip address
    $ipAddress = (Get-NetIPAddress | Where-Object { $_.InterfaceAlias -eq "Ethernet" -and $_.AddressFamily -eq "IPv4"}).IPAddress
    $taskState = Get-ScheduledTask -TaskName "PsPing" -ErrorAction SilentlyContinue
    if (-not $taskState) {
        $action = New-ScheduledTaskAction -Execute "C:\temp\psping64.exe" -Argument "-s $($ipAddress):$($PsPingTcpPort) -nobanner" -WorkingDirectory "C:\temp" 
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        Register-ScheduledTask -TaskName "PsPing" -Action $action -Trigger $trigger -Description "PsPing task to listen on port $PsPingTcpPort with ip address $ipAddress" -RunLevel Limited
        write-host "PsPing task created" -ForegroundColor Green
    } else {
        write-host "PsPing task already exists" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error creating PsPing task" -ForegroundColor Red
    write-host $_.Exception.Message
    # exit with error code
    exit 1
}