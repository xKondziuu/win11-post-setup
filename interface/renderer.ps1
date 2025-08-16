# User Interface Renderer

param (
  [switch]$Developer = $false,
  [Parameter(Mandatory = $true)]
  [ValidateSet("de", "en", "pl")]
  [string]$Language = "en",
  [Parameter(Mandatory = $true)]
  [string]$LayoutPath,
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$RootDirectory,
  [Parameter(Mandatory = $true)]
  [string]$Version
)

# Load necessary assemblies for WPF and Windows Forms
Add-Type -AssemblyName PresentationFramework, WindowsBase, System.Windows.Forms

# Set up language convertions
if (-not $Language -or $Language -eq "en") {
  $lngActivate         = "Activate"
  $lngActivityHistory  = "Activity History"
  $lngBingSearchEngine = "Bing Search Engine"
  $lngClearFiles       = "Delete Wizard files after setup completion"
  $lngDescription      = "This wizard will complete your Windows 11 setup using the recommended settings below,`n you can adjust them now. System will restart automatically after the setup."
  $lngDisable          = "Disable"
  $lngExecute          = "Execute"
  $lngExitMessage      = "Are you sure you want to exit the setup?"
  $lngExitTitle        = "Exit Confirmation"
  $lngHibernation      = "System Hibernation"
  $lngInstall          = "Install"
} elseif ($Language -eq "pl") {
  $lngActivate         = "Aktywuj"
  $lngActivityHistory  = "Historia Aktywno$([char]0x15b)ci"
  $lngBingSearchEngine = "Wyszukiwarka Bing"
  $lngClearFiles       = "Usu$([char]0x144) pliki kreatora po zako$([char]0x144)czeniu konfiguracji"
  $lngDescription      = "Ten kreator zako$([char]0x144)czy konfiguracj$([char]0x119) systemu Windows 11, u$([char]0x17c)ywaj$([char]0x105)c zalecanych ustawie$([char]0x144) poni$([char]0x17c)ej,`n mo$([char]0x17c)esz je teraz dostosowa$([char]0x107). Komputer zostanie uruchomiony ponownie."
  $lngDisable          = "Wy$([char]0x142)$([char]0x105)cz"
  $lngExecute          = "Wykonaj"
  $lngExitMessage      = "Czy na pewno chcesz zako$([char]0x144)czy$([char]0x107) prac$([char]0x119) kreatora?"
  $lngExitTitle        = "Potwierdzenie wyj$([char]0x15b)cia"
  $lngHibernation      = "Hibernacja systemu"
  $lngInstall          = "Zainstaluj"
} elseif ($Language -eq "de") {
  $lngActivate         = "Aktivieren"
  $lngActivityHistory  = "Aktivit$([char]0xE4)tsverlauf"
  $lngBingSearchEngine = "Bing-Suchmaschine"
  $lngClearFiles       = "L$([char]0xF6)sche den Assistenten nach Abschluss der Einrichtung"
  $lngDescription      = "Dieser Assistent schlie$([char]0xDF)t die Einrichtung von Windows 11 mit den unten empfohlenen Einstellungen ab. Sie k$([char]0xF6)nnen diese jetzt anpassen. Das System startet danach neu."
  $lngDisable          = "Deaktivieren"
  $lngExecute          = "Ausf$([char]0xFC)hren"
  $lngExitMessage      = "Sind Sie sicher, dass Sie die Einrichtung beenden m$([char]0xF6)chten?"
  $lngExitTitle        = "Best$([char]0xE4)tigung zum Beenden"
  $lngHibernation      = "System-Hibernation"
  $lngInstall          = "Installieren"
}

# Load the XAML layout from a file and create a window object from it
$xamlPath = Join-Path $RootDirectory $LayoutPath
if (-not (Test-Path $xamlPath)) {
  Write-Error "XAML layout file not found: $xamlPath"
  exit 1
}

# Load the XAML content
#Write-Host "Loading XAML layout from ""$xamlPath"""
$xamlContent = Get-Content -Path $xamlPath -Raw
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlContent))
$window = [Windows.Markup.XamlReader]::Load($reader)

if ($Developer) {
  $window.Title = $window.Title + " [DEVELOPER MODE]"
}

# Layout elements references
$activateOfficeOhook    = $window.FindName("activateOfficeOhook")
$activateWindowsHwid    = $window.FindName("activateWindowsHwid")
$activateWindowsTsforge = $window.FindName("activateWindowsTsforge")
$activateWinrar         = $window.FindName("activateWinrar")
$clearFiles             = $window.FindName("clearFiles")
$disableBing            = $window.FindName("disableBing")
$disableHibernation     = $window.FindName("disableHibernation")
$disableHistory         = $window.FindName("disableHistory")
$disableOnedrive        = $window.FindName("disableOnedrive")
$disableOutlook         = $window.FindName("disableOutlook")
$executeButton          = $window.FindName("executeButton")
$installChrome          = $window.FindName("installChrome")
$installFirefox         = $window.FindName("installFirefox")
$installOffice          = $window.FindName("installOffice")
$installPowertoys       = $window.FindName("installPowertoys")
$installSumatra         = $window.FindName("installSumatra")
$installWinrar          = $window.FindName("installWinrar")
$textActivate           = $window.FindName("textActivate")
$textActivityHistory    = $disableHistory
$textBingSearchEngine   = $disableBing
$textClearFiles         = $clearFiles
$textDescription        = $window.FindName("textDescription")
$textDisable            = $window.FindName("textDisable")
$textExecute            = $executeButton
$textHibernation        = $disableHibernation
$textInstall            = $window.FindName("textInstall")
$textVersion            = $window.FindName("textVersion")

