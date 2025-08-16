function Start-Activation {
  param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [int]$Timeout
  )

  Write-Host "Starting activation script `"$Path`""

  # Create a process start info object
  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = "cmd.exe"
  $startInfo.Arguments = "/c `"$Path`""
  $startInfo.UseShellExecute = $true
  $startInfo.CreateNoWindow = $false

  # Run activation script
  try {
    $process = [System.Diagnostics.Process]::Start($startInfo)
  } catch {
    Write-Warning "Failed to start activation script `"$Path`", skipping."
    return $false
  }

  # Wait for the process to exit or timeout
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $Timeout) {
    if ($process.HasExited) {
      if ($process.ExitCode -eq 0) {
        return $true
      } else {
        Write-Warning "Activation script failed with exit code $($process.ExitCode), skipping."
        return $false
      }
    }
    Start-Sleep -Seconds 2
  }

  # If the process is still running after the timeout, kill it
  if (-not $process.HasExited) {
    Write-Warning "Activation script timed out after $Timeout seconds, killing process..."
    $process.Kill()
    Write-Warning "Activation script `"$Path`" failed, skipping."
    return $false
  }
}