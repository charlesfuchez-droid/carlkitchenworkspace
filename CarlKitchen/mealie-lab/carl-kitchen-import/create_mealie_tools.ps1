<#
.SYNOPSIS
  Crée les ustensiles Carl Kitchen dans Mealie.

.DESCRIPTION
  - Lit la config existante mealie-import.config.json
  - Lit un CSV d'ustensiles : mealie_tools.csv
  - Teste plusieurs endpoints possibles pour les Tools/Ustensiles
  - Crée les ustensiles manquants
  - Ignore ceux déjà existants
  - Loggue les résultats

.NOTES
  À lancer depuis :
  C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = ".\mealie-import.config.json",
  [string]$ToolsCsv = ".\mealie_tools.csv",
  [switch]$DryRun,
  [switch]$Force
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

    $json = $Body | ConvertTo-Json -Depth 20

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

function Test-Endpoint {
  param(
    [object]$Cfg,
    [string[]]$Candidates
  )

  foreach ($candidate in $Candidates) {
    try {
      Write-Info "Test endpoint ustensiles : $candidate"
      $res = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path "$candidate?page=1&perPage=1"
      Write-Ok "Endpoint valide : $candidate"
      return $candidate
    }
    catch {
      Write-Warn "Endpoint KO : $candidate"
    }
  }

  throw "Aucun endpoint Tools/Ustensiles trouvé. Ouvre $($Cfg.MealieUrl)/docs puis recherche 'tools' ou 'organizers'."
}

function Get-AllTools {
  param(
    [object]$Cfg,
    [string]$Endpoint
  )

  $all = @()
  $page = 1
  $perPage = 100

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
      Write-Warn "Impossible de lister tous les ustensiles : $($_.Exception.Message)"
      break
    }
  }

  return $all
}

function Tool-Exists {
  param(
    [array]$ExistingTools,
    [string]$Name
  )

  foreach ($t in $ExistingTools) {
    if ($t.name -eq $Name) { return $true }
  }

  return $false
}

function Create-Tool {
  param(
    [object]$Cfg,
    [string]$Endpoint,
    [string]$Name
  )

  $payloadCandidates = @(
    @{ name = $Name },
    @{ name = $Name; slug = $null },
    @{ name = $Name; description = "" }
  )

  foreach ($payload in $payloadCandidates) {
    try {
      return Invoke-Mealie -Cfg $Cfg -Method "POST" -Path $Endpoint -Body $payload
    }
    catch {
      $lastError = $_.Exception.Message
    }
  }

  throw $lastError
}

try {
  $cfg = Load-Config -Path $ConfigPath

  if (-not (Test-Path $ToolsCsv)) {
    throw "CSV introuvable : $ToolsCsv"
  }

  Write-Info "MealieUrl : $($cfg.MealieUrl)"
  Write-Info "CSV       : $ToolsCsv"

  $endpointCandidates = @(
    "/api/organizers/tools",
    "/api/groups/organizers/tools",
    "/api/tools"
  )

  $endpoint = Test-Endpoint -Cfg $cfg -Candidates $endpointCandidates

  $tools = Import-Csv -Path $ToolsCsv -Encoding UTF8

  if ($tools.Count -eq 0) {
    throw "CSV vide."
  }

  $existing = Get-AllTools -Cfg $cfg -Endpoint $endpoint

  Write-Info "Ustensiles déjà présents : $($existing.Count)"
  Write-Info "Ustensiles à traiter     : $($tools.Count)"

  $created = 0
  $skipped = 0
  $failed = 0

  foreach ($tool in $tools) {
    $name = $tool.Name.Trim()

    if ([string]::IsNullOrWhiteSpace($name)) {
      continue
    }

    if (-not $Force -and (Tool-Exists -ExistingTools $existing -Name $name)) {
      Write-Warn "Déjà présent : $name"
      $skipped++
      continue
    }

    if ($DryRun) {
      Write-Ok "DRY-RUN : créerait l'ustensile '$name'"
      continue
    }

    try {
      $null = Create-Tool -Cfg $cfg -Endpoint $endpoint -Name $name
      Write-Ok "Créé : $name"
      $created++
    }
    catch {
      Write-Bad "Échec création : $name"
      Write-Bad $_.Exception.Message
      $failed++
    }
  }

  Write-Host ""
  Write-Ok "Terminé."
  Write-Host "Créés  : $created"
  Write-Host "Ignorés: $skipped"
  Write-Host "Échecs : $failed"

  if ($failed -gt 0) { exit 2 }
  exit 0
}
catch {
  Write-Bad $_.Exception.Message
  exit 1
}
