# ASCII-safe Mealie image uploader

This version avoids accents and special Unicode characters in the script code to prevent Windows PowerShell parser errors.

## Install

```powershell
$Downloads = "$env:USERPROFILE\Downloads"
$ImportDir = "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"

Expand-Archive `
  -Path "$Downloads\carl_kitchen_mealie_image_upload_ascii.zip" `
  -DestinationPath $ImportDir `
  -Force

cd $ImportDir
```

## Upload exact file to P01

```powershell
.\add_mealie_recipe_image_ascii.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeSlug "p01-base-volaille-grillee" `
  -ImagePath "$env:USERPROFILE\Downloads\ChatGPT Image 2 mai 2026, 17_49_55.png"
```

## Dry-run

```powershell
.\add_mealie_recipe_image_ascii.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeSlug "p01-base-volaille-grillee" `
  -ImagePath "$env:USERPROFILE\Downloads\ChatGPT Image 2 mai 2026, 17_49_55.png" `
  -DryRun
```

## List image endpoints

```powershell
.\add_mealie_recipe_image_ascii.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeSlug "p01-base-volaille-grillee" `
  -ImagePath "$env:USERPROFILE\Downloads\ChatGPT Image 2 mai 2026, 17_49_55.png" `
  -ListCandidates
```
