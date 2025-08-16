function ConvertFrom-JsonC {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$JsonCContent
  )

  process {
    # Remove single-line comments starting with // or #
    $lines = $JsonCContent -split "`n"
    $cleanLines = foreach ($line in $lines) {
      $trimmed = $line.Trim()
      if (-not ($trimmed.StartsWith("//") -or $trimmed.StartsWith("#"))) {
        # Remove inline comments after // or #
        $line -replace '\s*(//|#).*$', ''
      }
    }

    # Join back into a string
    $cleanJson = ($cleanLines | Where-Object { $_ -ne "" }) -join "`n"

    try {
      return $cleanJson | ConvertFrom-Json
    } catch {
      Write-Error "Nie udało się sparsować JSONC: $_"
      return $null
    }
  }
}

Export-ModuleMember -Function ConvertFrom-JsonC