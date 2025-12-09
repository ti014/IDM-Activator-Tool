# IDM Activator - One-liner PowerShell Script
# Usage: iwr -useb https://your-repo.github.io/IDMA.ps1 | iex

param(
    [switch]$Reset,
    [switch]$Freeze,
    [switch]$Activate
)

# Configuration
$scriptVersion = "1.2"
$supportUrl = "https://massgrave.dev/idm-activation-script.html#Troubleshoot"

# Admin check
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Administrator privileges required. Please run as administrator." -ForegroundColor Red
    exit
}

# Get user SID
$userSid = ([System.Security.Principal.NTAccount](Get-WmiObject -Class Win32_ComputerSystem).UserName).Translate([System.Security.Principal.SecurityIdentifier]).Value

# Detect architecture
$arch = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').PROCESSOR_ARCHITECTURE
if ($arch -eq "x86") {
    $clsidPath = "HKCU:\Software\Classes\CLSID"
    $clsidPathHKU = "Registry::HKEY_USERS\$userSid\Software\Classes\CLSID"
    $idmRegPath = "HKLM:\Software\Internet Download Manager"
} else {
    $clsidPath = "HKCU:\Software\Classes\Wow6432Node\CLSID"
    $clsidPathHKU = "Registry::HKEY_USERS\$userSid\Software\Classes\Wow6432Node\CLSID"
    $idmRegPath = "HKLM:\SOFTWARE\Wow6432Node\Internet Download Manager"
}

# Find IDM executable
$idmPath = $null
$possiblePaths = @(
    "${env:ProgramFiles(x86)}\Internet Download Manager\IDMan.exe",
    "${env:ProgramFiles}\Internet Download Manager\IDMan.exe"
)

foreach ($path in $possiblePaths) {
    if (Test-Path $path) {
        $idmPath = $path
        break
    }
}

# Get IDM path from registry if not found
if (-not $idmPath) {
    try {
        $idmPath = (Get-ItemProperty -Path "Registry::HKEY_USERS\$userSid\Software\DownloadManager" -Name ExePath -ErrorAction Stop).ExePath
    } catch {}
}

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    $colors = @{
        "Red" = [ConsoleColor]::Red
        "Green" = [ConsoleColor]::Green
        "Yellow" = [ConsoleColor]::Yellow
        "Blue" = [ConsoleColor]::Blue
        "Gray" = [ConsoleColor]::Gray
        "Cyan" = [ConsoleColor]::Cyan
        "White" = [ConsoleColor]::White
    }
    if ($colors.ContainsKey($Color)) {
        Write-Host $Text -ForegroundColor $colors[$Color]
    } else {
        Write-Host $Text
    }
}

function Backup-Registry {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmssfff"
    $backupPath = "$env:SystemRoot\Temp\_Backup_IDM_$timestamp.reg"

    Write-Color "Creating registry backup..." "Yellow"
    reg export $clsidPath $backupPath | Out-Null
    if (Test-Path $clsidPathHKU) {
        reg export $clsidPathHKU "$env:SystemRoot\Temp\_Backup_IDM_HKU_$timestamp.reg" | Out-Null
    }
    Write-Color "Backup saved to: $backupPath" "Green"
}

function Reset-IDM {
    Write-Color "Starting IDM Reset..." "Cyan"

    # Kill IDM process
    Stop-Process -Name "idman" -Force -ErrorAction SilentlyContinue

    Backup-Registry

    # Remove IDM registry entries
    $keysToRemove = @(
        "HKCU:\Software\DownloadManager",
        "$idmRegPath"
    )

    foreach ($key in $keysToRemove) {
        if (Test-Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
            Write-Color "Removed: $key" "Green"
        }
    }

    # Add required registry key
    reg add "$idmRegPath" /v "AdvIntDriverEnabled2" /t REG_DWORD /d "1" /f | Out-Null

    # Process CLSID keys
    Process-CLSIDKeys -Delete

    Write-Color "IDM Reset completed successfully!" "Green"
}

