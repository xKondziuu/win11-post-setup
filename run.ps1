<#
  Windows 11 Post-Setup Script
  Author: Konrad S.K.
  Repository: https://github.com/xKondziuu/win11-post-setup

  This script automates post-installation configuration for Windows 11.
  Software is provided "as-is", without warranty of any kind.
#>

param (
  [switch]$Developer = $false,
  [switch]$ForcePolishKeyboard = $false,
  [ValidateSet("de", "en", "pl")]
  [string]$Language = "en",
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$WorkingDirectory = $PSScriptRoot,
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$ConfigPath = (Join-Path $WorkingDirectory "config.jsonc")
)

if ($PSVersionTable.PSVersion.Major -lt 5) {
  Write-Error "PowerShell version 5.0 or higher is required."
  exit 1
}

# Ensure the script is running as administrator
if (-not $Developer -and -not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Warning "This script must be run as Administrator. Restarting with elevated privileges..."
  $allArgs = @()
  foreach ($kvp in $PSBoundParameters.GetEnumerator()) {
    $allArgs += "-$($kvp.Key) `"$($kvp.Value)`""
  }
  if ($args.Count -gt 0) {
    $allArgs += $args
  }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "powershell.exe"
  $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $allArgs"
  $psi.Verb = "runas"
  try {
    [System.Diagnostics.Process]::Start($psi) | Out-Null
  } catch {
    Write-Error "Failed to restart script as administrator: $_"
  }
  exit 0
}


Clear-Host
Write-Host @'

                          _      ___         __                 ______
                         | | /| / (_)__  ___/ /__ _    _____   <  <  /
                         | |/ |/ / / _ \/ _  / _ \ |/|/ (_-<   / // / 
                         |__/|__/_/_//_/\_,_/\___/__,__/___/  /_//_/                                                
    ____             __       _____      __                 _       ___                      __
   / __ \____  _____/ /_     / ___/___  / /___  ______     | |     / (_)___  ____ __________/ /
  / /_/ / __ \/ ___/ __/_____\__ \/ _ \/ __/ / / / __ \    | | /| / / /_  / / __ `/ ___/ __  / 
 / ____/ /_/ (__  ) /_/_____/__/ /  __/ /_/ /_/ / /_/ /    | |/ |/ / / / /_/ /_/ / /  / /_/ /  
/_/    \____/____/\__/     /____/\___/\__/\__,_/ .___/     |__/|__/_/ /___/\__,_/_/   \__,_/   
                                              /_/                                              
                                                                                    Konrad S.K.

'@

if ($Developer) {
  $Host.UI.RawUI.WindowTitle = $Host.UI.RawUI.WindowTitle + ' [DEVELOPER MODE]'
  Write-Warning "Developer mode enabled"
} else {
  $Host.UI.RawUI.WindowTitle = "Windows 11 Post-Setup Wizard"
}

Set-Location -Path $WorkingDirectory
Write-Host "Working directory is `"$WorkingDirectory`""

Write-Host "Importing required modules..."
try {
  Import-Module -Name (Join-Path $WorkingDirectory "modules/ConvertFrom-JsonC.psm1") -Force
  Import-Module -Name (Join-Path $WorkingDirectory "modules/Disable-Bing.psm1") -Force
  Import-Module -Name (Join-Path $WorkingDirectory "modules/Disable-History.psm1") -Force
  Import-Module -Name (Join-Path $WorkingDirectory "modules/Disable-Onedrive.psm1") -Force
  Import-Module -Name (Join-Path $WorkingDirectory "modules/Start-Activation.psm1") -Force
  Import-Module -Name (Join-Path $WorkingDirectory "modules/Start-Installation.psm1") -Force
  Import-Module -Name (Join-Path $WorkingDirectory "modules/Start-InstallationMSI.psm1") -Force
} catch {
  Write-Error "Failed to import module(s): $_"
  exit 1
}
Write-Host "Module import process completed."

# Config typing
class ConfigType {
  [string]$_configVersion
  [hashtable]$Activators
  [CleanupType]$Cleanup
  [int]$DefaultActivationTimeout
  [int]$DefaultInstallationTimeout
  [DisableBingType]$DisableBing
  [DisableHistoryType]$DisableHistory
  [DisableOnedriveType]$DisableOnedrive
  [ForcePolishKeyboardType]$ForcePolishKeyboard
  [InstallOfficeType]$InstallOffice
  [InstallWinrarType]$InstallWinrar
  [hashtable]$Installers
}
class ActivatorEntry {
  [string]$File
  [string]$Name
}
class CleanupType {
  [bool]$AlwaysRestartExplorer
  [bool]$KeepMainConsoleOpen
  [bool]$KeepCleanupConsoleOpen
  [bool]$RemoveRecentItems
  [RestartSystemType]$RestartSystem
}
class RestartSystemType {
  [bool]$Enabled
  [int]$Timeout
}
class DisableBingType {
  [bool]$BlockSearchApp
  [bool]$DisableCortana
}
class DisableHistoryType {
  [bool]$DisableActivityFeed
}
class DisableOnedriveType {
  [bool]$RemoveForNewUsers
  [bool]$RemoveFromSidebar
}
class ForcePolishKeyboardType {
  [bool]$DisableLanguageBar
}
class InstallOfficeType {
  [bool]$OrganizeShortcuts
  [bool]$RemoveToolsFolder
}
class InstallWinrarType {
  [bool]$OrganizeShortcuts
}
class InstallerEntry {
  [string]$Args
  [string]$File
  [string]$Name
}

try {
  $configContent = Get-Content -Path $ConfigPath -Raw
  [ConfigType]$config = ConvertFrom-JsonCTyped $configContent ([ConfigType])
} catch {
  Write-Error "Failed to load config file `"$($ConfigPath)`": $_"
  exit 1
} finally {
  if ($null -eq $config -or ([bool]($config | Measure-Object).Count -eq 0)) {
    Write-Error "Config file `"$($ConfigPath)`" is empty or invalid."
    exit 1
  } else {
    Write-Host "Config file `"$($ConfigPath)`" loaded successfully."
  }
}

# Define paths to resources
$fileRenderer = (Join-Path $WorkingDirectory "interface/renderer.ps1")

$systemDir = @{
  StartMenu = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
  StartMenuUser = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
}

function Write-ParameterSummary {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Title,
    [hashtable]$Parameters
  )
  if ($Parameters -and $Parameters.Count -gt 0) {
    Write-Host "Running `"$Title`" with parameters:"
    foreach ($key in $Parameters.Keys) {
      $value = $Parameters[$key]
      if ($value -is [bool]) {
        Write-Host "| $($key): $value"
      } elseif ($value -is [string]) {
        Write-Host "| $($key): `"$value`""
      } else {
        Write-Host "| $($key): $value"
      }
    }
  } else {
    Write-Host "Running `"$Title`""
  }
}

function Invoke-Installation {
  param(
    [Parameter(Mandatory)]
    [string]$Key,
    [int]$Timeout = $config.DefaultInstallationTimeout,
    [switch]$FreezeWarning,
    [switch]$NoNewWindow
  )
  if (-not ($config.Installers.PSObject.Properties.Name -contains $Key)) {
    Write-Warning "Skipping installation of `"$($Key)`", key not found in configuration."
    return
  }
  $installerInfo = $config.Installers.$Key
  $installerFile = $installerInfo.File -replace "\[LANG\]", $Language
  $params = @{
    Path = Join-Path (Join-Path $WorkingDirectory "installers") $installerFile
    Timeout = $Timeout
    Arguments = $installerInfo.Args
  }
  $func = if ($installerFile.ToLower().EndsWith(".exe")) {
    "Start-Installation"
  } elseif ($installerFile.ToLower().EndsWith(".msi")) {
    "Start-InstallationMSI"
  } else {
    Write-Warning "Unknown file extension: $installerFile. Skipping installation of $($installerInfo.Name)."
  }
  Write-ParameterSummary -Title $func -Parameters $params
  if ($func -eq "Start-Installation") {
    if ($NoNewWindow) {
      $params.NoNewWindow = $true
    }
  }
  if ($FreezeWarning) {
    $params.FreezeWarning = $true
  }
  if (-not $Developer) {
    if (& $func @params) {
      Write-Host "$($installerInfo.Name) installation completed" -ForegroundColor Green
    } else {
      Write-Warning "$($installerInfo.Name) installation failed"
    }
  } else {
    Write-Host "$($installerInfo.Name) installation completed" -ForegroundColor Green
  }
}

