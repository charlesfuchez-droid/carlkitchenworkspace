<#
.SYNOPSIS
  Import configurable de recettes JSON schema.org vers Mealie.

.DESCRIPTION
  Script robuste pour importer des recettes dans Mealie avec :
  - fichier de configuration JSON
  - token API dans la config locale
  - test de connexion
  - dry-run
  - import d'un seul fichier
  - détection de doublons par nom
  - logs détaillés
  - tentative automatique de plusieurs formats de payload
  - fichier d'état pour reprendre sans tout réimporter

.NOTES
  Place ce script à la racine du pack Carl Kitchen, à côté du dossier recipes_schema_org_json.
#>

[CmdletBinding()]
param(
    [string]$ConfigPath = ".\mealie-import.config.json",

    [switch]$TestConnection,

    [switch]$DiscoverImportShape,

    [string]$TestFile,

    [switch]$DryRun,

    [switch]$Force,

    [int]$Limit = 0
)

$ErrorActionPreference = "Stop"

function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Bad($Message) { Write-Host "[ERR]  $Message" -ForegroundColor Red }

function Load-Config {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Fichier de config introuvable : $Path. Copie config.sample.json vers mealie-import.config.json puis renseigne MealieUrl et ApiToken."
    }

    $raw = Get-Content $Path -Raw -Encoding UTF8
    $cfg = $raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($cfg.MealieUrl)) {
        throw "MealieUrl est vide dans la config."
    }

    if ([string]::IsNullOrWhiteSpace($cfg.ApiToken) -or $cfg.ApiToken -like "COLLE*") {
        throw "ApiToken n'est pas renseigné dans la config."
    }

    $cfg.MealieUrl = $cfg.MealieUrl.TrimEnd("/")

    if ([string]::IsNullOrWhiteSpace($cfg.RecipesDirectory)) {
        $cfg | Add-Member -NotePropertyName RecipesDirectory -NotePropertyValue ".\recipes_schema_org_json\01_preparations" -Force
    }

    if ([string]::IsNullOrWhiteSpace($cfg.LogFile)) {
        $cfg | Add-Member -NotePropertyName LogFile -NotePropertyValue ".\mealie-import.log" -Force
    }

    if ([string]::IsNullOrWhiteSpace($cfg.StateFile)) {
        $cfg | Add-Member -NotePropertyName StateFile -NotePropertyValue ".\mealie-import-state.json" -Force
    }

    if ($null -eq $cfg.SkipExisting) {
        $cfg | Add-Member -NotePropertyName SkipExisting -NotePropertyValue $true -Force
    }

    if ($null -eq $cfg.TimeoutSeconds) {
        $cfg | Add-Member -NotePropertyName TimeoutSeconds -NotePropertyValue 30 -Force
    }

    if ($null -eq $cfg.EndpointCandidates -or $cfg.EndpointCandidates.Count -eq 0) {
        $cfg | Add-Member -NotePropertyName EndpointCandidates -NotePropertyValue @(
            "/api/recipes/create/html-or-json",
            "/api/recipes/create-from-html-or-json"
        ) -Force
    }

    if ($null -eq $cfg.PayloadModes -or $cfg.PayloadModes.Count -eq 0) {
        $cfg | Add-Member -NotePropertyName PayloadModes -NotePropertyValue @(
            "data-string",
            "json-string",
            "html-or-json-string",
            "raw-schema-json"
        ) -Force
    }

    return $cfg
}

function Add-Log {
    param(
        [object]$Cfg,
        [string]$Level,
        [string]$Message
    )

    $line = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [$Level] $Message"
    Add-Content -Path $Cfg.LogFile -Value $line -Encoding UTF8
}