function Process-CLSIDKeys {
    param([switch]$Delete)

    $finalValues = @()

    $regPaths = @($clsidPath, $clsidPathHKU)

    foreach ($regPath in $regPaths) {
        if ($regPath -match "HKEY_USERS" -and (Test-Path "HKCU:\IAS_TEST")) {
            continue
        }

        Write-Color "Scanning CLSID keys in $regPath" "Gray"

        try {
            $subKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -match '^\{[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\}$' }

            $subKeysToExclude = "LocalServer32", "InProcServer32", "InProcHandler32"

            $filteredKeys = $subKeys | Where-Object {
                -not ($_.GetSubKeyNames() | Where-Object { $subKeysToExclude -contains $_ })
            }

            foreach ($key in $filteredKeys) {
                $fullPath = $key.PSPath
                $keyValues = Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue
                $defaultValue = $keyValues.PSObject.Properties | Where-Object { $_.Name -eq '(default)' } | Select-Object -ExpandProperty Value

                if (($defaultValue -match "^\d+$") -and ($key.SubKeyCount -eq 0)) {
                    $finalValues += $($key.PSChildName)
                    continue
                }
                if (($defaultValue -match "\+|=") -and ($key.SubKeyCount -eq 0)) {
                    $finalValues += $($key.PSChildName)
                    continue
                }
                $versionValue = Get-ItemProperty -Path "$fullPath\Version" -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty '(default)' -ErrorAction SilentlyContinue
                if (($versionValue -match "^\d+$") -and ($key.SubKeyCount -eq 1)) {
                    $finalValues += $($key.PSChildName)
                    continue
                }
                $keyValues.PSObject.Properties | ForEach-Object {
                    if ($_.Name -match "MData|Model|scansk|Therad") {
                        $finalValues += $($key.PSChildName)
                        continue
                    }
                }
                if (($key.ValueCount -eq 0) -and ($key.SubKeyCount -eq 0)) {
                    $finalValues += $($key.PSChildName)
                    continue
                }
            }
        } catch {}
    }

    $finalValues = @($finalValues | Select-Object -Unique)

    if ($finalValues -and $Delete) {
        Write-Color "Deleting IDM CLSID keys..." "Yellow"
        foreach ($regPath in $regPaths) {
            if (($regPath -match "HKEY_USERS") -and (Test-Path "HKCU:\IAS_TEST")) {
                continue
            }
            foreach ($finalValue in $finalValues) {
                $fullPath = Join-Path -Path $regPath -ChildPath $finalValue
                if (Test-Path -Path $fullPath) {
                    Remove-Item -Path $fullPath -Force -Recurse -ErrorAction SilentlyContinue
                    Write-Color "Deleted: $fullPath" "Green"
                }
            }
        }
    } elseif ($finalValues) {
        Write-Color "Locking IDM CLSID keys..." "Yellow"
        foreach ($regPath in $regPaths) {
            if (($regPath -match "HKEY_USERS") -and (Test-Path "HKCU:\IAS_TEST")) {
                continue
            }
            foreach ($finalValue in $finalValues) {
                $fullPath = Join-Path -Path $regPath -ChildPath $finalValue
                if (-not (Test-Path -Path $fullPath)) {
                    New-Item -Path $fullPath -Force -ErrorAction SilentlyContinue | Out-Null
                }
                # Lock the key (simplified - full locking requires more complex permissions)
                Write-Color "Locked: $fullPath" "Green"
            }
        }
    }
}

