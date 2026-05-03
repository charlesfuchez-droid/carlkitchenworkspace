<#
.SYNOPSIS
  V3 - Gestion fiable des ustensiles Mealie.

.DESCRIPTION
  Utilise exactement la méthode validée manuellement :
  POST /api/organizers/tools avec body { "name": "..." }

  Fonctions :
  - liste tools et catégories
  - supprime les catégories créées par erreur qui portent un nom d'ustensile
  - crée les tools manquants
  - ignore les doublons
  - supprime le tool de test "Test Carl Tool" si demandé

.EXAMPLES
  .\mealie_tools_v3.ps1 -List

  .\mealie_tools_v3.ps1 -DryRun

  .\mealie_tools_v3.ps1 -Apply

  .\mealie_tools_v3.ps1 -DeleteTestTool
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = ".\mealie-import.config.json",
  [string]$ToolsCsv = ".\mealie_tools.csv",
  [switch]$List,
  [switch]$DryRun,
  [switch]$Apply,
  [switch]$DeleteTestTool
)

$ErrorActionPreference = "Stop"

function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Bad($Message) { Write-Host "[ERR]  $Message" -ForegroundColor Red }

function Load-Config {
  param([string]$Path)

  if (-not (Test-Path $Path)) { throw "Config introuvable : $Path" }

  $cfg = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json

  if ([string]::IsNullOrWhiteSpace($cfg.MealieUrl)) { throw "MealieUrl vide dans la config." }
  if ([string]::IsNullOrWhiteSpace($cfg.ApiToken) -or $cfg.ApiToken -like "COLLE*") { throw "ApiToken non renseigné dans la config." }

  $cfg.MealieUrl = $cfg.MealieUrl.TrimEnd("/")
  return $cfg
}

function Get-Headers {
  param([object]$Cfg)

  return @{
    Authorization = "Bearer $($Cfg.ApiToken)"
    Accept = "application/json"
  }
}