function Invoke-Mealie {
    param(
        [object]$Cfg,
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [switch]$RawBody
    )

    $uri = "$($Cfg.MealieUrl)$Path"
    $headers = @{
        Authorization = "Bearer $($Cfg.ApiToken)"
        Accept = "application/json"
    }

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Uri $uri -Method $Method -Headers $headers -TimeoutSec $Cfg.TimeoutSeconds
        }

        if ($RawBody) {
            return Invoke-RestMethod `
                -Uri $uri `
                -Method $Method `
                -Headers $headers `
                -ContentType "application/json; charset=utf-8" `
                -Body $Body `
                -TimeoutSec $Cfg.TimeoutSeconds
        }

        $jsonBody = $Body | ConvertTo-Json -Depth 80
        return Invoke-RestMethod `
            -Uri $uri `
            -Method $Method `
            -Headers $headers `
            -ContentType "application/json; charset=utf-8" `
            -Body $jsonBody `
            -TimeoutSec $Cfg.TimeoutSeconds
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

function Get-RecipeNameFromSchema {
    param([string]$FilePath)

    $raw = Get-Content $FilePath -Raw -Encoding UTF8
    $obj = $raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace($obj.name)) {
        throw "Le fichier $FilePath ne contient pas de champ 'name'."
    }

    return $obj.name
}

function Get-ImportBody {
    param(
        [string]$Mode,
        [string]$RawJson
    )

    switch ($Mode) {
        "data-string" {
            return @{
                data = $RawJson
            }
        }
        "json-string" {
            return @{
                json = $RawJson
            }
        }
        "html-or-json-string" {
            return @{
                htmlOrJson = $RawJson
            }
        }
        "raw-schema-json" {
            return $RawJson
        }
        default {
            throw "Payload mode inconnu : $Mode"
        }
    }
}

function Get-UseRawBody {
    param([string]$Mode)
    return ($Mode -eq "raw-schema-json")
}

function Get-State {
    param([object]$Cfg)

    if (-not (Test-Path $Cfg.StateFile)) {
        return [ordered]@{
            SuccessfulEndpoint = $null
            SuccessfulPayloadMode = $null
            ImportedFiles = @()
            FailedFiles = @()
        }
    }

    try {
        $state = Get-Content $Cfg.StateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        return [ordered]@{
            SuccessfulEndpoint = $state.SuccessfulEndpoint
            SuccessfulPayloadMode = $state.SuccessfulPayloadMode
            ImportedFiles = @($state.ImportedFiles)
            FailedFiles = @($state.FailedFiles)
        }
    }
    catch {
        Write-Warn "Impossible de lire le fichier d'état. Il sera recréé."
        return [ordered]@{
            SuccessfulEndpoint = $null
            SuccessfulPayloadMode = $null
            ImportedFiles = @()
            FailedFiles = @()
        }
    }
}

function Save-State {
    param(
        [object]$Cfg,
        [object]$State
    )

    $State | ConvertTo-Json -Depth 20 | Set-Content -Path $Cfg.StateFile -Encoding UTF8
}