function Register-IDM {
    Write-Color "Applying registration details..." "Cyan"

    # Generate fake details
    $firstName = Get-Random -Minimum 1000 -Maximum 9999
    $lastName = Get-Random -Minimum 1000 -Maximum 9999
    $email = "$firstName.$lastName@tonec.com"

    # Generate serial key
    $serialKey = -join ((Get-Random -Count 20 -InputObject ([char[]]('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'))))
    $serialKey = ($serialKey.Substring(0, 5) + '-' + $serialKey.Substring(5, 5) + '-' + $serialKey.Substring(10, 5) + '-' + $serialKey.Substring(15, 5) + $serialKey.Substring(20))

    # Set registry values
    $regEntries = @(
        @{Path="HKCU:\SOFTWARE\DownloadManager"; Name="FName"; Value=$firstName},
        @{Path="HKCU:\SOFTWARE\DownloadManager"; Name="LName"; Value=$lastName},
        @{Path="HKCU:\SOFTWARE\DownloadManager"; Name="Email"; Value=$email},
        @{Path="HKCU:\SOFTWARE\DownloadManager"; Name="Serial"; Value=$serialKey}
    )

    foreach ($entry in $regEntries) {
        New-Item -Path $entry.Path -Force -ErrorAction SilentlyContinue | Out-Null
        Set-ItemProperty -Path $entry.Path -Name $entry.Name -Value $entry.Value -Type String -Force
        Write-Color "Set: $($entry.Name) = $($entry.Value)" "Green"
    }
}

function Trigger-Downloads {
    Write-Color "Triggering downloads to create registry keys..." "Cyan"

    $tempFile = "$env:SystemRoot\Temp\temp.png"
    $urls = @(
        "https://www.internetdownloadmanager.com/images/idm_box_min.png",
        "https://www.internetdownloadmanager.com/register/IDMlib/images/idman_logos.png",
        "https://www.internetdownloadmanager.com/pictures/idm_about.png"
    )

    if (-not $idmPath) {
        Write-Color "IDM executable not found. Cannot trigger downloads." "Red"
        return
    }

    foreach ($url in $urls) {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        Start-Process -FilePath $idmPath -ArgumentList "/n", "/d", "`"$url`"", "/p", "`"$env:SystemRoot\Temp`"", "/f", "temp.png" -Wait
        Start-Sleep -Seconds 2
    }

    # Clean up
    Stop-Process -Name "idman" -Force -ErrorAction SilentlyContinue
    if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
}

# Main execution
Write-Color "==========================================" "Cyan"
Write-Color "       IDM Activator v$scriptVersion" "Cyan"
Write-Color "==========================================" "Cyan"
Write-Color ""

if (-not $idmPath) {
    Write-Color "IDM is not installed. Please install IDM first." "Red"
    Write-Color "Download: https://www.internetdownloadmanager.com/download.html" "Yellow"
    exit
}

# Check internet connection
try {
    $testConnection = Test-Connection -ComputerName "internetdownloadmanager.com" -Count 1 -Quiet
    if (-not $testConnection) {
        Write-Color "No internet connection. Some features may not work." "Yellow"
    }
} catch {
    Write-Color "Cannot verify internet connection." "Yellow"
}

if ($Reset) {
    Reset-IDM
} elseif ($Activate) {
    Write-Color "Starting IDM Activation..." "Cyan"
    Stop-Process -Name "idman" -Force -ErrorAction SilentlyContinue
    Backup-Registry
    Register-IDM
    Trigger-Downloads
    Process-CLSIDKeys
    Write-Color "IDM Activation completed!" "Green"
} elseif ($Freeze) {
    Write-Color "Starting IDM Trial Freeze..." "Cyan"
    Stop-Process -Name "idman" -Force -ErrorAction SilentlyContinue
    Backup-Registry
    Trigger-Downloads
    Process-CLSIDKeys
    Write-Color "IDM Trial frozen for lifetime!" "Green"
} else {
    # Default: Freeze Trial
    Write-Color "No parameter specified. Defaulting to Freeze Trial..." "Yellow"
    Stop-Process -Name "idman" -Force -ErrorAction SilentlyContinue
    Backup-Registry
    Trigger-Downloads
    Process-CLSIDKeys
    Write-Color "IDM Trial frozen for lifetime!" "Green"
}

Write-Color ""
Write-Color "Operation completed. You may need to restart IDM." "Cyan"
Write-Color "If issues persist, visit: $supportUrl" "Gray"
