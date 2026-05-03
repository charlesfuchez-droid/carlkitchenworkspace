# Scripts Mealie basés sur /openapi.json

Tu avais raison : le script précédent disait d'aller voir `/docs`, mais il ne l'exploitait pas.

Ces scripts exploitent réellement l'API locale :

- `GET /openapi.json`
- lecture des endpoints disponibles
- détection des endpoints tools / organizers
- export des endpoints en CSV

## Installation

Dézippe dans :

```powershell
C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
```

```powershell
$Downloads = "$env:USERPROFILE\Downloads"
$ImportDir = "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"

Expand-Archive `
  -Path "$Downloads\carl_kitchen_mealie_openapi_tools.zip" `
  -DestinationPath $ImportDir `
  -Force

cd $ImportDir
```

## 1. Inspecter l'OpenAPI local

```powershell
.\inspect_mealie_openapi.ps1 `
  -ConfigPath .\mealie-import.config.json
```

Sortie attendue :

- endpoints affichés dans PowerShell
- fichier `mealie_openapi_endpoints.csv` généré

## 2. Chercher uniquement les ustensiles

```powershell
.\inspect_mealie_openapi.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -Keyword "tool|organizer"
```

## 3. Chercher les endpoints d'import recette

```powershell
.\inspect_mealie_openapi.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -Keyword "html|json|create|recipe"
```

## 4. Lister les endpoints tools détectés sans créer

```powershell
.\create_mealie_tools_from_openapi.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -ListOnly
```

## 5. Tester la création sans rien modifier

```powershell
.\create_mealie_tools_from_openapi.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -DryRun
```

## 6. Créer les ustensiles

```powershell
.\create_mealie_tools_from_openapi.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv
```

## Si l'endpoint contient un paramètre

Si le script affiche un endpoint du style :

```text
/api/groups/{group_slug}/organizers/tools
```

il ne peut pas deviner `{group_slug}` automatiquement.

Dans ce cas, force l'endpoint exact avec :

```powershell
.\create_mealie_tools_from_openapi.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -ToolsEndpoint "/api/TON_ENDPOINT_EXACT"
```

Copie la route exacte depuis la sortie de `inspect_mealie_openapi.ps1`.
