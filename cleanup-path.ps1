param(
    [switch]$WhatIf
)

# Spinner function for visual feedback
function Show-Spinner {
    param([string]$Message)
    $spinChars = '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'
    $i = 0
    Write-Host "`r$Message " -NoNewline
    while ($true) {
        Write-Host "`r$Message $($spinChars[$i])" -NoNewline
        Start-Sleep -Milliseconds 100
        $i = ($i + 1) % $spinChars.Length
    }
}

# Create backup with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupFile = "path_backup_$timestamp.txt"

# Backup current paths
"USER PATH:" | Out-File $backupFile
[Environment]::GetEnvironmentVariable('Path', 'User') | Out-File $backupFile -Append
"SYSTEM PATH:" | Out-File $backupFile -Append
[Environment]::GetEnvironmentVariable('Path', 'Machine') | Out-File $backupFile -Append

# Verify backup was created
$backupContent = Get-Content $backupFile -ErrorAction SilentlyContinue
if (-not $backupContent) {
    Write-Host "Failed to create backup. Aborting for safety." -ForegroundColor Red
    exit
}

Write-Host "Backed up current paths to $backupFile" -ForegroundColor Green

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Please run as Administrator!" -ForegroundColor Red
    pause
    exit
}

Write-Host "Starting enhanced PATH cleanup..." -ForegroundColor Cyan

# Critical Windows paths that should never be removed
$criticalPaths = @(
    "\Microsoft\WindowsApps",
    "\Windows",
    "\Windows\system32",
    "\Windows\System32\Wbem",
    "\Windows\System32\WindowsPowerShell",
    "\Windows\System32\OpenSSH"
)

# Known dev tool executables
$devTools = @(
    "node.exe", "npm.cmd", "pnpm.cmd", "yarn.cmd",
    "git.exe", "code.cmd", "python.exe", "pip.exe",
    "tsc.cmd", "eslint.cmd", "jest.cmd", "next.cmd",
    "react-scripts.cmd", "vite.cmd", "cargo.exe",
    "rustc.exe", "java.exe", "javac.exe", "mvn.cmd",
    "docker.exe", "docker-compose.exe", "kubectl.exe",
    "fnm.exe", "winget.exe", "scoop.cmd"
)

# Start spinner in background job
$job = Start-Job -ScriptBlock {
    param($msg)
    . {
        function Show-Spinner {
            param([string]$Message)
            $spinChars = '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'
            $i = 0
            while ($true) {
                Write-Host "`r$Message $($spinChars[$i])" -NoNewline
                Start-Sleep -Milliseconds 100
                $i = ($i + 1) % $spinChars.Length
            }
        }
    }
    Show-Spinner $msg
} -ArgumentList "Scanning system..."

# Get current paths
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ }
$sysPath = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';' | Where-Object { $_ }

Write-Host "Analyzing paths..." -ForegroundColor Green

# Function to check if path contains executables
function Test-PathForExecutables {
    param($path)
    if (Test-Path $path) {
        $exes = Get-ChildItem -Path $path -Include $devTools -File -ErrorAction SilentlyContinue
        if ($exes) {
            Write-Host "Found $($exes.Count) tools in $path" -ForegroundColor Yellow
            $exes | ForEach-Object {
                Write-Host "    - $($_.Name)" -ForegroundColor Gray
            }
            return $true
        }
    }
    return $false
}

# Process paths with basic validation
$validPaths = @()
foreach ($path in ($userPath + $sysPath | Select-Object -Unique)) {
    if ($path -and ($path.Trim())) {
        # Basic path validation
        if ($path.Length -le 3 -or $path.Contains(';;')) {
            Write-Host "Skipping invalid path format: $path" -ForegroundColor Yellow
            continue
        }

        $path = $path.TrimEnd('\')  # Normalize path
        $isCritical = $criticalPaths | Where-Object { $path -like "*$_*" }
        $hasTools = Test-PathForExecutables $path
        
        if ($isCritical) {
            Write-Host "Keeping critical path: $path" -ForegroundColor Blue
            $validPaths += $path
        }
        elseif ($hasTools) {
            Write-Host "Keeping dev tools path: $path" -ForegroundColor Green
            $validPaths += $path
        }
        elseif (Test-Path $path) {
            Write-Host "Found valid but empty path: $path" -ForegroundColor Yellow
            $validPaths += $path
        }
        else {
            Write-Host "Removing invalid path: $path" -ForegroundColor Red
        }
    }
}

# Stop spinner
Stop-Job $job
Remove-Job $job

# Split between system and user paths with improved logic
$newSysPath = $validPaths | Where-Object { 
    $path = $_
    ($criticalPaths | Where-Object { $path -like "*$_*" }) -or 
    $path -match "^C:\\Program Files" -or 
    $path -match "^C:\\Program Files \(x86\)" -or
    $path -like "*\System32*" -or
    $path -match "^C:\\Windows"
}

$newUserPath = $validPaths | Where-Object { 
    $path = $_
    -not ($criticalPaths | Where-Object { $path -like "*$_*" }) -and
    -not ($path -match "^C:\\Program Files") -and
    -not ($path -match "^C:\\Program Files \(x86\)") -and
    -not ($path -like "*\System32*") -and
    -not ($path -match "^C:\\Windows")
}

# Ensure critical paths are present
$requiredPaths = @(
    "C:\Windows\system32",
    "C:\Windows",
    "C:\Windows\System32\Wbem"
)

$missingPaths = $requiredPaths | Where-Object {
    $required = $_
    -not ($newSysPath | Where-Object { $_ -like "*$required*" })
}

if ($missingPaths) {
    Write-Host "`nERROR: Missing critical system paths:" -ForegroundColor Red
    $missingPaths | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "Aborting for system safety." -ForegroundColor Red
    exit
}

if ($newSysPath.Count -eq 0) {
    Write-Host "`nERROR: No system paths detected. This would break Windows. Aborting." -ForegroundColor Red
    exit
}

Write-Host "`nReady to update paths. Current counts:" -ForegroundColor Cyan
Write-Host "System paths: $($newSysPath.Count)" -ForegroundColor Blue
Write-Host "User paths: $($newUserPath.Count)" -ForegroundColor Blue

# Handle WhatIf parameter
if ($WhatIf) {
    Write-Host "`nDry run - would set these paths:" -ForegroundColor Yellow
    Write-Host "`nSystem PATH:" -ForegroundColor Blue
    $newSysPath | ForEach-Object { Write-Host "  $_" }
    Write-Host "`nUser PATH:" -ForegroundColor Blue
    $newUserPath | ForEach-Object { Write-Host "  $_" }
    exit
}

$confirm = Read-Host "`nDo you want to proceed with these changes? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "`nNo changes were made. Exiting..." -ForegroundColor Yellow
    exit
}

# Update PATH variables
[Environment]::SetEnvironmentVariable('Path', ($newSysPath -join ';'), 'Machine')
[Environment]::SetEnvironmentVariable('Path', ($newUserPath -join ';'), 'User')

Write-Host "`nCleanup complete!" -ForegroundColor Green
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "System paths: $($newSysPath.Count)" -ForegroundColor Blue
Write-Host "User paths: $($newUserPath.Count)" -ForegroundColor Blue
Write-Host "`nA backup was created at: $backupFile" -ForegroundColor Yellow
Write-Host "To restore if needed, use:" -ForegroundColor Yellow
Write-Host "notepad $backupFile" -ForegroundColor Cyan
Write-Host "`nPlease restart your terminal to apply changes." -Foregroundcolor Yellow

pause