function Invoke-Activation {
  param(
    [Parameter(Mandatory)]
    [string]$Key,
    [int]$Timeout = $config.DefaultActivationTimeout
  )
  if (-not ($config.Activators.PSObject.Properties.Name -contains $Key)) {
    Write-Warning "Skipping activation of `"$($Key)`", key not found in configuration."
    return
  }
  $activatorInfo = $config.Activators.$Key
  $activatorFile = $activatorInfo.File -replace "\[LANG\]", $Language
  $params = @{
    Path = Join-Path (Join-Path $WorkingDirectory "activators") $activatorFile
    Timeout = $Timeout
  }
  Write-ParameterSummary -Title "Start-Activation" -Parameters $params
  if (-not $Developer) {
    if (& Start-Activation @params) {
      Write-Host "$($activatorInfo.Name) activation completed" -ForegroundColor Green
    } else {
      Write-Warning "$($activatorInfo.Name) activation failed"
    }
  } else {
    Write-Host "$($activatorInfo.Name) activation completed" -ForegroundColor Green
  }
}

function Invoke-OfficeInstallation {
  param (
    [Parameter(Mandatory)]
    [string]$Language,
    [bool]$NoOnedrive = $false,
    [bool]$NoOutlook = $false,
    [switch]$OrganizeShortcuts,
    [switch]$RemoveToolsFolder
  )
  $configName = "default"
  if ($NoOnedrive -and $NoOutlook) {
    $configName = "no-onedrive-outlook"
  } elseif ($NoOnedrive) {
    $configName = "no-onedrive"
  } elseif ($NoOutlook) {
    $configName = "no-outlook"
  }
  Write-Host "Using configuration mode: `"$configName`""
  $configFile = "`"$(Join-Path $WorkingDirectory "installers/msoffice/config/$($Language)/$($configName).xml")`""
  $installerInfo = $config.Installers.msoffice
  $installerFile = $installerInfo.File -replace "\[LANG\]", $Language
  $params = @{
    Path = Join-Path (Join-Path $WorkingDirectory "installers") $installerFile
    Timeout = $config.DefaultInstallationTimeout
    Arguments = $installerInfo.Args -replace "\[CONFIG\]", $configFile
  }
  Write-ParameterSummary -Title "Start-Installation" -Parameters $params
  if (-not $Developer) {
    if (& Start-Installation @params -FreezeWarning -NoNewWindow) {
      Start-Sleep -Seconds 3
      if ($OrganizeShortcuts) {
        Write-Host "Organizing start menu shortcuts..."
        $officeFolder = Join-Path $systemDir.StartMenu "Microsoft Office"
        New-Item -Path $officeFolder -ItemType Directory -Force
        $officeShortcuts = @("Access", "Excel", "OneNote", "PowerPoint", "Publisher", "Word")
        if (-not $NoOutlook) {
          $officeShortcuts += "Outlook"
        }
        Start-Sleep -Seconds 1
        foreach ($s in $officeShortcuts) {
          $src = Join-Path $systemDir.StartMenu "$s.lnk"
          $dst = Join-Path $officeFolder "$s.lnk"
          if (Test-Path $src) {
            Move-Item -Path $src -Destination $dst -Force
          }
        }
      }
      if ($RemoveToolsFolder) {
        Write-Host "Removing Microsoft Office Tools folder..."
        $officeToolsName = if ($Language -eq "en") { 
          "Microsoft Office Tools"
        } elseif ($Language -eq "de") {
          "Microsoft Office-Tools"
        } elseif ($Language -eq "pl") { 
          "Narz$([char]0x119)dzia pakietu Microsoft Office"
        }
        $officeTools = Join-Path $systemDir.StartMenu $officeToolsName
        if (Test-Path $officeTools) {
          Remove-Item -Path $officeTools -Recurse -Force
        }
      }
      Write-Host "$($installerInfo.Name) installation completed" -ForegroundColor Green
    } else {
      Write-Warning "$($installerInfo.Name) installation failed"
    }
  } else {
    Write-Host "$($installerInfo.Name) installation completed" -ForegroundColor Green
  }
}

function Invoke-WinrarInstallation {
  param (
    [Parameter(Mandatory)]
    [string]$Language,
    [switch]$OrganizeShortcuts
  )

  $installerInfo = $config.Installers.winrar
  $installerFile = $installerInfo.File -replace "\[LANG\]", $Language
  $params = @{
    Path = Join-Path (Join-Path $WorkingDirectory "installers") $installerFile
    Timeout = $config.DefaultInstallationTimeout
    Arguments = $installerInfo.Args
  }
  Write-ParameterSummary -Title "Start-Installation" -Parameters $params
  if (-not $Developer) {
    if (& Start-Installation @params) {
      if ($OrganizeShortcuts) {
        Write-Host "Organizing start menu shortcuts..."
        Start-Sleep -Seconds 3
        $name = "WinRAR"
        $folders = @(
          @{ Folder = (Join-Path $systemDir.StartMenu $name); Parent = $systemDir.StartMenu },
          @{ Folder = (Join-Path $systemDir.StartMenuUser $name); Parent = $systemDir.StartMenuUser }
        )
        foreach ($f in $folders) {
          $src = Join-Path $f.Folder "$name.lnk"
          $dst = Join-Path $f.Parent "$name.lnk"
          if (Test-Path $src) {
            Move-Item -Path $src -Destination $dst -Force
          }
          if (Test-Path $f.Folder) {
            Remove-Item -Path $f.Folder -Recurse -Force
          }
        }
      }
      Write-Host "$($installerInfo.Name) installation completed" -ForegroundColor Green
    } else {
      Write-Warning "$($installerInfo.Name) installation failed"
    }
  } else {
    Write-Host "$($installerInfo.Name) installation completed" -ForegroundColor Green
  }
}

# Polish keyboard enforcement
if ($ForcePolishKeyboard) {
  Write-Host "Enforcing Polish keyboard layout..."
  
  Set-WinUILanguageOverride -Language en-US
  Set-WinSystemLocale -SystemLocale en-US
  Set-WinUserLanguageList -LanguageList en-US,pl-PL -Force

  $languageList = Get-WinUserLanguageList
  foreach ($lang in $languageList) {
    if ($lang.LanguageTag -eq 'en-US') {
      $lang.InputMethodTips.Clear()
      $lang.InputMethodTips.Add("0409:00000415") # en-US lang + pl keyboard
    }
  }
  Set-WinUserLanguageList $languageList -Force

  if (-not $config.ForcePolishKeyboard.DisableLanguageBar) {
    Write-Host "Disabling keyboard layout switcher"
    $regPath = "HKCU:\Software\Microsoft\CTF\LangBar"
    if (-not (Test-Path $regPath)) {
      New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "ShowStatus" -Value 3  # 3 = Hide the language bar
    Set-WinLanguageBarOption -UseLegacySwitchMode -UseLegacyLanguageBar
  }

  Write-Host "Locale configuration complete" -ForegroundColor Green
  Start-Sleep -Seconds 1
}

# Check if the renderer script exists
if (-not (Test-Path $fileRenderer)) {
  Write-Error "Renderer script not found: $fileRenderer"
  exit 1
}

# Run the renderer and get JSON data
Write-ParameterSummary -Title "$fileRenderer" -Parameters @{
  Developer = $Developer
  Language = $Language
  LayoutPath = "interface/layout.xaml"
  RootDirectory = $WorkingDirectory
  Version = $config._configVersion
}
Write-Host "Rendering UI..."
if ($Developer) {
  $json = powershell.exe -ExecutionPolicy Bypass -File $fileRenderer -Developer -Language $Language -LayoutPath "interface/layout.xaml" -RootDirectory $WorkingDirectory -Version $config._configVersion
} else {
  $json = powershell.exe -ExecutionPolicy Bypass -File $fileRenderer -Language $Language -LayoutPath "interface/layout.xaml" -RootDirectory $WorkingDirectory -Version $config._configVersion
}

# Close when the renderer returns no data
if (-not $json) {
  Write-Host "Renderer closed, exiting."
  exit 0
}

# Parse the JSON data
try {
  $options = $json | ConvertFrom-Json
} catch {
  Write-Error "$json"
  exit 1
}

Write-Host "Renderer returned options: $($options | ConvertTo-Json -Depth 2 -Compress)"

# Disable history and activity feed
if ($options.DisableHistory) {
  $params = @{
    DisableActivityFeed = $config.DisableHistory.DisableActivityFeed
  }
  Write-ParameterSummary -Title "Disable-History" -Parameters $params
  if (-not $Developer) {
    Disable-History @params
  }
  Start-Sleep -Seconds 1
}

# Disable system hibernation
if ($options.DisableHibernation) {
  Write-Host "Disabling system hibernation..."
  Write-ParameterSummary -Title "powercfg.exe"
  if (-not $Developer) {
    powercfg.exe /hibernate off
    Write-Host "System hibernation disabled" -ForegroundColor Green
  }
  Start-Sleep -Seconds 1
}

# Disable Bing in search
if ($options.DisableBing) {
  $params = @{
    BlockSearchApp = $config.DisableBing.BlockSearchApp
    DisableCortana = $config.DisableBing.DisableCortana
  }
  Write-ParameterSummary -Title "Disable-Bing" -Parameters $params
  if (-not $Developer) {
    Disable-Bing @params
  }
  Start-Sleep -Seconds 1
}

# Disable Onedrive
if ($options.DisableOnedrive) {
  $params = @{
    RemoveForNewUsers = $config.DisableOnedrive.RemoveForNewUsers
    RemoveFromSidebar = $config.DisableOnedrive.RemoveFromSidebar
  }
  Write-ParameterSummary -Title "Disable-Onedrive" -Parameters $params
  if (-not $Developer) {
    Disable-Onedrive @params
  }
  Start-Sleep -Seconds 1
}

# Install Microsoft Office
if ($options.InstallOffice) {
  $params = @{
    Language = $Language
    NoOneDrive = $options.DisableOnedrive
    NoOutlook = $options.DisableOutlook
    OrganizeShortcuts = $config.InstallOffice.OrganizeShortcuts
    RemoveToolsFolder = $config.InstallOffice.RemoveToolsFolder
  }
  Write-ParameterSummary -Title "Invoke-OfficeInstallation" -Parameters $params
  Invoke-OfficeInstallation @params
  Start-Sleep -Seconds 1
}

# Activate Microsoft Office
if ($options.ActivateOffice) {
  Invoke-Activation -Key "officeohook"
  Start-Sleep -Seconds 1
}

# Install PowerToys
if ($options.InstallPowerToys) {
  Invoke-Installation -Key "powertoys" -FreezeWarning
  Start-Sleep -Seconds 1
}

# Install Browsers
if ($null -ne $options.InstallBrowser) {
  foreach ($browser in $options.InstallBrowser) {
    Invoke-Installation -Key $browser -FreezeWarning
    Start-Sleep -Seconds 1
  }
}

# Install Sumatra PDF
if ($options.InstallSumatra) {
  Invoke-Installation -Key "sumatra"
  Start-Sleep -Seconds 1
}

# Install WinRAR
if ($options.InstallWinrar) {
  $params = @{
    Language = $Language
    OrganizeShortcuts = $config.InstallWinrar.OrganizeShortcuts
  }
  Write-ParameterSummary -Title "Invoke-WinrarInstallation" -Parameters $params
  Invoke-WinrarInstallation @params
  Start-Sleep -Seconds 1
}

# Activate WinRAR
if ($options.ActivateWinrar) {
  Invoke-Activation -Key "winraractivator"
  Start-Sleep -Seconds 1
}

# Activate Windows
if ($null -ne $options.ActivateWindows) {
  if ($options.ActivateWindows -eq "hwid") {
    Invoke-Activation -Key "windowshwid"
  } elseif ($options.ActivateWindows -eq "tsforge") {
    Invoke-Activation -Key "windowstsforge"
  }
  Start-Sleep -Seconds 1
}

Write-Host "Task execution completed, closing..." -ForegroundColor Green
Start-Sleep -Seconds 1

if (-not $Developer) {
  $cmds = @()
  if ($options.ClearFiles) {
    $cmds += "echo Cleaning up..."
    $cmds += "cd .."
    $cmds += "rd /s /q `"$PSScriptRoot`""
  }
  if ($config.RestartSystem.Enabled) {
    $cmds += "echo Restarting system..."
    $cmds += "shutdown /r /t $($config.RestartSystem.Timeout + 1) /c `" `""
  }
  if ($cmds.Count -gt 0) {
    $cmds += "timeout /t 2 /nobreak >nul"
    if ($config.Cleanup.KeepCleanupConsoleOpen) {
      $cmds += "echo WARNING: Option `"Cleanup.KeepCleanupConsoleOpen`" is enabled, keeping the console open."
      $cmds += "echo Press any key to close . . ."
      $cmds += "pause > nul"
      $cmds += "exit /b 0"
    } else {
      $cmds += "exit /b 0"
    }
    Start-Process cmd.exe "/c $($cmds -join ' & ')"
  } else {
    Write-Host "No cleanup required, exiting."
  }
  
  # Clear recent items
  if ($config.RemoveRecentItems) {
    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations\*" -Recurse -Force -ErrorAction SilentlyContinue
  }

  # Restart Explorer
  if ($config.Cleanup.AlwaysRestartExplorer) {
    Start-Sleep -Seconds 1
    Stop-Process -Name explorer -Force
  }

}

if ($Developer -or $config.Cleanup.KeepMainConsoleOpen) {
  if ($Developer) {
    Write-Warning "Developer mode is enabled, keeping the console open."
  } else {
    Write-Warning "Option `"Cleanup.KeepMainConsoleOpen`" is enabled, keeping the console open."
  }
  Write-Host "Press any key to close . . ." -NoNewline
  [void][System.Console]::ReadKey($true)
}

exit 0