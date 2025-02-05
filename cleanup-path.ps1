# Spinner function
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

# Admin check
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "❌ Please run as Administrator!" -ForegroundColor Red
    pause
    exit
}

Write-Host "🚀 Starting enhanced PATH cleanup..." -ForegroundColor Cyan

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
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User') -split ';'
$sysPath = [Environment]::GetEnvironmentVariable('Path', 'Machine') -split ';'
$allPaths = @()

Write-Host "`n📦 Analyzing paths..." -ForegroundColor Green

# Function to check if path contains executables
function Test-PathForExecutables {
    param($path)
    if (Test-Path $path) {
        $exes = Get-ChildItem -Path $path -Include $devTools -File -ErrorAction SilentlyContinue
        if ($exes) {
            Write-Host "  ✓ Found $($exes.Count) tools in $path" -ForegroundColor Yellow
            $exes | ForEach-Object {
                Write-Host "    - $($_.Name)" -ForegroundColor Gray
            }
            return $true
        }
    }
    return $false
}

# Process paths
$validPaths = @()
foreach ($path in ($userPath + $sysPath | Select-Object -Unique)) {
    if ($path -and ($path.Trim())) {
        $isCritical = $criticalPaths | Where-Object { $path -like "*$_*" }
        $hasTools = Test-PathForExecutables $path
        
        if ($isCritical) {
            Write-Host "  🔒 Keeping critical path: $path" -ForegroundColor Blue
            $validPaths += $path
        }
        elseif ($hasTools) {
            Write-Host "  🛠️ Keeping dev tools path: $path" -ForegroundColor Green
            $validPaths += $path
        }
        elseif (Test-Path $path) {
            Write-Host "  ❓ Found valid but empty path: $path" -ForegroundColor Yellow
            $validPaths += $path
        }
        else {
            Write-Host "  ❌ Removing invalid path: $path" -ForegroundColor Red
        }
    }
}

# Stop spinner
Stop-Job $job
Remove-Job $job

# Split between system and user paths
$newSysPath = $validPaths | Where-Object { 
    $path = $_
    $criticalPaths | Where-Object { $path -like "*$_*" } `
    -or $path -like "C:\Program Files*" `
    -or $path -like "C:\Windows*"
}

$newUserPath = $validPaths | Where-Object { 
    $path = $_
    -not ($criticalPaths | Where-Object { $path -like "*$_*" }) `
    -and $path -notlike "C:\Windows*" `
    -and $path -notlike "C:\Program Files*"
}

# Update PATH variables
[Environment]::SetEnvironmentVariable('Path', ($newSysPath -join ';'), 'Machine')
[Environment]::SetEnvironmentVariable('Path', ($newUserPath -join ';'), 'User')

Write-Host "`n✨ Cleanup complete!" -ForegroundColor Green
Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "  System paths: $($newSysPath.Count)" -ForegroundColor Blue
Write-Host "  User paths: $($newUserPath.Count)" -ForegroundColor Blue
Write-Host "`n🔄 Please restart your terminal to apply changes." -ForegroundColor Yellow

pause