[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $Filter,

    [string]
    $TargetIP
)

function copy-ssh-id {
    Write-Host -ForegroundColor Green "Attempting to copy the public key to the server ($TargetIP). You must authenticate via password once."
    Get-Content "$pathToKey.pub" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR root@$TargetIP "cat >> .ssh/authorized_keys"
}

$pathToKey = "$env:USERPROFILE\.ssh\archinstall-temp"
if (!(Test-Path "$pathToKey") -and !(Test-Path "$pathToKey.pub")) {
    Write-Warning "No key found on this machine. Creating a new one."
    ssh-keygen -t ed25519 -C "archinstall-temp" -f $pathToKey -N "" -q
    copy-ssh-id
}

$process = Start-Process ssh -ArgumentList "-i $pathToKey -o LogLevel=ERROR -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$TargetIP exit" -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0) {
    copy-ssh-id
}


# specify the path to the folder you want to monitor:
$Path = $PSScriptRoot

# specify which files you want to monitor
$FileFilter = $Filter

# specify whether you want to monitor subfolders as well:
# $IncludeSubfolders = $true

# specify the file or folder properties you want to monitor:
$AttributeFilter = [IO.NotifyFilters]::LastWrite 

# specify the type of changes you want to monitor:
$ChangeTypes = [System.IO.WatcherChangeTypes]::Changed

# specify the maximum time (in milliseconds) you want to wait for changes:
$Timeout = 500

# define a function that gets called for every change:
function Invoke-SomeAction {
    param
    (
        [Parameter(Mandatory)]
        [System.IO.WaitForChangedResult]
        $ChangeInformation
    )
  
    Write-Host -ForegroundColor Blue "File $($ChangeInformation.Name) changed. Copying it to root@$TargetIP..."
    scp -o LogLevel=ERROR -i $pathToKey -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$PSScriptRoot\$($ChangeInformation.Name)" "root@$($TargetIP):~/"
    ssh -o LogLevel=ERROR -i $pathToKey -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$TargetIP "chmod u+x ~/$($ChangeInformation.Name)"
}

# use a try...finally construct to release the
# filesystemwatcher once the loop is aborted
# by pressing CTRL+C

try {
    Write-Warning "FileSystemWatcher is monitoring $Path"
  
    # create a filesystemwatcher object
    $watcher = New-Object -TypeName IO.FileSystemWatcher -ArgumentList $Path, $FileFilter -Property @{
        #IncludeSubdirectories = $IncludeSubfolders
        NotifyFilter = $AttributeFilter
    }

    # start monitoring manually in a loop:
    do {
        # wait for changes for the specified timeout
        # IMPORTANT: while the watcher is active, PowerShell cannot be stopped
        # so it is recommended to use a timeout of 1000ms and repeat the
        # monitoring in a loop. This way, you have the chance to abort the
        # script every second.
        $result = $watcher.WaitForChanged($ChangeTypes, $Timeout)
        # if there was a timeout, continue monitoring:
        if ($result.TimedOut) { continue }
    
        Invoke-SomeAction -Change $result
        # the loop runs forever until you hit CTRL+C    
    } while ($true)
} finally {
    # release the watcher and free its memory:
    $watcher.Dispose()
    Write-Warning 'FileSystemWatcher removed.'
}
