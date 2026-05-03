<#
ASCII-safe Mealie image uploader.
No accents or special unicode chars in script code, to avoid Windows PowerShell parser issues.
Run from: C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = ".\mealie-import.config.json",
  [string]$RecipeName = "",
  [string]$RecipeSlug = "",
  [string]$ImagePath = "",
  [switch]$UseLatestDownload,
  [string]$DownloadsDirectory = "$env:USERPROFILE\Downloads",
  [string]$ImagesDirectory = ".\recipe_images",
  [switch]$ListCandidates,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Info($Message) { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
function Write-Ok($Message) { Write-Host "[OK]   $Message" -ForegroundColor Green }
function Write-Warn($Message) { Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Bad($Message) { Write-Host "[ERR]  $Message" -ForegroundColor Red }

function Load-Config {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Config file not found: $Path"
  }

  $cfg = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json

  if ([string]::IsNullOrWhiteSpace($cfg.MealieUrl)) {
    throw "MealieUrl is empty in config."
  }

  if ([string]::IsNullOrWhiteSpace($cfg.ApiToken) -or $cfg.ApiToken -like "COLLE*") {
    throw "ApiToken is missing in config."
  }

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

function Invoke-Mealie {
  param(
    [object]$Cfg,
    [string]$Method,
    [string]$Path,
    [object]$Body = $null
  )

  $headers = Get-Headers -Cfg $Cfg
  $uri = "$($Cfg.MealieUrl)$Path"

  try {
    if ($null -eq $Body) {
      return Invoke-WebRequest `
        -Uri $uri `
        -Headers $headers `
        -Method $Method `
        -UseBasicParsing `
        -TimeoutSec 30
    }

    $json = $Body | ConvertTo-Json -Depth 80

    return Invoke-WebRequest `
      -Uri $uri `
      -Headers $headers `
      -Method $Method `
      -ContentType "application/json" `
      -Body $json `
      -UseBasicParsing `
      -TimeoutSec 30
  }
  catch {
    $status = $null
    $bodyText = ""

    if ($_.Exception.Response) {
      try {
        $status = [int]$_.Exception.Response.StatusCode
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $bodyText = $reader.ReadToEnd()
      }
      catch {}
    }

    $msg = "HTTP error on $Method $Path"
    if ($status) { $msg += " - Status $status" }
    if ($bodyText) { $msg += " - Response: $bodyText" }
    else { $msg += " - $($_.Exception.Message)" }

    throw $msg
  }
}

function Parse-JsonContent {
  param([object]$WebResponse)

  if ($null -eq $WebResponse -or [string]::IsNullOrWhiteSpace($WebResponse.Content)) {
    return $null
  }

  return $WebResponse.Content | ConvertFrom-Json
}

function Convert-ResponseToItems {
  param([object]$WebResponse)

  $json = Parse-JsonContent -WebResponse $WebResponse
  if ($null -eq $json) { return @() }

  if ($json -is [System.Array]) { return @($json) }

  foreach ($prop in @("data", "items", "results")) {
    if ($json.PSObject.Properties.Name -contains $prop) {
      $v = $json.$prop
      if ($null -eq $v) { return @() }
      if ($v -is [System.Array]) { return @($v) }
      return @($v)
    }
  }

  if ($json.PSObject.Properties.Name -contains "name") { return @($json) }

  return @()
}

function Get-AllRecipes {
  param([object]$Cfg)

  $all = @()
  $page = 1
  $perPage = 500

  while ($true) {
    try {
      $path = "/api/recipes?page=$page" + "&perPage=$perPage"
      $res = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path $path
      $items = Convert-ResponseToItems -WebResponse $res

      if ($items.Count -eq 0) {
        if ($page -eq 1) {
          $res2 = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path "/api/recipes"
          return Convert-ResponseToItems -WebResponse $res2
        }
        break
      }

      $all += $items
      if ($items.Count -lt $perPage) { break }
      $page++
    }
    catch {
      Write-Warn "Paged recipe list failed: $($_.Exception.Message)"
      $res2 = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path "/api/recipes"
      return Convert-ResponseToItems -WebResponse $res2
    }
  }

  return $all
}

function Find-Recipe {
  param(
    [array]$Recipes,
    [string]$Name,
    [string]$Slug
  )

  if (-not [string]::IsNullOrWhiteSpace($Slug)) {
    foreach ($r in $Recipes) {
      if ($r.slug -eq $Slug) { return $r }
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($Name)) {
    foreach ($r in $Recipes) {
      if ($r.name -eq $Name) { return $r }
    }

    foreach ($r in $Recipes) {
      if ($r.name -like "*$Name*") { return $r }
    }

    foreach ($r in $Recipes) {
      if ($Name -like "*$($r.name)*") { return $r }
    }
  }

  return $null
}

function Resolve-LatestImage {
  param([string]$Dir)

  if (-not (Test-Path $Dir)) {
    throw "Downloads directory not found: $Dir"
  }

  $exts = @("*.png", "*.jpg", "*.jpeg", "*.webp")
  $files = @()

  foreach ($ext in $exts) {
    $files += Get-ChildItem -Path $Dir -Filter $ext -File -ErrorAction SilentlyContinue
  }

  if ($files.Count -eq 0) {
    throw "No image found in: $Dir"
  }

  return $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Convert-ToSafeFileName {
  param([string]$Text)

  $safe = $Text.ToLowerInvariant()
  $safe = $safe -replace "[^a-z0-9]+", "_"
  $safe = $safe.Trim("_")

  if ([string]::IsNullOrWhiteSpace($safe)) {
    return "recipe_image"
  }

  return $safe
}

function Get-MimeType {
  param([string]$Path)

  $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()

  switch ($ext) {
    ".jpg"  { return "image/jpeg" }
    ".jpeg" { return "image/jpeg" }
    ".png"  { return "image/png" }
    ".webp" { return "image/webp" }
    default { return "application/octet-stream" }
  }
}

function Get-OpenApi {
  param([object]$Cfg)

  foreach ($candidate in @("/openapi.json", "/api/openapi.json")) {
    try {
      $res = Invoke-Mealie -Cfg $Cfg -Method "GET" -Path $candidate
      return Parse-JsonContent -WebResponse $res
    }
    catch {
      Write-Warn "OpenAPI failed: $candidate"
    }
  }

  return $null
}

function Get-ImageEndpointCandidates {
  param(
    [object]$OpenApi,
    [string]$Slug
  )

  $candidates = @()

  if ($null -ne $OpenApi -and $null -ne $OpenApi.paths) {
    foreach ($pathProp in $OpenApi.paths.PSObject.Properties) {
      $rawPath = $pathProp.Name
      $pathObj = $pathProp.Value

      if ($rawPath -notmatch "(?i)recipe") { continue }
      if ($rawPath -notmatch "(?i)image|asset|media|photo") { continue }

      foreach ($methodProp in $pathObj.PSObject.Properties) {
        $method = $methodProp.Name.ToUpperInvariant()
        if ($method -notin @("POST", "PUT", "PATCH")) { continue }

        $path = $rawPath
        $path = $path -replace "\{slug\}", $Slug
        $path = $path -replace "\{recipe_slug\}", $Slug
        $path = $path -replace "\{recipeSlug\}", $Slug

        if ($path -match "\{.+?\}") { continue }

        $summary = ""
        if ($methodProp.Value.summary) { $summary = $methodProp.Value.summary }

        $candidates += [PSCustomObject]@{
          Method = $method
          Path = $path
          Source = "openapi"
          Summary = $summary
        }
      }
    }
  }

  $fallbacks = @(
    [PSCustomObject]@{ Method = "PUT";  Path = "/api/recipes/$Slug/image"; Source = "fallback"; Summary = "Fallback recipe image" },
    [PSCustomObject]@{ Method = "POST"; Path = "/api/recipes/$Slug/image"; Source = "fallback"; Summary = "Fallback recipe image" },
    [PSCustomObject]@{ Method = "PUT";  Path = "/api/recipes/$Slug/assets"; Source = "fallback"; Summary = "Fallback recipe assets" },
    [PSCustomObject]@{ Method = "POST"; Path = "/api/recipes/$Slug/assets"; Source = "fallback"; Summary = "Fallback recipe assets" }
  )

  foreach ($f in $fallbacks) {
    $exists = $false
    foreach ($c in $candidates) {
      if ($c.Method -eq $f.Method -and $c.Path -eq $f.Path) { $exists = $true }
    }
    if (-not $exists) { $candidates += $f }
  }

  return $candidates
}

function Invoke-MultipartUpload {
  param(
    [object]$Cfg,
    [string]$Method,
    [string]$Path,
    [string]$FilePath,
    [string]$FieldName
  )

  Add-Type -AssemblyName System.Net.Http

  $client = New-Object System.Net.Http.HttpClient
  $client.Timeout = [TimeSpan]::FromSeconds(60)
  $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $Cfg.ApiToken)
  $client.DefaultRequestHeaders.Accept.Clear()
  $client.DefaultRequestHeaders.Accept.Add([System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new("application/json"))

  $uri = "$($Cfg.MealieUrl)$Path"
  $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::new($Method), $uri)

  $multipart = New-Object System.Net.Http.MultipartFormDataContent
  $bytes = [System.IO.File]::ReadAllBytes($FilePath)
  $fileContent = New-Object System.Net.Http.ByteArrayContent(,$bytes)

  $mime = Get-MimeType -Path $FilePath
  $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($mime)

  $fileName = [System.IO.Path]::GetFileName($FilePath)
  $multipart.Add($fileContent, $FieldName, $fileName)

  $request.Content = $multipart

  $response = $client.SendAsync($request).Result
  $responseBody = $response.Content.ReadAsStringAsync().Result

  if (-not $response.IsSuccessStatusCode) {
    throw "HTTP $([int]$response.StatusCode) $($response.ReasonPhrase) - $responseBody"
  }

  return $responseBody
}

try {
  $cfg = Load-Config -Path $ConfigPath

  Write-Info "MealieUrl: $($cfg.MealieUrl)"

  if ([string]::IsNullOrWhiteSpace($RecipeName) -and [string]::IsNullOrWhiteSpace($RecipeSlug)) {
    throw "Provide -RecipeName or -RecipeSlug."
  }

  $recipes = Get-AllRecipes -Cfg $cfg
  Write-Info "Recipes found: $($recipes.Count)"

  $recipe = Find-Recipe -Recipes $recipes -Name $RecipeName -Slug $RecipeSlug

  if ($null -eq $recipe) {
    throw "Recipe not found. Use -RecipeSlug or check the exact name in Mealie."
  }

  $slug = $recipe.slug
  Write-Ok "Recipe found: $($recipe.name) / slug=$slug"

  if ([string]::IsNullOrWhiteSpace($ImagePath)) {
    $latest = Resolve-LatestImage -Dir $DownloadsDirectory
    $ImagePath = $latest.FullName
  }

  if (-not (Test-Path $ImagePath)) {
    throw "Image not found: $ImagePath"
  }

  $sourceImage = Get-Item $ImagePath
  Write-Ok "Image source: $($sourceImage.FullName)"

  New-Item -ItemType Directory -Force -Path $ImagesDirectory | Out-Null

  $safeBase = Convert-ToSafeFileName -Text $recipe.slug
  $ext = [System.IO.Path]::GetExtension($sourceImage.Name)
  if ([string]::IsNullOrWhiteSpace($ext)) { $ext = ".png" }

  $localImagePath = Join-Path $ImagesDirectory "$safeBase$ext"
  Copy-Item -Path $sourceImage.FullName -Destination $localImagePath -Force
  Write-Ok "Image copied to: $localImagePath"

  $openapi = Get-OpenApi -Cfg $cfg
  $candidates = Get-ImageEndpointCandidates -OpenApi $openapi -Slug $slug

  Write-Info "Image endpoint candidates: $($candidates.Count)"

  if ($ListCandidates) {
    $candidates | Format-Table Method, Path, Source, Summary -AutoSize
    exit 0
  }

  if ($DryRun) {
    Write-Ok "DRY-RUN: no upload."
    $candidates | Format-Table Method, Path, Source, Summary -AutoSize
    exit 0
  }

  $fieldNames = @("image", "file", "data")
  $success = $false
  $lastError = ""

  foreach ($candidate in $candidates) {
    foreach ($field in $fieldNames) {
      Write-Info "Trying upload: $($candidate.Method) $($candidate.Path) / field=$field"

      try {
        $response = Invoke-MultipartUpload `
          -Cfg $cfg `
          -Method $candidate.Method `
          -Path $candidate.Path `
          -FilePath $localImagePath `
          -FieldName $field

        Write-Ok "Image uploaded successfully."
        Write-Ok "Endpoint: $($candidate.Method) $($candidate.Path)"
        Write-Ok "Field: $field"

        if (-not [string]::IsNullOrWhiteSpace($response)) {
          Write-Info "Response: $response"
        }

        $success = $true
        break
      }
      catch {
        $lastError = $_.Exception.Message
        Write-Warn "Failed: $lastError"
      }
    }

    if ($success) { break }
  }

  if (-not $success) {
    throw "No upload candidate worked. Last error: $lastError. Run with -ListCandidates and send me the output."
  }

  Write-Host ""
  Write-Ok "Done. Check recipe in Mealie: $($recipe.name)"
}
catch {
  Write-Bad $_.Exception.Message
  exit 1
}
