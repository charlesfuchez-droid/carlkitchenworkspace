<#
.SYNOPSIS
  Corrige les ustensiles créés par erreur en catégories dans Mealie.

.DESCRIPTION
  - Lit mealie-import.config.json
  - Lit mealie_tools.csv
  - Liste les catégories Mealie
  - Liste les tools/ustensiles Mealie
  - Repère les catégories dont le nom correspond à un ustensile du CSV
  - En DryRun : affiche ce qui serait supprimé/créé
  - En mode réel : supprime ces catégories mal classées, puis crée les tools manquants

.SECURITY
  Le script ne supprime que les catégories dont le nom est exactement présent dans mealie_tools.csv.
  Il ne touche pas aux autres catégories.

.EXAMPLE
  .\fix_tools_created_as_categories.ps1 -DryRun

.EXAMPLE
  .\fix_tools_created_as_categories.ps1 -Apply
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = ".\mealie-import.config.json",
  [string]$ToolsCsv = ".\mealie_tools.csv",
  [switch]$DryRun,
  [switch]$Apply
)

$ErrorActionPreference = "Stop"

function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Bad($Message) { Write-Host "[ERR]  $Message" -ForegroundColor Red }

function Load-Config {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Config introuvable : $Path"
  }

  $cfg = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json

  if ([string]::IsNullOrWhiteSpace($cfg.MealieUrl)) {
    throw "MealieUrl vide dans la config."
  }

  if ([string]::IsNullOrWhiteSpace($cfg.ApiToken) -or $cfg.ApiToken -like "COLLE*") {
    throw "ApiToken non renseigné dans la config."
  }

  $cfg.MealieUrl = $cfg.MealieUrl.TrimEnd("/")
  return $cfg
}

function Invoke-Mealie {
  param(
    [object]$Cfg,
    [string]$Method,
    [string]$Path,
    [object]$Body = $null
  )

  $headers = @{
    Authorization = "Bearer $($Cfg.ApiToken)"
    Accept = "application/json"
  }

  $uri = "$($Cfg.MealieUrl)$Path"

  try {
    if ($null -eq $Body) {
      return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -TimeoutSec 30
    }

    $json = $Body | ConvertTo-Json -Depth 30

    return Invoke-RestMethod `
      -Uri $uri `
      -Method $Method `
      -Headers $headers `
      -ContentType "application/json; charset=utf-8" `
      -Body $json `
      -TimeoutSec 30
  }
  catch {
    $status = $null
    $responseText = ""

    if ($_.Exception.Response) {
      try {
        $status = [int]$_.Exception.Response.StatusCode
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $responseText = $reader.ReadToEnd()
      }
      catch {}
    }

    $msg = "HTTP error on $Method $Path"
    if ($status) { $msg += " - Status $status" }
    if ($responseText) { $msg += " - Response: $responseText" }
    else { $msg += " - $($_.Exception.Message)" }

    throw $msg
  }
}

function Get-OrganizerItems {
  param(
    [object]$Cfg,
    [string]$Endpoint
  )

  $all = @()
  $page = 1
  $perPage = 500

  while ($true) {
    try {
      $res = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path "$Endpoint?page=$page&perPage=$perPage"

      if ($null -ne $res.data) {
        $items = @($res.data)
      }
      elseif ($res -is [System.Collections.IEnumerable]) {
        $items = @($res)
      }
      else {
        $items = @()
      }

      if ($items.Count -eq 0) { break }

      $all += $items

      if ($items.Count -lt $perPage) { break }
      $page++
    }
    catch {
      Write-Warn "Lecture KO sur $Endpoint avec pagination. Nouvel essai sans pagination."
      $res2 = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path $Endpoint

      if ($null -ne $res2.data) { return @($res2.data) }
      if ($res2 -is [System.Collections.IEnumerable]) { return @($res2) }

      return @()
    }
  }

  return $all
}

function Get-ItemId {
  param([object]$Item)

  foreach ($prop in @("id", "slug")) {
    if ($Item.PSObject.Properties.Name -contains $prop) {
      $value = $Item.$prop
      if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
        return [string]$value
      }
    }
  }

  return $null
}

function Item-ExistsByName {
  param(
    [array]$Items,
    [string]$Name
  )

  foreach ($i in $Items) {
    if ($i.name -eq $Name) {
      return $true
    }
  }

  return $false
}