function Escape-FilterLiteral {
    param([string]$Value)
    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Test-RecipeExists {
    param(
        [object]$Cfg,
        [string]$Name
    )

    try {
        $safe = Escape-FilterLiteral $Name
        $filter = [System.Uri]::EscapeDataString("name = `"$safe`"")
        $path = "/api/recipes?page=1&perPage=1&queryFilter=$filter"

        $res = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path $path

        if ($null -ne $res.data -and $res.data.Count -gt 0) {
            return $true
        }

        return $false
    }
    catch {
        Write-Warn "Impossible de vérifier le doublon pour '$Name'. Le script continue. Détail: $($_.Exception.Message)"
        return $false
    }
}

function Test-MealieConnection {
    param([object]$Cfg)

    Write-Info "Test connexion Mealie : $($Cfg.MealieUrl)"

    $aboutPaths = @(
        "/api/app/about",
        "/api/app/about/startup-info",
        "/api/app/about/check"
    )

    foreach ($p in $aboutPaths) {
        try {
            $res = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path $p
            Write-Ok "Connexion OK via $p"
            Add-Log -Cfg $Cfg -Level "OK" -Message "Connexion OK via $p"
            return $true
        }
        catch {
            Write-Warn "Test KO via $p : $($_.Exception.Message)"
            Add-Log -Cfg $Cfg -Level "WARN" -Message "Test KO via $p : $($_.Exception.Message)"
        }
    }

    Write-Warn "Impossible de valider via /api/app/about. On teste /api/recipes."
    try {
        $res = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path "/api/recipes?page=1&perPage=1"
        Write-Ok "Connexion OK via /api/recipes"
        Add-Log -Cfg $Cfg -Level "OK" -Message "Connexion OK via /api/recipes"
        return $true
    }
    catch {
        Write-Bad "Connexion KO. Détail : $($_.Exception.Message)"
        Add-Log -Cfg $Cfg -Level "ERR" -Message "Connexion KO : $($_.Exception.Message)"
        return $false
    }
}

function Show-LocalApiDocsHint {
    param([object]$Cfg)

    Write-Info "Documentation API locale à ouvrir dans le navigateur : $($Cfg.MealieUrl)/docs"
    Write-Info "Si l'import échoue, recherche dans cette page : html-or-json, create, recipes."
}

function Discover-Shape {
    param(
        [object]$Cfg,
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        throw "Fichier de test introuvable : $FilePath"
    }

    $raw = Get-Content $FilePath -Raw -Encoding UTF8
    $name = Get-RecipeNameFromSchema -FilePath $FilePath

    Write-Info "Détection import sur une recette test : $name"
    Write-Warn "Cette étape peut créer une recette dans Mealie si un format fonctionne."

    foreach ($endpoint in $Cfg.EndpointCandidates) {
        foreach ($mode in $Cfg.PayloadModes) {
            Write-Info "Essai endpoint=$endpoint / payload=$mode"

            try {
                $body = Get-ImportBody -Mode $mode -RawJson $raw
                $useRaw = Get-UseRawBody -Mode $mode

                $null = Invoke-Mealie -Cfg $Cfg -Method "POST" -Path $endpoint -Body $body -RawBody:$useRaw

                Write-Ok "Format trouvé : endpoint=$endpoint / payload=$mode"
                Add-Log -Cfg $Cfg -Level "OK" -Message "Format trouvé endpoint=$endpoint payload=$mode"

                $state = Get-State -Cfg $Cfg
                $state.SuccessfulEndpoint = $endpoint
                $state.SuccessfulPayloadMode = $mode
                Save-State -Cfg $Cfg -State $state

                return @{
                    Endpoint = $endpoint
                    PayloadMode = $mode
                }
            }
            catch {
                Write-Warn "Échec : $($_.Exception.Message)"
                Add-Log -Cfg $Cfg -Level "WARN" -Message "Échec endpoint=$endpoint payload=$mode : $($_.Exception.Message)"
            }
        }
    }

    throw "Aucun endpoint/payload n'a fonctionné. Ouvre $($Cfg.MealieUrl)/docs pour vérifier le nom exact de l'endpoint dans ta version Mealie."
}

function Import-OneRecipe {
    param(
        [object]$Cfg,
        [string]$FilePath,
        [string]$Endpoint,
        [string]$PayloadMode,
        [switch]$DryRun,
        [switch]$Force
    )

    $raw = Get-Content $FilePath -Raw -Encoding UTF8
    $name = Get-RecipeNameFromSchema -FilePath $FilePath
    $fileName = Split-Path $FilePath -Leaf

    Write-Info "Recette : $name"

    if ($DryRun) {
        Write-Ok "DRY-RUN : $fileName serait importé."
        return "dry-run"
    }

    if (-not $Force -and $Cfg.SkipExisting) {
        if (Test-RecipeExists -Cfg $Cfg -Name $name) {
            Write-Warn "Déjà présent dans Mealie, ignoré : $name"
            Add-Log -Cfg $Cfg -Level "SKIP" -Message "$fileName / $name déjà présent"
            return "skipped"
        }
    }

    $body = Get-ImportBody -Mode $PayloadMode -RawJson $raw
    $useRaw = Get-UseRawBody -Mode $PayloadMode

    try {
        $null = Invoke-Mealie -Cfg $Cfg -Method "POST" -Path $Endpoint -Body $body -RawBody:$useRaw
        Write-Ok "Import OK : $name"
        Add-Log -Cfg $Cfg -Level "OK" -Message "Import OK : $fileName / $name"
        return "imported"
    }
    catch {
        Write-Bad "Import KO : $name"
        Write-Bad $_.Exception.Message
        Add-Log -Cfg $Cfg -Level "ERR" -Message "Import KO : $fileName / $name / $($_.Exception.Message)"
        return "failed"
    }
}

# MAIN
try {
    $cfg = Load-Config -Path $ConfigPath

    Write-Info "Config chargée : $ConfigPath"
    Write-Info "MealieUrl : $($cfg.MealieUrl)"
    Write-Info "RecipesDirectory : $($cfg.RecipesDirectory)"
    Write-Info "LogFile : $($cfg.LogFile)"
    Show-LocalApiDocsHint -Cfg $cfg

    if ($TestConnection) {
        $ok = Test-MealieConnection -Cfg $cfg
        if (-not $ok) { exit 1 }
        exit 0
    }

    if (-not (Test-MealieConnection -Cfg $cfg)) {
        throw "Connexion Mealie impossible. Corrige MealieUrl / ApiToken dans la config."
    }

    $state = Get-State -Cfg $cfg

    $testFileToUse = $TestFile
    if ([string]::IsNullOrWhiteSpace($testFileToUse)) {
        $first = Get-ChildItem -Path $cfg.RecipesDirectory -Filter "*.json" -File | Sort-Object Name | Select-Object -First 1
        if ($first) { $testFileToUse = $first.FullName }
    }

    if ($DiscoverImportShape -or [string]::IsNullOrWhiteSpace($state.SuccessfulEndpoint) -or [string]::IsNullOrWhiteSpace($state.SuccessfulPayloadMode)) {
        if ([string]::IsNullOrWhiteSpace($testFileToUse)) {
            throw "Aucun fichier JSON trouvé pour tester l'import."
        }

        $shape = Discover-Shape -Cfg $cfg -FilePath $testFileToUse
        $state = Get-State -Cfg $cfg
    }

    $endpoint = $state.SuccessfulEndpoint
    $payloadMode = $state.SuccessfulPayloadMode

    if ([string]::IsNullOrWhiteSpace($endpoint) -or [string]::IsNullOrWhiteSpace($payloadMode)) {
        throw "Aucun format d'import validé. Lance avec -DiscoverImportShape -TestFile chemin\vers\P01.json"
    }

    Write-Ok "Import configuré avec endpoint=$endpoint / payload=$payloadMode"

    if (-not [string]::IsNullOrWhiteSpace($TestFile)) {
        if (-not (Test-Path $TestFile)) { throw "Fichier test introuvable : $TestFile" }

        $result = Import-OneRecipe -Cfg $cfg -FilePath $TestFile -Endpoint $endpoint -PayloadMode $payloadMode -DryRun:$DryRun -Force:$Force
        exit 0
    }

    $files = Get-ChildItem -Path $cfg.RecipesDirectory -Filter "*.json" -File | Sort-Object Name

    if ($Limit -gt 0) {
        $files = $files | Select-Object -First $Limit
    }

    if ($files.Count -eq 0) {
        throw "Aucun fichier JSON trouvé dans $($cfg.RecipesDirectory)"
    }

    Write-Info "Nombre de fichiers à traiter : $($files.Count)"

    $imported = 0
    $skipped = 0
    $failed = 0
    $dry = 0

    foreach ($f in $files) {
        $result = Import-OneRecipe -Cfg $cfg -FilePath $f.FullName -Endpoint $endpoint -PayloadMode $payloadMode -DryRun:$DryRun -Force:$Force

        switch ($result) {
            "imported" { $imported++ }
            "skipped" { $skipped++ }
            "failed" { $failed++ }
            "dry-run" { $dry++ }
        }
    }

    Write-Host ""
    Write-Ok "Terminé."
    Write-Host "Importés : $imported"
    Write-Host "Ignorés  : $skipped"
    Write-Host "Échecs   : $failed"
    Write-Host "Dry-run  : $dry"
    Write-Host "Logs     : $($cfg.LogFile)"

    if ($failed -gt 0) {
        exit 2
    }

    exit 0
}
catch {
    Write-Bad $_.Exception.Message
    exit 1
}
