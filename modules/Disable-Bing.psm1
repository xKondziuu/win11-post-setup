function Disable-Bing {
  [CmdletBinding()]
  param (
    [switch]$BlockSearchApp,
    [switch]$DisableCortana
  )
  
  if ($BlockSearchApp) {
    Write-Host "Blocking SearchApp.exe"
    $searchAppPath = "$env:windir\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy\SearchApp.exe"
    if (Test-Path $searchAppPath) {
      takeown /F $searchAppPath /A /R /D Y
      icacls $searchAppPath /inheritance:r
      icacls $searchAppPath /deny "Everyone:(X)"
      Write-Host "SearchApp.exe has been blocked"
    } else {
      Write-Host "SearchApp.exe not found"
    }
  }

  $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
  if (-not (Test-Path $regPath)) {
    Write-Host "Creating Windows Search registry key"
    New-Item -Path $regPath -Force | Out-Null
  }

  Write-Host "Disabling Web Search"
  New-ItemProperty -Path $regPath -Name "DisableWebSearch" -Value 1 -PropertyType DWord -Force
  Write-Host "Disabling Connected Search"
  New-ItemProperty -Path $regPath -Name "ConnectedSearchUseWeb" -Value 0 -PropertyType DWord -Force
  Write-Host "Disabling Search Highlights"
  New-ItemProperty -Path $regPath -Name "DisableSearchBoxSuggestions" -Value 1 -PropertyType DWord -Force
  
  if ($DisableCortana) {
    Write-Host "Disabling Cortana"
    New-ItemProperty -Path $regPath -Name "AllowCortana" -Value 0 -PropertyType DWord -Force
  }

  Write-Host "Bing Search disabled successfully" -ForegroundColor Green

}

Export-ModuleMember -Function Disable-Bing