function Delete-OrganizerItem {
  param(
    [object]$Cfg,
    [string]$Endpoint,
    [object]$Item
  )

  $id = Get-ItemId -Item $Item

  if ([string]::IsNullOrWhiteSpace($id)) {
    throw "Impossible de trouver id/slug pour '$($Item.name)'"
  }

  $encodedId = [System.Uri]::EscapeDataString($id)
  return Invoke-Mealie -Cfg $Cfg -Method "DELETE" -Path "$Endpoint/$encodedId"
}

function Create-Tool {
  param(
    [object]$Cfg,
    [string]$Name
  )

  $payloads = @(
    @{ name = $Name },
    @{ name = $Name; description = "" }
  )

  $lastError = $null

  foreach ($payload in $payloads) {
    try {
      return Invoke-Mealie -Cfg $Cfg -Method "POST" -Path "/api/organizers/tools" -Body $payload
    }
    catch {
      $lastError = $_.Exception.Message
    }
  }

  throw $lastError
}

try {
  if (-not $DryRun -and -not $Apply) {
    Write-Warn "Par sécurité, lance d'abord avec -DryRun ou confirme avec -Apply."
    Write-Host ""
    Write-Host "Exemple :"
    Write-Host ".\fix_tools_created_as_categories.ps1 -DryRun"
    Write-Host ".\fix_tools_created_as_categories.ps1 -Apply"
    exit 1
  }

  $cfg = Load-Config -Path $ConfigPath

  if (-not (Test-Path $ToolsCsv)) {
    throw "CSV introuvable : $ToolsCsv"
  }

  $toolNames = Import-Csv -Path $ToolsCsv -Encoding UTF8 |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) } |
    ForEach-Object { $_.Name.Trim() } |
    Sort-Object -Unique

  if ($toolNames.Count -eq 0) {
    throw "Aucun ustensile trouvé dans $ToolsCsv"
  }

  Write-Info "MealieUrl : $($cfg.MealieUrl)"
  Write-Info "Ustensiles référencés dans le CSV : $($toolNames.Count)"

  $categories = Get-OrganizerItems -Cfg $cfg -Endpoint "/api/organizers/categories"
  $tools = Get-OrganizerItems -Cfg $cfg -Endpoint "/api/organizers/tools"

  Write-Info "Catégories existantes : $($categories.Count)"
  Write-Info "Ustensiles existants  : $($tools.Count)"

  $wrongCategories = @()

  foreach ($cat in $categories) {
    if ($toolNames -contains $cat.name) {
      $wrongCategories += $cat
    }
  }

  Write-Host ""
  Write-Warn "Catégories qui ressemblent à des ustensiles : $($wrongCategories.Count)"

  foreach ($wc in $wrongCategories) {
    Write-Host " - $($wc.name)"
  }

  Write-Host ""

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
      Write-Bad "Suppression KO : $($wc.name)"
      Write-Bad $_.Exception.Message
      $failed++
    }
  }

  # Recharge les tools après suppression éventuelle
  $tools = Get-OrganizerItems -Cfg $cfg -Endpoint "/api/organizers/tools"

  foreach ($name in $toolNames) {
    if (Item-ExistsByName -Items $tools -Name $name) {
      Write-Warn "Tool déjà présent : $name"
      $skipped++
      continue
    }

    if ($DryRun) {
      Write-Ok "DRY-RUN : créerait l'ustensile '$name'"
      continue
    }

    try {
      $null = Create-Tool -Cfg $cfg -Name $name
      Write-Ok "Ustensile créé : $name"
      $created++
    }
    catch {
      Write-Bad "Création tool KO : $name"
      Write-Bad $_.Exception.Message
      $failed++
    }
  }

  Write-Host ""
  Write-Ok "Terminé."
  Write-Host "Catégories supprimées : $deleted"
  Write-Host "Ustensiles créés      : $created"
  Write-Host "Ustensiles ignorés    : $skipped"
  Write-Host "Échecs                : $failed"

  if ($DryRun) {
    Write-Warn "Mode DryRun : aucune modification réelle n'a été faite."
  }

  if ($failed -gt 0) { exit 2 }
  exit 0
}
catch {
  Write-Bad $_.Exception.Message
  exit 1
}
