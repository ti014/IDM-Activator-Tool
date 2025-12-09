@set scriptVersion=1.2
@setlocal DisableDelayedExpansion
@echo off

::========================================================================================================================================
:: SCRIPT CONFIGURATION - These variables control script behavior
::========================================================================================================================================

:: Activation flags - set to 1 to enable or use command line parameters /act, /frz, /res
set shouldActivate=0
set shouldFreeze=0
set shouldReset=0

::========================================================================================================================================
:: MAIN SCRIPT EXECUTION
::========================================================================================================================================

call :initializeEnvironment
call :parseCommandLineArguments
call :validateSystemRequirements
call :setupScriptEnvironment
call :checkForUpdates
call :validatePowerShellAndPrivileges
call :configureConsoleSettings
call :initializeSystemComponents
call :setupRegistryConfiguration
call :routeToOperation
goto :cleanupAndExit

::========================================================================================================================================
:: ENVIRONMENT INITIALIZATION
::========================================================================================================================================

:initializeEnvironment
:: Purpose: Setup essential environment variables and path configuration
:: This ensures the script works correctly even with misconfigured system paths

set "PATH=%SystemRoot%\System32;%SystemRoot%\System32\wbem;%SystemRoot%\System32\WindowsPowerShell\v1.0\"
if exist "%SystemRoot%\Sysnative\reg.exe" (
    set "PATH=%SystemRoot%\Sysnative;%SystemRoot%\Sysnative\wbem;%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\;%PATH%"
)

:: Handle architecture-specific process relaunching for compatibility
set "scriptCommand=%~f0"
for %%# in (%*) do (
    if /i "%%#"=="r1" set relaunchFlagX64=1
    if /i "%%#"=="r2" set relaunchFlagARM=1
)

:: Relaunch with x64 process if started from x86 on x64 Windows
if exist %SystemRoot%\Sysnative\cmd.exe if not defined relaunchFlagX64 (
    setlocal EnableDelayedExpansion
    start %SystemRoot%\Sysnative\cmd.exe /c ""!scriptCommand!" %* r1"
    exit /b
)

:: Relaunch with ARM32 process if started from x64 on ARM64 Windows
if exist %SystemRoot%\SysArm32\cmd.exe if %PROCESSOR_ARCHITECTURE%==AMD64 if not defined relaunchFlagARM (
    setlocal EnableDelayedExpansion
    start %SystemRoot%\SysArm32\cmd.exe /c ""!scriptCommand!" %* r2"
    exit /b
)

goto :eof

::========================================================================================================================================
:: COMMAND LINE ARGUMENT PARSING
::========================================================================================================================================

:parseCommandLineArguments
:: Purpose: Parse and validate command line arguments for unattended operation

set commandLineArgs=%*
if defined commandLineArgs set commandLineArgs=%commandLineArgs:"=%
if defined commandLineArgs (
    for %%A in (%commandLineArgs%) do (
        if /i "%%A"=="-el"  set elevatedMode=1
        if /i "%%A"=="/res" set shouldReset=1
        if /i "%%A"=="/frz" set shouldFreeze=1
        if /i "%%A"=="/act" set shouldActivate=1
    )
)

:: Determine if running in unattended mode
set unattendedMode=0
for %%A in (%shouldActivate% %shouldFreeze% %shouldReset%) do (
    if "%%A"=="1" set unattendedMode=1
)

goto :eof

::========================================================================================================================================
:: SYSTEM REQUIREMENTS VALIDATION
::========================================================================================================================================

:validateSystemRequirements
:: Purpose: Ensure the system meets minimum requirements for script execution

set "blankChar="
set "supportUrl=ht%blankChar%tps%blankChar%://mass%blankChar%grave.dev/"

:: Verify Null service is running (critical for batch script stability)
sc query Null | find /i "RUNNING" >nul 2>&1
if %errorlevel% NEQ 0 (
    echo:
    echo Null service is not running, script may crash...
    echo:
    echo Help: %supportUrl%idm-activation-script.html#Troubleshoot
    echo:
    ping 127.0.0.1 -n 10 >nul
)

:: Validate script file integrity (check for proper line endings)
pushd "%~dp0"
:: Check if file ends with newline by checking last character
for %%F in ("%~nx0") do set "fileSize=%%~zF"
if %fileSize% LEQ 0 (
    echo:
    echo Error: Script file is empty.
    echo:
    ping 127.0.0.1 -n 6 >nul
    popd
    exit /b
)
popd

:: Check Windows version compatibility
set windowsBuild=1
for /f "tokens=6 delims=[]. " %%G in ('ver') do set windowsBuild=%%G

if %windowsBuild% LSS 7600 (
    echo:
    echo ==== ERROR ====
    echo Unsupported Windows version detected: %windowsBuild%
    echo Script requires Windows 7/8/8.1/10/11 or Server equivalents.
    goto :exitWithError
)

:: Verify PowerShell availability
for %%# in (powershell.exe) do @if "%%~$PATH:#"=="" (
    echo:
    echo ==== ERROR ====
    echo PowerShell executable not found in system PATH.
    goto :exitWithError
)

goto :eof

::========================================================================================================================================
:: SCRIPT ENVIRONMENT SETUP
::========================================================================================================================================

:setupScriptEnvironment
:: Purpose: Configure script runtime environment and UI settings

cls
color 07
title IDM Activation Script %scriptVersion%

:: Setup output redirection variables for cleaner execution
set "redirectToNull1=1>nul"
set "redirectToNull2=2>nul"
set "redirectToNull6=2^>nul"
set "redirectAllToNull=>nul 2>&1"

set powershellExecutable=powershell.exe

