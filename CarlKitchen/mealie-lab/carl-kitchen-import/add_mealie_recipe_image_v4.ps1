<#
Mealie recipe image uploader V4.
ASCII-safe script.

This version uses the API contract discovered from Mealie:
PUT /api/recipes/{slug}/image
multipart/form-data:
- image: binary file
- extension: png/jpg/jpeg/webp

Run from:
C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
#>

[CmdletBinding()]
param(
  [string]$ConfigPath = ".\mealie-import.config.json",
  [string]$RecipeSlug = "",
  [string]$RecipeName = "",
  [string]$ImagePath = "",
  [switch]$UseLatestDownload,
  [string]$DownloadsDirectory = "$env:USERPROFILE\Downloads",
  [string]$ImagesDirectory = "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import\recipe_images",
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

function Invoke-MealieJson {
  param(
    [object]$Cfg,
    [string]$Method,
    [string]$Path
  )

  $headers = Get-Headers -Cfg $Cfg

  return Invoke-WebRequest `
    -Uri "$($Cfg.MealieUrl)$Path" `
    -Headers $headers `
    -Method $Method `
    -UseBasicParsing `
    -TimeoutSec 30
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
      $res = Invoke-MealieJson -Cfg $Cfg -Method "GET" -Path $path
      $items = Convert-ResponseToItems -WebResponse $res

      if ($items.Count -eq 0) {
        if ($page -eq 1) {
          $res2 = Invoke-MealieJson -Cfg $Cfg -Method "GET" -Path "/api/recipes"
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
      $res2 = Invoke-MealieJson -Cfg $Cfg -Method "GET" -Path "/api/recipes"
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

function Get-ImageExtension {
  param([string]$Path)

  $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant().TrimStart(".")

  if ($ext -eq "jpg") { return "jpg" }
  if ($ext -eq "jpeg") { return "jpeg" }
  if ($ext -eq "png") { return "png" }
  if ($ext -eq "webp") { return "webp" }

  throw "Unsupported image extension: $ext"
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

function Copy-ImageLocal {
  param(
    [string]$SourcePath,
    [string]$DestinationDirectory,
    [string]$Slug
  )

  $dirFull = (New-Item -ItemType Directory -Force -Path $DestinationDirectory).FullName
  $ext = [System.IO.Path]::GetExtension($SourcePath)
  $dest = Join-Path $dirFull "$Slug$ext"

  Copy-Item -Path $SourcePath -Destination $dest -Force

  return (Resolve-Path $dest).Path
}

function Upload-RecipeImage {
  param(
    [object]$Cfg,
    [string]$Slug,
    [string]$FilePath
  )

  Add-Type -AssemblyName System.Net.Http

  $client = New-Object System.Net.Http.HttpClient
  $client.Timeout = [TimeSpan]::FromSeconds(60)
  $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $Cfg.ApiToken)
  $client.DefaultRequestHeaders.Accept.Clear()
  $client.DefaultRequestHeaders.Accept.Add([System.Net.Http.Headers.MediaTypeWithQualityHeaderValue]::new("application/json"))

  $endpoint = "$($Cfg.MealieUrl)/api/recipes/$Slug/image"
  $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::new("PUT"), $endpoint)

  $multipart = New-Object System.Net.Http.MultipartFormDataContent

  $bytes = [System.IO.File]::ReadAllBytes($FilePath)
  $fileContent = New-Object System.Net.Http.ByteArrayContent(,$bytes)
  $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse((Get-MimeType -Path $FilePath))

  $fileName = [System.IO.Path]::GetFileName($FilePath)
  $multipart.Add($fileContent, "image", $fileName)

  $extension = Get-ImageExtension -Path $FilePath
  $extensionContent = New-Object System.Net.Http.StringContent($extension)
  $multipart.Add($extensionContent, "extension")

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

  if ([string]::IsNullOrWhiteSpace($RecipeSlug) -and [string]::IsNullOrWhiteSpace($RecipeName)) {
    throw "Provide -RecipeSlug or -RecipeName."
  }

  $recipes = Get-AllRecipes -Cfg $cfg
  Write-Info "Recipes found: $($recipes.Count)"

  $recipe = Find-Recipe -Recipes $recipes -Name $RecipeName -Slug $RecipeSlug
  if ($null -eq $recipe) {
    throw "Recipe not found. Use exact -RecipeSlug from Mealie."
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

  $image = Get-Item $ImagePath
  Write-Ok "Image source: $($image.FullName)"

  $localPath = Copy-ImageLocal -SourcePath $image.FullName -DestinationDirectory $ImagesDirectory -Slug $slug
  Write-Ok "Image copied to: $localPath"

  $extension = Get-ImageExtension -Path $localPath
  Write-Info "Extension sent to Mealie: $extension"
  Write-Info "Endpoint: PUT /api/recipes/$slug/image"
  Write-Info "Multipart fields: image + extension"

  if ($DryRun) {
    Write-Ok "DRY-RUN: no upload done."
    exit 0
  }

  $response = Upload-RecipeImage -Cfg $cfg -Slug $slug -FilePath $localPath
  Write-Ok "Image uploaded successfully."

  if (-not [string]::IsNullOrWhiteSpace($response)) {
    Write-Info "Response: $response"
  }

  Write-Host ""
  Write-Ok "Done. Check recipe image in Mealie."
}
catch {
  Write-Bad $_.Exception.Message
  exit 1
}
