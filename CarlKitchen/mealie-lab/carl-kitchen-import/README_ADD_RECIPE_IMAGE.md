# Ajout d'image à une préparation Mealie

Ce script ajoute une image à une recette/préparation Mealie.

Il est prévu pour ton cas :
- l'image est dans Downloads
- son nom est du style ChatGPT/blabla
- tu veux l'associer à `P01 — Base volaille grillée`

## Installation

Dézippe dans :

```powershell
C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
```

```powershell
$Downloads = "$env:USERPROFILE\Downloads"
$ImportDir = "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"

Expand-Archive `
  -Path "$Downloads\carl_kitchen_mealie_image_upload.zip" `
  -DestinationPath $ImportDir `
  -Force

cd $ImportDir
```

## Option recommandée : utiliser la dernière image téléchargée

```powershell
.\add_mealie_recipe_image.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeName "P01 — Base volaille grillée" `
  -UseLatestDownload
```

Le script va :
1. prendre la dernière image dans `Downloads`
2. la copier dans `.\recipe_images`
3. chercher la recette dans Mealie
4. détecter les endpoints image via `/openapi.json`
5. tenter l'upload

## Si tu veux d'abord voir les endpoints candidats

```powershell
.\add_mealie_recipe_image.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeName "P01 — Base volaille grillée" `
  -UseLatestDownload `
  -ListCandidates
```

## Si tu veux tester sans uploader

```powershell
.\add_mealie_recipe_image.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeName "P01 — Base volaille grillée" `
  -UseLatestDownload `
  -DryRun
```

## Avec un chemin d'image précis

```powershell
.\add_mealie_recipe_image.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeName "P01 — Base volaille grillée" `
  -ImagePath "$env:USERPROFILE\Downloads\nom_de_ton_image.png"
```

## Si le nom exact de la recette ne marche pas

Utilise le slug Mealie :

```powershell
.\add_mealie_recipe_image.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeSlug "p01-base-volaille-grillee" `
  -UseLatestDownload
```
