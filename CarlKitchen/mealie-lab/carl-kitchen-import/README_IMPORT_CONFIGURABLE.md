# Import Mealie configurable — Carl Kitchen

Ce dossier contient un script PowerShell robuste pour importer des recettes JSON schema.org dans Mealie.

## Fichiers

- `import_mealie_configurable.ps1` : script principal
- `config.sample.json` : modèle de configuration à copier
- `README_IMPORT_CONFIGURABLE.md` : cette procédure

## Installation rapide

Place ces fichiers à la racine de ton pack Carl Kitchen, au même niveau que :

```text
recipes_schema_org_json\01_preparations
```

Copie la config :

```powershell
Copy-Item .\config.sample.json .\mealie-import.config.json
notepad .\mealie-import.config.json
```

Renseigne :

```json
{
  "MealieUrl": "http://localhost:9925",
  "ApiToken": "TON_TOKEN_API_MEALIE",
  "RecipesDirectory": ".\\recipes_schema_org_json\\01_preparations"
}
```

## 1. Test connexion

```powershell
.\import_mealie_configurable.ps1 -ConfigPath .\mealie-import.config.json -TestConnection
```

## 2. Dry-run sur un seul fichier

```powershell
.\import_mealie_configurable.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -TestFile ".\recipes_schema_org_json\01_preparations\P01_poulet_grille_neutre.json" `
  -DryRun
```

## 3. Détecter le bon format d'import

Cette commande teste plusieurs endpoints et plusieurs formats de payload sur une seule recette.

Attention : si un format fonctionne, la recette test peut être créée dans Mealie.

```powershell
.\import_mealie_configurable.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -DiscoverImportShape `
  -TestFile ".\recipes_schema_org_json\01_preparations\P01_poulet_grille_neutre.json"
```

Le format qui fonctionne est enregistré dans :

```text
mealie-import-state.json
```

## 4. Importer tout le lot

```powershell
.\import_mealie_configurable.ps1 -ConfigPath .\mealie-import.config.json
```

## 5. Importer seulement les 3 premiers fichiers

```powershell
.\import_mealie_configurable.ps1 -ConfigPath .\mealie-import.config.json -Limit 3
```

## 6. Forcer l'import même si une recette existe déjà

```powershell
.\import_mealie_configurable.ps1 -ConfigPath .\mealie-import.config.json -Force
```

## En cas de blocage PowerShell

```powershell
powershell -ExecutionPolicy Bypass -File .\import_mealie_configurable.ps1 -ConfigPath .\mealie-import.config.json -TestConnection
```

## Logs

Le script écrit dans :

```text
mealie-import.log
```

## Sécurité

Le token API est stocké en clair dans `mealie-import.config.json`.
Garde ce fichier local, ne le mets pas sur GitHub, ne le partage pas.