:: Configure console color support based on Windows version
set colorSupportEnabled=1
if %windowsBuild% LSS 10586 set colorSupportEnabled=0
if %windowsBuild% GEQ 10586 (
    reg query "HKCU\Console" /v ForceV2 %redirectToNull2% | find /i "0x0" %redirectToNull1% && (set colorSupportEnabled=0)
)

if %colorSupportEnabled% EQU 1 (
    for /F %%a in ('echo prompt $E ^| cmd') do set "escapeSequence=%%a"
    set "colorRed=41;97m"
    set "colorGray=100;97m"
    set "colorGreen=42;97m"
    set "colorBlue=44;97m"
    set "colorWhite=40;37m"
    set "colorBrightGreen=40;92m"
    set "colorYellow=40;93m"
    set "colorBrightRed=40;91m"
    set "colorCyan=40;96m"
) else (
    set "colorRed=Red" "white""
    set "colorGray=Darkgray" "white""
    set "colorGreen=DarkGreen" "white""
    set "colorBlue=Blue" "white""
    set "colorWhite=Black" "Gray""
    set "colorBrightGreen=Black" "Green""
    set "colorYellow=Black" "Yellow""
    set "colorBrightRed=Black" "Red""
    set "colorCyan=Black" "Cyan""
)

set "errorLine=echo: &echo ==== ERROR ==== &echo:"
set "errorLineColored=echo: &call :displayColoredText %colorRed% "==== ERROR ====" &echo:"
set "separatorLine=___________________________________________________________________________________________________"
set "consoleBufferConfig={$W=$Host.UI.RawUI.WindowSize;$B=$Host.UI.RawUI.BufferSize;$W.Height=34;$B.Height=300;$Host.UI.RawUI.WindowSize=$W;$Host.UI.RawUI.BufferSize=$B;}"

:: Setup file and path variables
set "scriptDirectory=%~dp0"
if "%scriptDirectory:~-1%"=="\" set "scriptDirectory=%scriptDirectory:~0,-1%"

set "scriptFullPath=%~f0"
set "scriptPathForPS=%scriptFullPath:'=''%"

set powerShellArgs="""%~f0""" -el %commandLineArgs%
set powerShellArgs=%powerShellArgs:'=''%'

set "appDataDirectory=%appdata%"
set "tempDirectory=%userprofile%\AppData\Local\Temp"

setlocal EnableDelayedExpansion

:: Prevent execution from temporary directories to avoid archive extraction issues
echo "!scriptFullPath!" | find /i "!tempDirectory!" %redirectToNull1% && (
    if /i not "!scriptDirectory!"=="!tempDirectory!" (
        %errorLineColored%
        echo Script is running from temporary folder.
        echo This usually indicates execution directly from archive file.
        echo:
        echo Please extract the archive and run from extracted folder.
        goto :exitWithError
    )
)

goto :eof

::========================================================================================================================================
:: POWERSHELL VALIDATION AND PRIVILEGE CHECK
::========================================================================================================================================

:: Purpose: Validate PowerShell execution and ensure administrator privileges

:validatePowerShellAndPrivileges
REM :PowerShellTest: $ExecutionContext.SessionState.LanguageMode :PowerShellTest:

%powershellExecutable% "$f=[io.file]::ReadAllText('!scriptPathForPS!') -split ':PowerShellTest:\s*';iex ($f[1])" | find /i "FullLanguage" %redirectToNull1% || (
    %errorLineColored%
    %powershellExecutable% $ExecutionContext.SessionState.LanguageMode
    echo:
    echo PowerShell execution is restricted. Cannot continue.
    echo Remove any PowerShell restrictions that may have been applied.
    echo:
    echo Help: %supportUrl%idm-activation-script.html#Troubleshoot
    goto :exitWithError
)

%redirectToNull1% fltmc || (
    if not defined elevatedMode %powershellExecutable% "start cmd.exe -arg '/c \"!powerShellArgs!\"' -verb runas" && exit /b
    %errorLineColored%
    echo Administrator privileges required for this script.
    echo Right-click the script and select 'Run as administrator'.
    goto :exitWithError
)

goto :eof

::========================================================================================================================================
:: CONSOLE CONFIGURATION
::========================================================================================================================================

:: Purpose: Configure console settings for optimal script execution

:configureConsoleSettings
set quickEditDisabled=
set terminalMode=

if %unattendedMode%==1 (
    set quickEditDisabled=1
    set terminalMode=1
)

for %%# in (%commandLineArgs%) do (if /i "%%#"=="-qedit" set quickEditDisabled=1)

if %windowsBuild% LSS 10586 (
    reg query HKCU\Console /v QuickEdit %redirectToNull2% | find /i "0x0" %redirectToNull1% && set quickEditDisabled=1
)

if %windowsBuild% GEQ 17763 (
    set "consoleLaunchCommand=start conhost.exe %powershellExecutable%"
) else (
    set "consoleLaunchCommand=%powershellExecutable%"
)

set "quickEditDisableCode1=$t=[AppDomain]::CurrentDomain.DefineDynamicAssembly(4, 1).DefineDynamicModule(2, $False).DefineType(0);"
set "quickEditDisableCode2=$t.DefinePInvokeMethod('GetStdHandle', 'kernel32.dll', 22, 1, [IntPtr], @([Int32]), 1, 3).SetImplementationFlags(128);"
set "quickEditDisableCode3=$t.DefinePInvokeMethod('SetConsoleMode', 'kernel32.dll', 22, 1, [Boolean], @([IntPtr], [Int32]), 1, 3).SetImplementationFlags(128);"
set "quickEditDisableCode4=$k=$t.CreateType(); $b=$k::SetConsoleMode($k::GetStdHandle(-10), 0x0080);"

