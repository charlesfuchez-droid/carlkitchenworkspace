# Mealie Tools V3

Cette V3 utilise exactement le POST qui a fonctionné dans ton test manuel :

```powershell
POST /api/organizers/tools
Body: { "name": "Test Carl Tool" }
```

## Installation

```powershell
$Downloads = "$env:USERPROFILE\Downloads"
$ImportDir = "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"

Expand-Archive `
  -Path "$Downloads\carl_kitchen_mealie_tools_v3.zip" `
  -DestinationPath $ImportDir `
  -Force

cd $ImportDir
```

## 1. Lister catégories et tools

```powershell
.\mealie_tools_v3.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -List
```

## 2. Supprimer le tool de test

```powershell
.\mealie_tools_v3.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -DeleteTestTool
```

## 3. Dry-run correction

```powershell
.\mealie_tools_v3.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -DryRun
```

## 4. Appliquer

```powershell
.\mealie_tools_v3.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -Apply
```
