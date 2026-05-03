param(
    [Parameter(Mandatory=$true)]
    [string]$MealieUrl,

    [Parameter(Mandatory=$true)]
    [string]$Token
)

$ErrorActionPreference = "Stop"

# Exemple :
# .\import_lot1_to_mealie.ps1 -MealieUrl "http://localhost:9925" -Token "COLLE_TON_TOKEN_ICI"
# Le token Mealie se crée dans /user/profile/api-tokens

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$folder = Join-Path $root "recipes_schema_org_json\01_preparations"

$headers = @{
    "Authorization" = "Bearer $Token"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

Get-ChildItem -Path $folder -Filter "*.json" | Sort-Object Name | ForEach-Object {
    $file = $_.FullName
    $jsonRecipe = Get-Content -Path $file -Raw -Encoding UTF8

    $payload = @{
        data        = $jsonRecipe
        includeTags = $true
    } | ConvertTo-Json -Depth 30

    Write-Host "Import : $($_.Name)" -ForegroundColor Yellow

    try {
        $response = Invoke-RestMethod `
            -Uri "$MealieUrl/api/recipes/create/html-or-json" `
            -Method Post `
            -Headers $headers `
            -Body $payload

        Write-Host "OK" -ForegroundColor Green
    }
    catch {
        Write-Host "ERREUR sur $($_.Name)" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor DarkRed }
    }

    Start-Sleep -Milliseconds 500
}

Write-Host "Import du lot 1 terminé." -ForegroundColor Green