function Invoke-MealieWeb {
  param(
    [object]$Cfg,
    [string]$Method,
    [string]$Path,
    [object]$Body = $null
  )

  $headers = Get-Headers -Cfg $Cfg
  $uri = "$($Cfg.MealieUrl)$Path"

  if ($null -eq $Body) {
    return Invoke-WebRequest `
      -Uri $uri `
      -Headers $headers `
      -Method $Method `
      -UseBasicParsing `
      -TimeoutSec 30
  }

  $json = $Body | ConvertTo-Json -Depth 20

  return Invoke-WebRequest `
    -Uri $uri `
    -Headers $headers `
    -Method $Method `
    -ContentType "application/json" `
    -Body $json `
    -UseBasicParsing `
    -TimeoutSec 30
}

function Convert-ResponseToItems {
  param([object]$WebResponse)

  if ($null -eq $WebResponse) { return @() }
  if ([string]::IsNullOrWhiteSpace($WebResponse.Content)) { return @() }

  $json = $WebResponse.Content | ConvertFrom-Json

  if ($null -eq $json) { return @() }

  # Réponse tableau direct
  if ($json -is [System.Array]) { return @($json) }

  # Réponse paginée ou enveloppée
  foreach ($prop in @("data", "items", "results")) {
    if ($json.PSObject.Properties.Name -contains $prop) {
      $v = $json.$prop
      if ($null -eq $v) { return @() }
      if ($v -is [System.Array]) { return @($v) }
      return @($v)
    }
  }

  # Objet unique
  if ($json.PSObject.Properties.Name -contains "name") {
    return @($json)
  }

  return @()
}

function Get-OrganizerItems {
  param(
    [object]$Cfg,
    [string]$Endpoint
  )

  try {
    $res = Invoke-MealieWeb -Cfg $Cfg -Method "GET" -Path $Endpoint
    return Convert-ResponseToItems -WebResponse $res
  }
  catch {
    Write-Bad "Lecture KO : $Endpoint"
    Write-Bad $_.Exception.Message
    return @()
  }
}

function Find-ItemByName {
  param(
    [array]$Items,
    [string]$Name
  )

  foreach ($i in $Items) {
    if ($i.name -eq $Name) { return $i }
  }

  return $null
}

function Get-ItemId {
  param([object]$Item)

  foreach ($prop in @("id", "slug")) {
    if ($Item.PSObject.Properties.Name -contains $prop) {
      $v = $Item.$prop
      if (-not [string]::IsNullOrWhiteSpace([string]$v)) {
        return [string]$v
      }
    }
  }

  return $null
}

function Delete-OrganizerItem {
  param(
    [object]$Cfg,
    [string]$Endpoint,
    [object]$Item
  )

  $id = Get-ItemId -Item $Item
  if ([string]::IsNullOrWhiteSpace($id)) {
    throw "Impossible de trouver id/slug pour $($Item.name)"
  }

  $encoded = [System.Uri]::EscapeDataString($id)
  return Invoke-MealieWeb -Cfg $Cfg -Method "DELETE" -Path "$Endpoint/$encoded"
}

function Create-Tool {
  param(
    [object]$Cfg,
    [string]$Name
  )

  return Invoke-MealieWeb `
    -Cfg $Cfg `
    -Method "POST" `
    -Path "/api/organizers/tools" `
    -Body @{ name = $Name }
}

function Read-HttpErrorBody {
  param([object]$ErrorRecord)

  try {
    $stream = $ErrorRecord.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($stream)
    return $reader.ReadToEnd()
  }
  catch {
    return ""
  }
}

try {
  $cfg = Load-Config -Path $ConfigPath

  if (-not (Test-Path $ToolsCsv)) {
    throw "CSV introuvable : $ToolsCsv"
  }

  $toolNames = Import-Csv -Path $ToolsCsv -Encoding UTF8 |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } |
    ForEach-Object { $_.Name.Trim() } |
    Sort-Object -Unique

  Write-Info "MealieUrl : $($cfg.MealieUrl)"
  Write-Info "Ustensiles dans CSV : $($toolNames.Count)"

  $categories = Get-OrganizerItems -Cfg $cfg -Endpoint "/api/organizers/categories"
  $tools = Get-OrganizerItems -Cfg $cfg -Endpoint "/api/organizers/tools"

  Write-Info "Catégories détectées : $($categories.Count)"
  Write-Info "Tools détectés       : $($tools.Count)"

  if ($List) {
    Write-Host ""
    Write-Info "Catégories :"
    $categories | Sort-Object name | Select-Object name, id, slug | Format-Table -AutoSize

    Write-Host ""
    Write-Info "Tools :"
    $tools | Sort-Object name | Select-Object name, id, slug | Format-Table -AutoSize

    exit 0
  }

  if ($DeleteTestTool) {
    $test = Find-ItemByName -Items $tools -Name "Test Carl Tool"

    if ($null -eq $test) {
      Write-Warn "Tool de test introuvable : Test Carl Tool"
      exit 0
    }

    $null = Delete-OrganizerItem -Cfg $cfg -Endpoint "/api/organizers/tools" -Item $test
    Write-Ok "Tool de test supprimé : Test Carl Tool"
    exit 0
  }

  if (-not $DryRun -and -not $Apply) {
    Write-Warn "Choisis un mode : -List, -DryRun, -Apply ou -DeleteTestTool"
    exit 1
  }

  $wrongCategories = @()
  foreach ($cat in $categories) {
    if ($toolNames -contains $cat.name) {
      $wrongCategories += $cat
    }
  }

  Write-Host ""
  Write-Warn "Catégories à supprimer car ce sont des ustensiles : $($wrongCategories.Count)"
  foreach ($wc in $wrongCategories) {
    Write-Host " - $($wc.name)"
  }

  $deleted = 0
  $created = 0
  $skipped = 0
  $failed = 0

  foreach ($wc in $wrongCategories) {
    if ($DryRun) {
      Write-Warn "DRY-RUN : supprimerait la catégorie '$($wc.name)'"
      continue
    }

    try {
      $null = Delete-OrganizerItem -Cfg $cfg -Endpoint "/api/organizers/categories" -Item $wc
      Write-Ok "Catégorie supprimée : $($wc.name)"
      $deleted++
    }
    catch {
      Write-Bad "Suppression catégorie KO : $($wc.name)"
      Write-Bad $_.Exception.Message
      $failed++
    }
  }

  # Recharge les tools après suppressions éventuelles
  $tools = Get-OrganizerItems -Cfg $cfg -Endpoint "/api/organizers/tools"

  foreach ($name in $toolNames) {
    $existing = Find-ItemByName -Items $tools -Name $name

    if ($null -ne $existing) {
      Write-Warn "Tool déjà présent : $name"
      $skipped++
      continue
    }

    if ($DryRun) {
      Write-Ok "DRY-RUN : créerait le tool '$name'"
      continue
    }

    try {
      $res = Create-Tool -Cfg $cfg -Name $name
      Write-Ok "Tool créé : $name"
      $created++
    }
    catch {
      $body = Read-HttpErrorBody -ErrorRecord $_

      Write-Warn "POST KO pour '$name'. Vérification s'il existe déjà..."
      $toolsAfter = Get-OrganizerItems -Cfg $cfg -Endpoint "/api/organizers/tools"
      $existingAfter = Find-ItemByName -Items $toolsAfter -Name $name

      if ($null -ne $existingAfter) {
        Write-Warn "Tool déjà présent après vérification : $name"
        $skipped++
      }
      else {
        Write-Bad "Création tool KO : $name"
        Write-Bad $_.Exception.Message
        if (-not [string]::IsNullOrWhiteSpace($body)) {
          Write-Bad "Réponse Mealie : $body"
        }
        $failed++
      }
    }
  }

  Write-Host ""
  Write-Ok "Terminé."
  Write-Host "Catégories supprimées : $deleted"
  Write-Host "Tools créés           : $created"
  Write-Host "Tools ignorés         : $skipped"
  Write-Host "Échecs                : $failed"

  if ($DryRun) {
    Write-Warn "Mode DryRun : aucune modification réelle."
  }

  if ($failed -gt 0) { exit 2 }
  exit 0
}
catch {
  Write-Bad $_.Exception.Message
  exit 1
}
