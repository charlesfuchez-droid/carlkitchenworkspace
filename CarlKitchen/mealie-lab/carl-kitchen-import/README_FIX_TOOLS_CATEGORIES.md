# Fix Mealie — ustensiles créés en catégories

Ce script corrige le problème suivant :

> des ustensiles ont été créés dans Mealie comme catégories au lieu d'être créés comme Tools/Ustensiles.

Le script est sécurisé : il ne supprime que les catégories dont le nom correspond exactement à un nom présent dans `mealie_tools.csv`.

## Installation

Dézippe dans :

```powershell
C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
```

```powershell
$Downloads = "$env:USERPROFILE\Downloads"
$ImportDir = "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"

Expand-Archive `
  -Path "$Downloads\carl_kitchen_fix_tools_categories.zip" `
  -DestinationPath $ImportDir `
  -Force

cd $ImportDir
```

## 1. Dry-run obligatoire

```powershell
.\fix_tools_created_as_categories.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -DryRun
```

Vérifie la liste des catégories qui seront supprimées.

## 2. Correction réelle

```powershell
.\fix_tools_created_as_categories.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -Apply
```

## 3. Vérification

Dans Mealie :

- les catégories ne doivent plus contenir `Poêle`, `Casserole`, `Spatule`, etc.
- les Tools/Ustensiles doivent contenir ces noms.

## Important

Si tu as volontairement créé une catégorie qui porte le même nom qu'un ustensile du CSV, enlève-la du fichier `mealie_tools.csv` avant de lancer `-Apply`.
