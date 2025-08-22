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

function ConvertTo-FlatObject {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    $InputObject,
    [string]$Prefix = ''
  )

  $result = @{}

  if ($null -eq $InputObject) { return $result }

  # Hashtable / IDictionary
  if ($InputObject -is [System.Collections.IDictionary]) {
    foreach ($key in $InputObject.Keys) {
      $val = $InputObject[$key]
      $newPrefix = if ($Prefix) { "$Prefix`_$key" } else { "$key" }
      $result += ConvertTo-FlatObject -InputObject $val -Prefix $newPrefix
    }
    return $result
  }

  # PSCustomObject
  if ($InputObject -is [psobject]) {
    foreach ($p in $InputObject.PSObject.Properties) {
      $newPrefix = if ($Prefix) { "$Prefix`_$($p.Name)" } else { "$($p.Name)" }
      $result += ConvertTo-FlatObject -InputObject $p.Value -Prefix $newPrefix
    }
    return $result
  }

  # Array - index: Section_0_Field (in case they appear)
  if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
    $i = 0
    foreach ($item in $InputObject) {
      $newPrefix = if ($Prefix) { "$Prefix`_$i" } else { "$i" }
      $result += ConvertTo-FlatObject -InputObject $item -Prefix $newPrefix
      $i++
    }
    return $result
  }

  # Simple value
  $result[$Prefix] = $InputObject
  return $result
}

function ConvertFrom-JsonCTyped {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$JsonCContent,
    [Parameter(Mandatory)]
    [Type]$Type
  )

  # Step 1: JSONC -> PSCustomObject
  $raw = ConvertFrom-JsonC -JsonCContent $JsonCContent
  if ($null -eq $raw) {
    throw "Nie udało się sparsować JSONC do PSCustomObject."
  }

  # Step 2: Flatten to A_B_C key map
  $flat = ConvertTo-FlatObject -InputObject $raw

  # Step 3: Create an instance of the target class
  $typed = [Activator]::CreateInstance($Type)

  foreach ($prop in $Type.GetProperties()) {   # <— WARNING: .GetProperties(), nie ::
    $name = $prop.Name
    if ($flat.ContainsKey($name)) {
      $value = $flat[$name]

      try {
        # Solid type casting with error on incompatible type
        $converted = [System.Management.Automation.LanguagePrimitives]::ConvertTo($value, $prop.PropertyType)
      } catch {
        throw "Nie można skonwertować właściwości '$name' o wartości '$value' do typu $($prop.PropertyType.FullName): $_"
      }

      $prop.SetValue($typed, $converted)
    }
    # No key -> default value remains (null/0/False)
  }

  return ($typed -as $Type)
}

Export-ModuleMember -Function ConvertFrom-JsonC, ConvertFrom-JsonCTyped