# Set the language for UI elements
$textActivate.Text            = $lngActivate
$textActivityHistory.Content  = $lngActivityHistory
$textBingSearchEngine.Content = $lngBingSearchEngine
$textClearFiles.Content       = $lngClearFiles
$textDescription.Text         = $lngDescription
$textDisable.Text             = $lngDisable
$textExecute.Content          = $lngExecute
$textHibernation.Content      = $lngHibernation
$textInstall.Text             = $lngInstall
$textVersion.Text             = "$Version"

# Office/Outlook/Ohook dependency logic
function Update-OfficeInstallationDependencies {
    $activateOfficeOhook.IsEnabled = $installOffice.IsChecked
    $disableOutlook.IsEnabled      = $installOffice.IsChecked
    $activateOfficeOhook.IsChecked = $installOffice.IsChecked
    $disableOutlook.IsChecked      = $installOffice.IsChecked
}

# Windows HWID/TSforge mutual exclusion logic
function Update-WindowsActivationDependencies {
  if ($activateWindowsHwid.IsChecked) {
    $activateWindowsTsforge.IsEnabled = $false
    $activateWindowsHwid.IsEnabled = $true
  } elseif ($activateWindowsTsforge.IsChecked) {
    $activateWindowsHwid.IsEnabled = $false
    $activateWindowsTsforge.IsEnabled = $true
  } else {
    $activateWindowsHwid.IsEnabled = $true
    $activateWindowsTsforge.IsEnabled = $true
  }
}


# Winrar activation auto check
function Update-WinrarInstallationDependencies {
  $activateWinrar.IsEnabled = $installWinrar.IsChecked
  $activateWinrar.IsChecked = $installWinrar.IsChecked
}


# Disabled checkboxes always gray
function Set-DisabledCheckboxesGray {
  $checkboxes = @($disableOutlook, $activateWindowsHwid, $activateWindowsTsforge, $activateOfficeOhook, $activateWinrar)
  foreach ($cb in $checkboxes) {
    if ($cb.IsEnabled) {
      $cb.Foreground = [System.Windows.Media.Brushes]::Black
    } else {
      $cb.Foreground = [System.Windows.Media.Brushes]::Gray
    }
  }
}

function Get-ActivateWindows {
  if ($activateWindowsHwid.IsChecked) {
    return "hwid"
  } elseif ($activateWindowsTsforge.IsChecked) {
    return "tsforge"
  } else {
    return $null
  }
}

function Get-InstallBrowser {
  $browsers = @()
  if ($installChrome.IsChecked) {
    $browsers += "chrome"
  }
  if ($installFirefox.IsChecked) {
    $browsers += "firefox"
  }
  if ($browsers.Count -eq 0) {
    return $null
  } else {
    return $browsers
  }
}

# Office installation dependencies
$installOffice.Add_Checked({ Update-OfficeInstallationDependencies; Set-DisabledCheckboxesGray })
$installOffice.Add_Unchecked({ Update-OfficeInstallationDependencies; Set-DisabledCheckboxesGray })

# Windows activation dependencies
$activateWindowsHwid.Add_Checked({ Update-WindowsActivationDependencies; Set-DisabledCheckboxesGray })
$activateWindowsHwid.Add_Unchecked({ Update-WindowsActivationDependencies; Set-DisabledCheckboxesGray })
$activateWindowsTsforge.Add_Checked({ Update-WindowsActivationDependencies; Set-DisabledCheckboxesGray })
$activateWindowsTsforge.Add_Unchecked({ Update-WindowsActivationDependencies; Set-DisabledCheckboxesGray })

# Winrar activation dependencies
$installWinrar.Add_Checked({ Update-WinrarInstallationDependencies; Set-DisabledCheckboxesGray })
$installWinrar.Add_Unchecked({ Update-WinrarInstallationDependencies; Set-DisabledCheckboxesGray })

# Execute button action
$executeButton.Add_Click({
  $settings = @{
    ActivateOffice     = $activateOfficeOhook.IsChecked
    ActivateWindows    = Get-ActivateWindows
    ActivateWinrar     = $activateWinrar.IsChecked
    ClearFiles         = $clearFiles.IsChecked
    DisableBing        = $disableBing.IsChecked
    DisableHibernation = $disableHibernation.IsChecked
    DisableHistory     = $disableHistory.IsChecked
    DisableOnedrive    = $disableOnedrive.IsChecked
    DisableOutlook     = $disableOutlook.IsChecked
    InstallBrowser     = Get-InstallBrowser
    InstallOffice      = $installOffice.IsChecked
    InstallPowertoys   = $installPowertoys.IsChecked
    InstallWinrar      = $installWinrar.IsChecked
    InstallSumatra     = $installSumatra.IsChecked
  }

  $json = $settings | ConvertTo-Json -Compress -Depth 2
  Write-Host $json
  exit 0
})

# Show confirmation dialog on window close
$window.Add_Closing({
  param($s, $e)
  $result = [System.Windows.MessageBox]::Show(
    $lngExitMessage,
    $lngExitTitle,
    [System.Windows.MessageBoxButton]::YesNo,
    [System.Windows.MessageBoxImage]::Warning
  )
  if ($result -eq [System.Windows.MessageBoxResult]::No) {
    $e.Cancel = $true
  }
})

# Initial state
Update-OfficeInstallationDependencies
Update-WindowsActivationDependencies
Update-WinrarInstallationDependencies
Set-DisabledCheckboxesGray

# Show interface
[void] $window.ShowDialog()