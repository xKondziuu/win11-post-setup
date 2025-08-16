function Disable-History {
  param (
    [switch]$DisableActivityFeed
  )

  $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
  if (-not (Test-Path $regPath)) {
    Write-Host "Creating System registry key"
    New-Item -Path $regPath -Force | Out-Null
  }
  
  Write-Host "Disabling activity publishing"
  New-ItemProperty -Path $regPath -Name "PublishUserActivities" -Value 0 -PropertyType DWord -Force

  Write-Host "Disabling activity uploading"
  New-ItemProperty -Path $regPath -Name "UploadUserActivities" -Value 0 -PropertyType DWord -Force

  if ($DisableActivityFeed) {
    Write-Host "Disabling activity feed"
    New-ItemProperty -Path $regPath -Name "EnableActivityFeed" -Value 0 -PropertyType DWord -Force
  }

  Write-Host "Activity history disabled successfully" -ForegroundColor Green

}