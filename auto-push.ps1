$repoPath = "D:\Copy of Website thiết kế thiệp online"
$logFile = Join-Path $repoPath "auto-push.log"
$debounceSeconds = 15

function Write-Log($msg) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $msg" | Out-File -FilePath $logFile -Append -Encoding utf8
}

Set-Location $repoPath

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repoPath
$watcher.IncludeSubdirectories = $true
$watcher.Filter = "*.*"
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, DirectoryName, Size'
$watcher.EnableRaisingEvents = $true

$global:lastChange = Get-Date

$action = {
    $path = $Event.SourceEventArgs.FullPath
    if ($path -notmatch '\\\.git(\\|$)' -and $path -notmatch '\\auto-push\.(ps1|log)$') {
        $global:lastChange = Get-Date
    }
}

Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null
Register-ObjectEvent $watcher "Deleted" -Action $action | Out-Null
Register-ObjectEvent $watcher "Renamed" -Action $action | Out-Null

Write-Log "Auto-push watcher started."

while ($true) {
    Start-Sleep -Seconds 5
    if ($global:lastChange -and ((Get-Date) - $global:lastChange).TotalSeconds -ge $debounceSeconds) {
        $global:lastChange = $null
        Set-Location $repoPath
        git add -A *> $null
        $status = git status --porcelain
        if ($status) {
            $msg = "Auto-update " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            cmd /c "git commit -m `"$msg`" >> `"$logFile`" 2>&1"
            cmd /c "git pull --rebase --autostash >> `"$logFile`" 2>&1"
            cmd /c "git push >> `"$logFile`" 2>&1"
            Write-Log "Pushed changes."
        }
    }
}
