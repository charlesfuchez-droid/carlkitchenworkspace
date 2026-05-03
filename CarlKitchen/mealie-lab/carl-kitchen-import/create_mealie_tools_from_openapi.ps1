<#
.SYNOPSIS
  Crée les ustensiles Mealie en découvrant le bon endpoint via /openapi.json.

.DESCRIPTION
  Contrairement à la version précédente, ce script lit réellement l'API locale :
  - GET /openapi.json
  - cherche les endpoints POST liés aux tools / organizers
  - teste les endpoints candidats
  - crée les ustensiles depuis mealie_tools.csv

.PARAMETER ToolsEndpoint
  Permet de forcer l'endpoint si l'auto-détection ne suffit pas.
  Exemple : /api/organizers/tools

.PARAMETER ListOnly
  Affiche les endpoints candidats sans créer les ustensiles.
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = ".\mealie-import.config.json",
  [string]$ToolsCsv = ".\mealie_tools.csv",
  [string]$ToolsEndpoint = "",
  [switch]$DryRun,
  [switch]$ListOnly
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

function Get-OpenApi {
  param([object]$Cfg)

  foreach ($candidate in @("/openapi.json", "/api/openapi.json")) {
    try {
      Write-Info "Lecture OpenAPI : $candidate"
      return Invoke-Mealie -Cfg $Cfg -Method "GET" -Path $candidate
    }
    catch {
      Write-Warn "OpenAPI KO : $candidate"
    }
  }

  throw "Impossible de lire le schéma OpenAPI local."
}

function Get-ToolEndpointCandidatesFromOpenApi {
  param([object]$OpenApi)

  $candidates = @()

  foreach ($pathProp in $OpenApi.paths.PSObject.Properties) {
    $path = $pathProp.Name
    $pathObj = $pathProp.Value

    if ($path -notmatch "(?i)tool|organizer") { continue }

    $hasPost = $false
    $hasGet = $false

    foreach ($methodProp in $pathObj.PSObject.Properties) {
      $m = $methodProp.Name.ToLowerInvariant()
      if ($m -eq "post") { $hasPost = $true }
      if ($m -eq "get") { $hasGet = $true }
    }

    if ($hasPost) {
      # On ignore les endpoints avec paramètres de chemin non résolus.
      # Si Mealie expose /api/groups/{group_slug}/..., il faudra forcer ToolsEndpoint.
      $needsParam = $path -match "\{.+?\}"

      $candidates += [PSCustomObject]@{
        Path = $path
        HasGet = $hasGet
        HasPost = $hasPost
        NeedsPathParam = $needsParam
      }
    }
  }

  return $candidates | Sort-Object NeedsPathParam, Path
}

function Test-ToolEndpoint {
  param(
    [object]$Cfg,
    [string]$Endpoint
  )

  try {
    $null = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path "$Endpoint?page=1&perPage=1"
    return $true
  }
  catch {
    try {
      # Certains endpoints peuvent lister sans pagination.
      $null = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path $Endpoint
      return $true
    }
    catch {
      return $false
    }
  }
}

function Get-ExistingTools {
  param(
    [object]$Cfg,
    [string]$Endpoint
  )

  try {
    $res = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path "$Endpoint?page=1&perPage=500"

    if ($null -ne $res.data) { return @($res.data) }
    if ($res -is [System.Collections.IEnumerable]) { return @($res) }

    return @()
  }
  catch {
    Write-Warn "Impossible de récupérer la liste des ustensiles. Le script continuera sans déduplication."
    return @()
  }
}

function Tool-Exists {
  param([array]$ExistingTools, [string]$Name)

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
    @{ name = $Name; description = "" }
  )

  $last = $null

  foreach ($payload in $payloadCandidates) {
    try {
      return Invoke-Mealie -Cfg $Cfg -Method "POST" -Path $Endpoint -Body $payload
    }
    catch {
      $last = $_.Exception.Message
    }
  }

  throw $last
}

try {
  $cfg = Load-Config -Path $ConfigPath

  if (-not (Test-Path $ToolsCsv)) {
    throw "CSV introuvable : $ToolsCsv"
  }

  $api = Get-OpenApi -Cfg $cfg
  $candidates = Get-ToolEndpointCandidatesFromOpenApi -OpenApi $api

  Write-Host ""
  Write-Info "Endpoints tools/organizers trouvés dans OpenAPI :"
  $candidates | Format-Table Path, HasGet, HasPost, NeedsPathParam -AutoSize

  if ($ListOnly) {
    Write-Ok "ListOnly : aucune création."
    exit 0
  }

  $endpoint = $ToolsEndpoint

  if ([string]::IsNullOrWhiteSpace($endpoint)) {
    foreach ($c in $candidates) {
      if ($c.NeedsPathParam) { continue }

      Write-Info "Test endpoint candidat : $($c.Path)"

      if (Test-ToolEndpoint -Cfg $cfg -Endpoint $c.Path) {
        $endpoint = $c.Path
        break
      }
    }
  }

  if ([string]::IsNullOrWhiteSpace($endpoint)) {
    throw "Endpoint tools non détecté automatiquement. Relance avec -ListOnly puis force avec -ToolsEndpoint."
  }

  Write-Ok "Endpoint tools utilisé : $endpoint"

  $tools = Import-Csv -Path $ToolsCsv -Encoding UTF8
  $existing = Get-ExistingTools -Cfg $cfg -Endpoint $endpoint

  $created = 0
  $skipped = 0
  $failed = 0

  foreach ($tool in $tools) {
    $name = $tool.Name.Trim()

    if ([string]::IsNullOrWhiteSpace($name)) { continue }

    if (Tool-Exists -ExistingTools $existing -Name $name) {
      Write-Warn "Déjà présent : $name"
      $skipped++
      continue
    }

    if ($DryRun) {
      Write-Ok "DRY-RUN : créerait '$name'"
      continue
    }

    try {
      $null = Create-Tool -Cfg $cfg -Endpoint $endpoint -Name $name
      Write-Ok "Créé : $name"
      $created++
    }
    catch {
      Write-Bad "Échec : $name"
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
