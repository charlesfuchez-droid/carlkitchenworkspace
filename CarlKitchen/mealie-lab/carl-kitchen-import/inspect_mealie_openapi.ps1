<#
.SYNOPSIS
  Inspecte l'API locale Mealie via OpenAPI.

.DESCRIPTION
  Ce script utilise réellement le schéma OpenAPI local derrière /docs :
  - GET /openapi.json
  - Liste tous les endpoints disponibles
  - Filtre les endpoints recipes/tools/organizers/tags/categories
  - Exporte un CSV pour analyse

.NOTES
  À lancer depuis :
  C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = ".\mealie-import.config.json",
  [string]$Keyword = "tool|organizer|recipe|tag|categor|html|json",
  [string]$OutCsv = ".\mealie_openapi_endpoints.csv"
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

  $cfg.MealieUrl = $cfg.MealieUrl.TrimEnd("/")
  return $cfg
}

function Invoke-MealieJson {
  param(
    [object]$Cfg,
    [string]$Path
  )

  $headers = @{
    Accept = "application/json"
  }

  if (-not [string]::IsNullOrWhiteSpace($Cfg.ApiToken) -and $Cfg.ApiToken -notlike "COLLE*") {
    $headers.Authorization = "Bearer $($Cfg.ApiToken)"
  }

  return Invoke-RestMethod `
    -Uri "$($Cfg.MealieUrl)$Path" `
    -Method GET `
    -Headers $headers `
    -TimeoutSec 30
}

try {
  $cfg = Load-Config -Path $ConfigPath

  Write-Info "MealieUrl : $($cfg.MealieUrl)"
  Write-Info "Lecture du schéma OpenAPI local..."

  $openApiCandidates = @(
    "/openapi.json",
    "/api/openapi.json"
  )

  $api = $null
  $usedPath = $null

  foreach ($candidate in $openApiCandidates) {
    try {
      Write-Info "Essai : $candidate"
      $api = Invoke-MealieJson -Cfg $cfg -Path $candidate
      $usedPath = $candidate
      break
    }
    catch {
      Write-Warn "KO : $candidate"
    }
  }

  if ($null -eq $api) {
    throw "Impossible de lire /openapi.json. Vérifie dans le navigateur : $($cfg.MealieUrl)/openapi.json"
  }

  Write-Ok "OpenAPI chargé via $usedPath"

  if ($api.info) {
    Write-Host ""
    Write-Host "API title   : $($api.info.title)"
    Write-Host "API version : $($api.info.version)"
  }

  $rows = @()

  foreach ($pathProp in $api.paths.PSObject.Properties) {
    $path = $pathProp.Name
    $pathObj = $pathProp.Value

    foreach ($methodProp in $pathObj.PSObject.Properties) {
      $method = $methodProp.Name.ToUpperInvariant()

      if ($method -notin @("GET", "POST", "PUT", "PATCH", "DELETE")) {
        continue
      }

      $op = $methodProp.Value
      $summary = ""
      $operationId = ""
      $tags = ""

      if ($op.summary) { $summary = $op.summary }
      if ($op.operationId) { $operationId = $op.operationId }
      if ($op.tags) { $tags = ($op.tags -join ";") }

      $rows += [PSCustomObject]@{
        Method = $method
        Path = $path
        Tags = $tags
        OperationId = $operationId
        Summary = $summary
      }
    }
  }

  $rows | Sort-Object Path, Method | Export-Csv -Path $OutCsv -NoTypeInformation -Encoding UTF8

  Write-Ok "CSV exporté : $OutCsv"
  Write-Host ""
  Write-Host "Endpoints filtrés avec keyword : $Keyword"
  Write-Host ""

  $filtered = $rows | Where-Object {
    $_.Path -match $Keyword -or
    $_.Tags -match $Keyword -or
    $_.OperationId -match $Keyword -or
    $_.Summary -match $Keyword
  } | Sort-Object Path, Method

  $filtered | Format-Table Method, Path, Tags, OperationId, Summary -AutoSize

  Write-Host ""
  Write-Ok "Terminé."
  Write-Info "Pour chercher seulement les ustensiles :"
  Write-Host ".\inspect_mealie_openapi.ps1 -ConfigPath .\mealie-import.config.json -Keyword `"tool|organizer`""
  Write-Info "Pour chercher l'import recette :"
  Write-Host ".\inspect_mealie_openapi.ps1 -ConfigPath .\mealie-import.config.json -Keyword `"html|json|create|recipe`""
}
catch {
  Write-Bad $_.Exception.Message
  exit 1
}
