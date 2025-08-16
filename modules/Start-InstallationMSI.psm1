function Start-InstallationMSI {
  param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [int]$Timeout,
    [string]$Arguments = "/quiet /norestart", # default arguments for silent MSI installation
    [switch]$FreezeWarning
  )

  Write-Host "Starting MSI installation `"$Path`" with arguments: $Arguments"

  if ($FreezeWarning) {
    Write-Warning "It's normal for it to freeze here. Please wait..."
  }

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = "msiexec.exe"
  $startInfo.Arguments = "/i `"$Path`" $Arguments"
  $startInfo.UseShellExecute = $true
  $startInfo.CreateNoWindow = $true

  try {
    $process = [System.Diagnostics.Process]::Start($startInfo)
  } catch {
    Write-Warning "Failed to start MSI installer `"$Path`", skipping."
    return $false
  }

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
    if ($process.HasExited) {
      if ($process.ExitCode -eq 0) {
        return $true
      } else {
        Write-Warning "Installation failed with exit code $($process.ExitCode), skipping."
        return $false
      }
    }
    Start-Sleep -Seconds 2
  }

  if (-not $process.HasExited) {
    Write-Warning "Installation timed out after $Timeout seconds, killing process..."
    $process.Kill()
    Write-Warning "Installation of `"$Path`" failed, skipping."
    return $false
  }
}