if defined quickEditDisabled goto :skipQuickEditDisable
%consoleLaunchCommand% "%quickEditDisableCode1% %quickEditDisableCode2% %quickEditDisableCode3% %quickEditDisableCode4% & cmd.exe '/c' '!powerShellArgs! -qedit'" &exit /b
:skipQuickEditDisable

goto :eof

::========================================================================================================================================
:: UPDATE CHECK
::========================================================================================================================================

:: Purpose: Check for newer script versions when running interactively

:checkForUpdates
set updateAvailable=
set updateCheckUrl=iasupdatecheck.mass%-%blankChar%grave.dev

for /f "delims=[] tokens=2" %%# in ('ping -4 -n 1 %updateCheckUrl%') do (
    if not [%%#]==[] (echo "%%#" | find "127.69" %redirectToNull1% && (echo "%%#" | find "127.69.%scriptVersion%" %redirectToNull1% || set updateAvailable=1))
)

if defined updateAvailable (
    echo _______________________________________________
    %errorLineColored%
    echo Outdated script version detected: %scriptVersion%
    echo _______________________________________________
    echo:
    if not %unattendedMode%==1 (
        echo [1] Download Latest Version
        echo [0] Continue with Current Version
        echo:
        call :displayColoredText %colorBrightGreen% "Select option [1,0]: "
        choice /C:10 /N
        if !errorlevel!==2 rem
        if !errorlevel!==1 (start https://github.com/Sabir555S/IDM-Activation-Script_555 & start %supportUrl%/idm-activation-script & exit /b)
    )
)

goto :eof

::========================================================================================================================================
:: SYSTEM INITIALIZATION
::========================================================================================================================================

:: Purpose: Perform final system checks and setup before main operations

:initializeSystemComponents
cls
title IDM Activation Script %scriptVersion%

echo:
echo Initializing system components...

:: Verify WMI service functionality
%powershellExecutable% "Get-WmiObject -Class Win32_ComputerSystem | Select-Object -Property CreationClassName" %redirectToNull2% | find /i "computersystem" %redirectToNull1% || (
    %errorLineColored%
    %powershellExecutable% "Get-WmiObject -Class Win32_ComputerSystem | Select-Object -Property CreationClassName"
    echo:
    echo WMI service is not functioning properly.
    echo:
    echo Help: %supportUrl%idm-activation-script.html#Troubleshoot
    goto :exitWithError
)

:: Retrieve and validate user account SID
set userAccountSid=
for /f "delims=" %%a in ('%powershellExecutable% "([System.Security.Principal.NTAccount](Get-WmiObject -Class Win32_ComputerSystem).UserName).Translate([System.Security.Principal.SecurityIdentifier]).Value" %redirectToNull6%') do (set userAccountSid=%%a)

reg query HKU\%userAccountSid%\Software %redirectAllToNull% || (
    for /f "delims=" %%a in ('%powershellExecutable% "$explorerProc = Get-Process -Name explorer | Where-Object {$_.SessionId -eq (Get-Process -Id $pid).SessionId} | Select-Object -First 1; $sid = (gwmi -Query ('Select * From Win32_Process Where ProcessID=' + $explorerProc.Id)).GetOwnerSid().Sid; $sid" %redirectToNull6%') do (set userAccountSid=%%a)
)

reg query HKU\%userAccountSid%\Software %redirectAllToNull% || (
    %errorLineColored%
    echo:
    echo [%userAccountSid%]
    echo Unable to determine user account SID.
    echo:
    echo Help: %supportUrl%idm-activation-script.html#Troubleshoot
    goto :exitWithError
)

goto :eof

::========================================================================================================================================
:: REGISTRY CONFIGURATION
::========================================================================================================================================

:: Purpose: Setup registry paths and validate access based on system architecture

:setupRegistryConfiguration
:: Check if HKCU registry entries sync with HKU entries for the current user
%redirectAllToNull% reg delete HKCU\IAS_TEST /f
%redirectAllToNull% reg delete HKU\%userAccountSid%\IAS_TEST /f

set hkcuRegistrySync=$null
%redirectAllToNull% reg add HKCU\IAS_TEST
%redirectAllToNull% reg query HKU\%userAccountSid%\IAS_TEST && (
    set hkcuRegistrySync=1
)

%redirectAllToNull% reg delete HKCU\IAS_TEST /f
%redirectAllToNull% reg delete HKU\%userAccountSid%\IAS_TEST /f

:: Determine system architecture (works with ARM64 Windows including x64 emulation)
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE') do set systemArchitecture=%%b
if /i not "%systemArchitecture%"=="x86" set systemArchitecture=x64

if "%systemArchitecture%"=="x86" (
    set "clsidRegistryPath=HKCU\Software\Classes\CLSID"
    set "clsidRegistryPathHKU=HKU\%userAccountSid%\Software\Classes\CLSID"
    set "idmRegistryPath=HKLM\Software\Internet Download Manager"
) else (
    set "clsidRegistryPath=HKCU\Software\Classes\Wow6432Node\CLSID"
    set "clsidRegistryPathHKU=HKU\%userAccountSid%\Software\Classes\Wow6432Node\CLSID"
    set "idmRegistryPath=HKLM\SOFTWARE\Wow6432Node\Internet Download Manager"
)

:: Locate IDM executable path
for /f "tokens=2*" %%a in ('reg query "HKU\%userAccountSid%\Software\DownloadManager" /v ExePath %redirectToNull6%') do call set "idmExecutablePath=%%b"

if not exist "%idmExecutablePath%" (
    if %systemArchitecture%==x64 set "idmExecutablePath=%ProgramFiles(x86)%\Internet Download Manager\IDMan.exe"
    if %systemArchitecture%==x86 set "idmExecutablePath=%ProgramFiles%\Internet Download Manager\IDMan.exe"
)

:: Ensure temp directory exists and setup IDM process check
if not exist %SystemRoot%\Temp md %SystemRoot%\Temp
set "idmProcessCheck=tasklist /fi "imagename eq idman.exe" | findstr /i "idman.exe" %redirectToNull1%"

:: Validate registry write access for HKU CLSID path
%redirectAllToNull% reg add %clsidRegistryPathHKU%\IAS_TEST
%redirectAllToNull% reg query %clsidRegistryPathHKU%\IAS_TEST || (
    %errorLineColored%
    echo Registry write access denied for %clsidRegistryPathHKU%
    echo:
    echo Help: %supportUrl%idm-activation-script.html#Troubleshoot
    goto :exitWithError
)

%redirectAllToNull% reg delete %clsidRegistryPathHKU%\IAS_TEST /f

goto :eof

::========================================================================================================================================
:: MAIN MENU DISPLAY
::========================================================================================================================================

:: Purpose: Display interactive menu and handle user selections

:displayMainMenu
cls
title IDM Activation Script %scriptVersion%
if not defined terminalMode mode 75, 28

echo:
echo:
echo             =====================================================
echo:
call :displayColoredText2 %colorWhite% "                              " %colorBrightRed% "INNO CYBER"
echo:
call :displayColoredText2 %colorWhite% "                         " %colorCyan% "Version: %scriptVersion%  -  Date: Dec 2025"
echo:
echo             =====================================================
echo:
echo:                This script is NOT working with latest IDM.
echo:            ___________________________________________________
echo:
echo:               [1] Freeze Trial
echo:               [2] Activate
echo:               [3] Reset Activation / Trial
echo:               _____________________________________________
echo:
echo:               [4] Download IDM
echo:               [5] Help
echo:               [0] Exit
echo:            ___________________________________________________
echo:
call :displayColoredText2 %colorWhite% "                             " %colorYellow% "~ M.Sabir Ali ~"
echo:
call :displayColoredText2 %colorWhite% "             " %colorBrightGreen% "Enter a menu option in the Keyboard [1,2,3,4,5,0]"
choice /C:123450 /N
set userMenuChoice=%errorlevel%

if %userMenuChoice%==6 exit /b
if %userMenuChoice%==5 start https://github.com/Sabir555S/IDM-Activation-Script_555 & start http://innocyber.free.nf/ & goto displayMainMenu
if %userMenuChoice%==4 start https://www.internetdownloadmanager.com/download.html & goto displayMainMenu
if %userMenuChoice%==3 goto performResetOperation
if %userMenuChoice%==2 (set freezeTrialMode=0&goto performActivationOperation)
if %userMenuChoice%==1 (set freezeTrialMode=1&goto performActivationOperation)
goto displayMainMenu

::========================================================================================================================================
:: OPERATION ROUTING
::========================================================================================================================================

:: Purpose: Route to appropriate operations based on configuration or menu selection

:routeToOperation
if %shouldReset%==1 goto performResetOperation
if %shouldActivate%==1 (set freezeTrialMode=0&goto performActivationOperation)
if %shouldFreeze%==1 (set freezeTrialMode=1&goto performActivationOperation)
goto displayMainMenu

goto :eof

::========================================================================================================================================
:: RESET OPERATION
::========================================================================================================================================

:: Purpose: Reset IDM activation and trial status

:performResetOperation
cls
if not %hkcuRegistrySync%==1 (
    if not defined terminalMode mode 153, 35
) else (
    if not defined terminalMode mode 113, 35
)
if not defined terminalMode %powershellExecutable% "&%consoleBufferConfig%" %redirectToNull%

echo:
%idmProcessCheck% && taskkill /f /im idman.exe

call :createRegistryBackup
call :cleanupIdmRegistryEntries
call :scanAndProcessClsidKeys delete
call :addRequiredRegistryKey

echo:
echo %separatorLine%
echo:
call :displayColoredText %colorGreen% "IDM reset operation completed successfully."

goto :operationCompleted

::========================================================================================================================================
:: REGISTRY BACKUP CREATION
::========================================================================================================================================

:: Purpose: Create timestamped backup of CLSID registry keys before modification

:createRegistryBackup
set timestamp=
for /f %%a in ('%powershellExecutable% "(Get-Date).ToString('yyyyMMdd-HHmmssfff')"') do set timestamp=%%a

echo:
echo Creating backup of CLSID registry keys in %SystemRoot%\Temp

reg export %clsidRegistryPath% "%SystemRoot%\Temp\_Backup_HKCU_CLSID_%timestamp%.reg"
if not %hkcuRegistrySync%==1 reg export %clsidRegistryPathHKU% "%SystemRoot%\Temp\_Backup_HKU-%userAccountSid%_CLSID_%timestamp%.reg"

goto :eof

::========================================================================================================================================
:: IDM REGISTRY CLEANUP
::========================================================================================================================================

:: Purpose: Remove IDM-related registry entries from both HKCU and HKU

:cleanupIdmRegistryEntries
echo:
echo Removing IDM registry entries...
echo:

set "registryKeysToDelete[0]="HKCU\Software\DownloadManager" "/v" "FName""
set "registryKeysToDelete[1]="HKCU\Software\DownloadManager" "/v" "LName""
set "registryKeysToDelete[2]="HKCU\Software\DownloadManager" "/v" "Email""
set "registryKeysToDelete[3]="HKCU\Software\DownloadManager" "/v" "Serial""
set "registryKeysToDelete[4]="HKCU\Software\DownloadManager" "/v" "scansk""
set "registryKeysToDelete[5]="HKCU\Software\DownloadManager" "/v" "tvfrdt""
set "registryKeysToDelete[6]="HKCU\Software\DownloadManager" "/v" "radxcnt""
set "registryKeysToDelete[7]="HKCU\Software\DownloadManager" "/v" "LstCheck""
set "registryKeysToDelete[8]="HKCU\Software\DownloadManager" "/v" "ptrk_scdt""
set "registryKeysToDelete[9]="HKCU\Software\DownloadManager" "/v" "LastCheckQU""
set "registryKeysToDelete[10]="%idmRegistryPath%""

for /l %%i in (0,1,10) do (
    for /f "tokens=* delims=" %%A in ("!registryKeysToDelete[%%i]!") do (
        set "currentRegKey="%%~A""
        reg query !currentRegKey! %redirectAllToNull% && call :deleteRegistryValue
    )
)

if not %hkcuRegistrySync%==1 (
    set "hkuKeysToDelete[0]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "FName""
    set "hkuKeysToDelete[1]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "LName""
    set "hkuKeysToDelete[2]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "Email""
    set "hkuKeysToDelete[3]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "Serial""
    set "hkuKeysToDelete[4]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "scansk""
    set "hkuKeysToDelete[5]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "tvfrdt""
    set "hkuKeysToDelete[6]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "radxcnt""
    set "hkuKeysToDelete[7]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "LstCheck""
    set "hkuKeysToDelete[8]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "ptrk_scdt""
    set "hkuKeysToDelete[9]="HKU\%userAccountSid%\Software\DownloadManager" "/v" "LastCheckQU""

    for /l %%i in (0,1,9) do (
        for /f "tokens=* delims=" %%A in ("!hkuKeysToDelete[%%i]!") do (
            set "currentRegKey="%%~A""
            reg query !currentRegKey! %redirectAllToNull% && call :deleteRegistryValue
        )
    )
)

goto :eof

::========================================================================================================================================
:: REGISTRY VALUE DELETION HELPER
::========================================================================================================================================

:: Purpose: Delete a specific registry value and report the result

:deleteRegistryValue
reg delete %currentRegKey% /f %redirectToNull%

if "%errorlevel%"=="0" (
    set "reg=%currentRegKey:"=%
    echo Deleted - !reg!
) else (
    set "reg=%currentRegKey:"=%
    call :displayColoredText2 %colorRed% "Failed - !reg!"
)

goto :eof

::========================================================================================================================================


::========================================================================================================================================

::========================================================================================================================================
:: ACTIVATION OPERATION
::========================================================================================================================================

:: Purpose: Activate or freeze IDM trial based on user selection

:performActivationOperation
cls
if not %hkcuRegistrySync%==1 (
    if not defined terminalMode mode 153, 35
) else (
    if not defined terminalMode mode 113, 35
)
if not defined terminalMode %powershellExecutable% "&%consoleBufferConfig%" %redirectToNull%

call :showActivationWarning
call :verifyIdmInstallation
call :checkInternetConnectivity
call :displaySystemInformation
call :createRegistryBackup
call :cleanupIdmRegistryEntries
call :addRequiredRegistryKey
call :scanAndProcessClsidKeys lock

if %freezeTrialMode%==0 call :registerIdmWithFakeDetails

call :triggerIdmDownloads
if not defined fileDownloadSuccessful (
    %errorLineColored%
    echo IDM download test failed.
    echo:
    echo Help: %supportUrl%idm-activation-script.html#Troubleshoot
    goto :operationCompleted
)

call :scanAndProcessClsidKeys lock

echo:
echo %separatorLine%
echo:
if %freezeTrialMode%==0 (
    call :displayColoredText %colorGreen% "IDM activation completed successfully."
    echo:
    call :displayColoredText %colorGray% "If fake serial screen appears, use Freeze Trial option instead."
) else (
    call :displayColoredText %colorGreen% "IDM 30-day trial period frozen for lifetime."
    echo:
    call :displayColoredText %colorGray% "If registration popup appears, reinstall IDM."
)

goto :operationCompleted

::========================================================================================================================================
:: ACTIVATION WARNING DISPLAY
::========================================================================================================================================

:: Purpose: Show activation warning and get user confirmation for non-trial operations

:showActivationWarning
if %freezeTrialMode%==0 if %unattendedMode%==0 (
    echo:
    echo %separatorLine%
    echo:
    echo      Activation may not work for all users and may show fake serial nag screen.
    echo:
    call :displayColoredText2 %colorWhite% "     " %colorBrightGreen% "Freeze Trial option is recommended instead."
    echo %separatorLine%
    echo:
    choice /C:19 /N /M ">    [1] Go Back [9] Activate : "
    if !errorlevel!==1 goto displayMainMenu
    cls
)

goto :eof

::========================================================================================================================================
:: IDM INSTALLATION VERIFICATION
::========================================================================================================================================

:: Purpose: Ensure IDM is installed before attempting activation

:verifyIdmInstallation
echo:
if not exist "%idmExecutablePath%" (
    call :displayColoredText %colorBrightRed% "IDM [Internet Download Manager] is not installed."
    echo Download from: https://www.internetdownloadmanager.com/download.html
    goto :operationCompleted
)

goto :eof

::========================================================================================================================================
:: INTERNET CONNECTIVITY CHECK
::========================================================================================================================================

:: Purpose: Verify internet connection to IDM servers

:checkInternetConnectivity
set internetConnectionAvailable=
for /f "delims=[] tokens=2" %%# in ('ping -n 1 internetdownloadmanager.com') do (if not [%%#]==[] set internetConnectionAvailable=1)

if not defined internetConnectionAvailable (
    %powershellExecutable% "$t = New-Object Net.Sockets.TcpClient;try{$t.Connect('internetdownloadmanager.com', 80)}catch{};$t.Connected" | findstr /i "true" %redirectToNull1% || (
        call :displayColoredText %colorBrightRed% "Cannot connect to internetdownloadmanager.com, aborting..."
        goto :operationCompleted
    )
    call :displayColoredText %colorGray% "Ping failed for internetdownloadmanager.com"
    echo:
)

goto :eof

::========================================================================================================================================
:: SYSTEM INFORMATION DISPLAY
::========================================================================================================================================

:: Purpose: Display system and IDM version information for debugging

:displaySystemInformation
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul') do set "windowsProductName=%%b"
for /f "skip=2 tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PROCESSOR_ARCHITECTURE') do set "processorArchitecture=%%b"
for /f "tokens=6-7 delims=[]. " %%i in ('ver') do if "%%j"=="" (set windowsBuildNumber=%%i) else (set windowsBuildNumber=%%i.%%j)
for /f "tokens=2*" %%a in ('reg query "HKU\%userAccountSid%\Software\DownloadManager" /v idmvers %redirectToNull6%') do set "idmVersion=%%b"

echo System Info - [%windowsProductName% ^| %windowsBuildNumber% ^| %processorArchitecture% ^| IDM: %idmVersion%]

%idmProcessCheck% && (echo: & taskkill /f /im idman.exe)

goto :eof

::========================================================================================================================================

::========================================================================================================================================
:: OPERATION COMPLETION HANDLER
::========================================================================================================================================

:: Purpose: Handle completion of operations and user interaction

:operationCompleted

echo %separatorLine%
echo:
echo:
if %unattendedMode%==1 timeout /t 2 & exit /b

if defined terminalMode (
    call :displayColoredText %colorYellow% "Press 0 to return..."
    choice /c 0 /n
) else (
    call :displayColoredText %colorYellow% "Press any key to return..."
    pause %redirectToNull1%
)
goto displayMainMenu

::========================================================================================================================================
:: ERROR EXIT HANDLER
::========================================================================================================================================

:: Purpose: Handle script termination with error

:exitWithError
if %unattendedMode%==1 timeout /t 2 & exit /b

if defined terminalMode (
    echo Press 0 to exit...
    choice /c 0 /n
) else (
    echo Press any key to exit...
    pause %redirectToNull1%
)
exit /b

::========================================================================================================================================
:: SCRIPT CLEANUP AND EXIT
::========================================================================================================================================

:: Purpose: Final cleanup before script termination

:cleanupAndExit
:: Any final cleanup operations would go here
exit /b

::========================================================================================================================================
:: COLORED TEXT DISPLAY FUNCTIONS
::========================================================================================================================================

:: Purpose: Display colored text in console

:displayColoredText
if %colorSupportEnabled% EQU 1 (
    echo %escapeSequence%[%~1%~2%escapeSequence%[0m
) else (
    %powershellExecutable% write-host -back '%1' -fore '%2' '%3'
)
goto :eof

:displayColoredText2
if %colorSupportEnabled% EQU 1 (
    echo %escapeSequence%[%~1%~2%escapeSequence%[%~3%~4%escapeSequence%[0m
) else (
    %powershellExecutable% write-host -back '%1' -fore '%2' '%3' -NoNewline; write-host -back '%4' -fore '%5' '%6'
)
goto :eof

::========================================================================================================================================
:: IDM REGISTRATION WITH FAKE DETAILS
::========================================================================================================================================

:: Purpose: Register IDM with randomly generated fake user details and serial

:registerIdmWithFakeDetails
echo:
echo Applying fake registration details...
echo:

set /a fakeFirstName = %random% %% 9999 + 1000
set /a fakeLastName = %random% %% 9999 + 1000
set fakeEmail=%fakeFirstName%.%fakeLastName%@tonec.com

for /f "delims=" %%a in ('%powershellExecutable% "$key = -join ((Get-Random -Count  20 -InputObject ([char[]]('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'))));$key = ($key.Substring(0,  5) + '-' + $key.Substring(5,  5) + '-' + $key.Substring(10,  5) + '-' + $key.Substring(15,  5) + $key.Substring(20));Write-Output $key" %redirectToNull6%') do (set fakeSerialKey=%%a)

set "registryEntry=HKCU\SOFTWARE\DownloadManager /v FName /t REG_SZ /d "%fakeFirstName%"" & call :addRegistryEntry
set "registryEntry=HKCU\SOFTWARE\DownloadManager /v LName /t REG_SZ /d "%fakeLastName%"" & call :addRegistryEntry
set "registryEntry=HKCU\SOFTWARE\DownloadManager /v Email /t REG_SZ /d "%fakeEmail%"" & call :addRegistryEntry
set "registryEntry=HKCU\SOFTWARE\DownloadManager /v Serial /t REG_SZ /d "%fakeSerialKey%"" & call :addRegistryEntry

if not %hkcuRegistrySync%==1 (
    set "registryEntry=HKU\%userAccountSid%\SOFTWARE\DownloadManager /v FName /t REG_SZ /d "%fakeFirstName%"" & call :addRegistryEntry
    set "registryEntry=HKU\%userAccountSid%\SOFTWARE\DownloadManager /v LName /t REG_SZ /d "%fakeLastName%"" & call :addRegistryEntry
    set "registryEntry=HKU\%userAccountSid%\SOFTWARE\DownloadManager /v Email /t REG_SZ /d "%fakeEmail%"" & call :addRegistryEntry
    set "registryEntry=HKU\%userAccountSid%\SOFTWARE\DownloadManager /v Serial /t REG_SZ /d "%fakeSerialKey%"" & call :addRegistryEntry
)

goto :eof

::========================================================================================================================================
:: IDM DOWNLOAD TRIGGERING
::========================================================================================================================================

:: Purpose: Trigger downloads through IDM to create necessary registry keys

:triggerIdmDownloads
echo:
echo Triggering downloads to create required registry keys, please wait...
echo:

set "tempDownloadFile=%SystemRoot%\Temp\temp.png"
set fileDownloadSuccessful=

set downloadUrl=https://www.internetdownloadmanager.com/images/idm_box_min.png
call :performIdmDownload
set downloadUrl=https://www.internetdownloadmanager.com/register/IDMlib/images/idman_logos.png
call :performIdmDownload
set downloadUrl=https://www.internetdownloadmanager.com/pictures/idm_about.png
call :performIdmDownload

echo:
timeout /t 3 %redirectToNull1%
%idmProcessCheck% && taskkill /f /im idman.exe
if exist "%tempDownloadFile%" del /f /q "%tempDownloadFile%"

goto :eof

::========================================================================================================================================
:: SINGLE IDM DOWNLOAD EXECUTION
::========================================================================================================================================

:: Purpose: Execute a single download through IDM and wait for completion

:performIdmDownload
set /a downloadAttemptCount=0
if exist "%tempDownloadFile%" del /f /q "%tempDownloadFile%"
start "" /B "%idmExecutablePath%" /n /d "%downloadUrl%" /p "%SystemRoot%\Temp" /f temp.png

:waitForDownloadCompletion
timeout /t 1 %redirectToNull1%
set /a downloadAttemptCount+=1
if exist "%tempDownloadFile%" set fileDownloadSuccessful=1&goto :eof
if %downloadAttemptCount% GEQ 20 goto :eof
goto :waitForDownloadCompletion

::========================================================================================================================================
:: REGISTRY ENTRY ADDITION HELPER
::========================================================================================================================================

:: Purpose: Add a registry entry and handle the operation result

:addRegistryEntry
reg add %registryEntry% /f %redirectToNull%

goto :eof

::========================================================================================================================================
:: REQUIRED REGISTRY KEY ADDITION
::========================================================================================================================================

:: Purpose: Add required registry key for IDM functionality

:addRequiredRegistryKey
echo:
echo Adding required registry key...
echo:

set "requiredRegistryKey="%idmRegistryPath%" /v "AdvIntDriverEnabled2""

reg add %requiredRegistryKey% /t REG_DWORD /d "1" /f %redirectToNull%

if "%errorlevel%"=="0" (
    set "reg=%requiredRegistryKey:"=%
    echo Added - !reg!
) else (
    set "reg=%requiredRegistryKey:"=%
    call :displayColoredText2 %colorRed% "Failed - !reg!"
)

goto :eof

::========================================================================================================================================
:: CLSID REGISTRY SCANNING AND PROCESSING
::========================================================================================================================================

:: Purpose: Scan and process CLSID registry keys for locking/deletion

:scanAndProcessClsidKeys
set operationType=%1

if not defined hkcuRegistrySync set hkcuRegistrySync=0
if "%hkcuRegistrySync%"=="$null" set hkcuRegistrySync=0

:: Use scriptFullPath directly - it's set before delayed expansion, so % works
:: Escape single quotes for PowerShell
set "psPath=%scriptFullPath%"
set "psPath=%psPath:'=''%"

if /i "%operationType%"=="delete" (
    %powershellExecutable% "$sid = '%userAccountSid%'; $HKCUsync = if ('%hkcuRegistrySync%' -eq '1') { 1 } else { $null }; $lockKey = $null; $deleteKey = 1; $f=[io.file]::ReadAllText('%psPath%') -split ':regscan\:.*';iex ($f[1])"
) else (
    %powershellExecutable% "$sid = '%userAccountSid%'; $HKCUsync = if ('%hkcuRegistrySync%' -eq '1') { 1 } else { $null }; $lockKey = 1; $deleteKey = $null; $toggle = 1; $f=[io.file]::ReadAllText('%psPath%') -split ':regscan\:.*';iex ($f[1])"
)

goto :eof

::========================================================================================================================================


::========================================================================================================================================

:regscan:
$finalValues = @()

$arch = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment').PROCESSOR_ARCHITECTURE
if ($arch -eq "x86") {
  $regPaths = @("HKCU:\Software\Classes\CLSID", "Registry::HKEY_USERS\$sid\Software\Classes\CLSID")
} else {
  $regPaths = @("HKCU:\Software\Classes\WOW6432Node\CLSID", "Registry::HKEY_USERS\$sid\Software\Classes\Wow6432Node\CLSID")
}

foreach ($regPath in $regPaths) {
    if (($regPath -match "HKEY_USERS") -and ($HKCUsync -ne $null)) {
        continue
    }
	
	Write-Host
	Write-Host "Searching IDM CLSID Registry Keys in $regPath"
	Write-Host
	
    $subKeys = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue -ErrorVariable lockedKeys | Where-Object { $_.PSChildName -match '^\{[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\}$' }

    foreach ($lockedKey in $lockedKeys) {
        $leafValue = Split-Path -Path $lockedKey.TargetObject -Leaf
        $finalValues += $leafValue
        Write-Output "$leafValue - Found Locked Key"
    }

    if ($subKeys -eq $null) {
	continue
	}
	
	$subKeysToExclude = "LocalServer32", "InProcServer32", "InProcHandler32"

    $filteredKeys = $subKeys | Where-Object { !($_.GetSubKeyNames() | Where-Object { $subKeysToExclude -contains $_ }) }

    foreach ($key in $filteredKeys) {
        $fullPath = $key.PSPath
        $keyValues = Get-ItemProperty -Path $fullPath -ErrorAction SilentlyContinue
        $defaultValue = $keyValues.PSObject.Properties | Where-Object { $_.Name -eq '(default)' } | Select-Object -ExpandProperty Value

        if (($defaultValue -match "^\d+$") -and ($key.SubKeyCount -eq 0)) {
            $finalValues += $($key.PSChildName)
            Write-Output "$($key.PSChildName) - Found Digit In Default and No Subkeys"
            continue
        }
        if (($defaultValue -match "\+|=") -and ($key.SubKeyCount -eq 0)) {
            $finalValues += $($key.PSChildName)
            Write-Output "$($key.PSChildName) - Found + or = In Default and No Subkeys"
            continue
        }
        $versionValue = Get-ItemProperty -Path "$fullPath\Version" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty '(default)' -ErrorAction SilentlyContinue
        if (($versionValue -match "^\d+$") -and ($key.SubKeyCount -eq 1)) {
            $finalValues += $($key.PSChildName)
            Write-Output "$($key.PSChildName) - Found Digit In \Version and No Other Subkeys"
            continue
        }
        $keyValues.PSObject.Properties | ForEach-Object {
            if ($_.Name -match "MData|Model|scansk|Therad") {
                $finalValues += $($key.PSChildName)
                Write-Output "$($key.PSChildName) - Found MData Model scansk Therad"
                continue
            }
        }
        if (($key.ValueCount -eq 0) -and ($key.SubKeyCount -eq 0)) {
            $finalValues += $($key.PSChildName)
            Write-Output "$($key.PSChildName) - Found Empty Key"
            continue
        }
    }
}

$finalValues = @($finalValues | Select-Object -Unique)

if ($finalValues -ne $null) {
    Write-Host
    if ($lockKey -ne $null) {
        Write-Host "Locking IDM CLSID Registry Keys..."
    }
    if ($deleteKey -ne $null) {
        Write-Host "Deleting IDM CLSID Registry Keys..."
    }
    Write-Host
} else {
    Write-Host "IDM CLSID Registry Keys are not found."
	Exit
}

if (($finalValues.Count -gt 20) -and ($toggle -ne $null)) {
	$lockKey = $null
	$deleteKey = 1
    Write-Host "The IDM keys count is more than 20. Deleting them now instead of locking..."
	Write-Host
}

function Take-Permissions {
    param($rootKey, $regKey)
    $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly(4, 1)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule(2, $False)
    $TypeBuilder = $ModuleBuilder.DefineType(0)

    $TypeBuilder.DefinePInvokeMethod('RtlAdjustPrivilege', 'ntdll.dll', 'Public, Static', 1, [int], @([int], [bool], [bool], [bool].MakeByRefType()), 1, 3) | Out-Null
    9,17,18 | ForEach-Object { $TypeBuilder.CreateType()::RtlAdjustPrivilege($_, $true, $false, [ref]$false) | Out-Null }

    $SID = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $IDN = ($SID.Translate([System.Security.Principal.NTAccount])).Value
    $Admin = New-Object System.Security.Principal.NTAccount($IDN)

    $everyone = New-Object System.Security.Principal.SecurityIdentifier('S-1-1-0')
    $none = New-Object System.Security.Principal.SecurityIdentifier('S-1-0-0')

    $key = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($regkey, 'ReadWriteSubTree', 'TakeOwnership')

    $acl = New-Object System.Security.AccessControl.RegistrySecurity
    $acl.SetOwner($Admin)
    $key.SetAccessControl($acl)

    $key = $key.OpenSubKey('', 'ReadWriteSubTree', 'ChangePermissions')
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'ContainerInherit', 'None', 'Allow')
    $acl.ResetAccessRule($rule)
    $key.SetAccessControl($acl)

    if ($lockKey -ne $null) {
        $acl = New-Object System.Security.AccessControl.RegistrySecurity
        $acl.SetOwner($none)
        $key.SetAccessControl($acl)

        $key = $key.OpenSubKey('', 'ReadWriteSubTree', 'ChangePermissions')
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule($everyone, 'FullControl', 'Deny')
        $acl.ResetAccessRule($rule)
        $key.SetAccessControl($acl)
    }
}

foreach ($regPath in $regPaths) {
    if (($regPath -match "HKEY_USERS") -and ($HKCUsync -ne $null)) {
        continue
    }
    foreach ($finalValue in $finalValues) {
        $fullPath = Join-Path -Path $regPath -ChildPath $finalValue
        if ($fullPath -match 'HKCU:') {
            $rootKey = 'CurrentUser'
        } else {
            $rootKey = 'Users'
        }

        $position = $fullPath.IndexOf("\")
        $regKey = $fullPath.Substring($position + 1)

        if ($lockKey -ne $null) {
            if (-not (Test-Path -Path $fullPath -ErrorAction SilentlyContinue)) { New-Item -Path $fullPath -Force -ErrorAction SilentlyContinue | Out-Null }
            Take-Permissions $rootKey $regKey
            try {
                Remove-Item -Path $fullPath -Force -Recurse -ErrorAction Stop
                Write-Host -back 'DarkRed' -fore 'white' "Failed - $fullPath"
            }
            catch {
                Write-Host "Locked - $fullPath"
            }
        }

        if ($deleteKey -ne $null) {
            if (Test-Path -Path $fullPath) {
                Remove-Item -Path $fullPath -Force -Recurse -ErrorAction SilentlyContinue
                if (Test-Path -Path $fullPath) {
                    Take-Permissions $rootKey $regKey
                    try {
                        Remove-Item -Path $fullPath -Force -Recurse -ErrorAction Stop
                        Write-Host "Deleted - $fullPath"
                    }
                    catch {
                        Write-Host -back 'DarkRed' -fore 'white' "Failed - $fullPath"
                    }
                }
                else {
                    Write-Host "Deleted - $fullPath"
                }
            }
        }
    }
}
:regscan:

::========================================================================================================================================
:: Leave empty line below
