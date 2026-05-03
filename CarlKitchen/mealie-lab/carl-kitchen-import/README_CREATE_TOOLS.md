# Création des ustensiles dans Mealie

Ce pack crée les ustensiles comme objets Mealie.

L'import JSON d'une recette peut contenir un champ `tool`, mais selon les versions de Mealie, ce champ n'est pas forcément importé comme vrai "Tool/Ustensile" lié à la recette. Ce script crée donc les ustensiles séparément.

## Installation

Dézipper ce pack dans :

```powershell
C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
```

## Commandes

```powershell
cd C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
```

Test sans création :

```powershell
.\create_mealie_tools.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -DryRun
```

Création réelle :

```powershell
.\create_mealie_tools.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv
```

## Vérification dans Mealie

Dans l'interface Mealie, va dans les paramètres/organisateurs du groupe et cherche les Tools/Ustensiles.

## Modifier la liste

Ouvre :

```powershell
notepad .\mealie_tools.csv
```

Ajoute ou supprime les ustensiles.
