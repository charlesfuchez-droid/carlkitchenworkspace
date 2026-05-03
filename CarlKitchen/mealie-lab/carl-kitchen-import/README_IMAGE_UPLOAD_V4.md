# Mealie image upload V4

This version uses the exact API contract seen from your error:

```text
PUT /api/recipes/{slug}/image
multipart/form-data:
- image
- extension
```

## Install

```powershell
$Downloads = "$env:USERPROFILE\Downloads"
$ImportDir = "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"

Expand-Archive `
  -Path "$Downloads\carl_kitchen_mealie_image_upload_v4.zip" `
  -DestinationPath $ImportDir `
  -Force

cd $ImportDir
```

## Dry-run

```powershell
.\add_mealie_recipe_image_v4.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeSlug "p01-base-volaille-grillee" `
  -ImagePath "$env:USERPROFILE\Downloads\ChatGPT Image 2 mai 2026, 17_49_55.png" `
  -DryRun
```

## Upload

```powershell
.\add_mealie_recipe_image_v4.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeSlug "p01-base-volaille-grillee" `
  -ImagePath "$env:USERPROFILE\Downloads\ChatGPT Image 2 mai 2026, 17_49_55.png"
```
