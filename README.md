# Carl Kitchen Workspace

Carl Kitchen est un environnement local de gestion de recettes basé sur **Mealie**, lancé avec **Docker Compose**, exposé via **Caddy**, et accessible depuis une URL locale propre dans **Microsoft Edge**.

Le workspace contient :

- le moteur applicatif Mealie ;
- les fichiers Docker ;
- la configuration Caddy ;
- les scripts d’import de recettes ;
- les scripts d’import d’ustensiles ;
- les images de recettes ;
- les scripts de lancement Windows ;
- la documentation projet.

---

## 1. Structure du projet

```text
C:\Docker
├── README.md
├── .gitignore
├── CarlKitchen
│   ├── bdd-francaise              # ignoré par Git
│   └── mealie-lab
│       ├── docker-compose.yml
│       ├── Caddyfile
│       ├── .env.example
│       ├── .env                   # ignoré par Git
│       ├── data                   # ignoré par Git
│       ├── backups                # ignoré par Git
│       ├── custom-brand
│       ├── scripts
│       └── carl-kitchen-import
│           ├── recipes_schema_org_json
│           ├── recipe_images       # ignoré par Git
│           ├── mealie-import.config.example.json
│           ├── mealie-import.config.json   # ignoré par Git
│           ├── mealie_tools.csv
│           └── image_manifest.csv
│
└── Appli
    ├── start-carl-kitchen.ps1
    ├── CarlKitchenLauncher
    └── CarlKitchenDesktop
```

---

## 2. Prérequis

Avant de lancer Carl Kitchen, installer :

- Docker Desktop ;
- WSL2 ;
- PowerShell ;
- Microsoft Edge ;
- Git.

Vérifier Docker :

```powershell
docker --version
docker compose version
docker ps
```

Mettre à jour WSL si besoin :

```powershell
wsl --update
```

---

## 3. Configuration du fichier hosts Windows

Carl Kitchen utilise une URL locale personnalisée :

```text
http://charles-kitchen.localhost
```

Pour éviter les problèmes de résolution DNS locale, ajouter les entrées suivantes au fichier `hosts`.

Ouvrir PowerShell en administrateur, puis lancer :

```powershell
notepad C:\Windows\System32\drivers\etc\hosts
```

Ajouter à la fin du fichier :

```text
127.0.0.1 kitchen.localhost
127.0.0.1 charles-kitchen.localhost
127.0.0.1 carl-kitchen.localhost
```

Enregistrer le fichier.

Tester :

```powershell
ping charles-kitchen.localhost
```

Résultat attendu :

```text
127.0.0.1
```

---

## 4. Configuration Caddy

Le fichier Caddy est situé ici :

```text
C:\Docker\CarlKitchen\mealie-lab\Caddyfile
```

Configuration cible :

```caddy
http://localhost {
    reverse_proxy mealie:9000
}

http://kitchen.localhost {
    reverse_proxy mealie:9000
}

http://charles-kitchen.localhost {
    reverse_proxy mealie:9000
}

http://carl-kitchen.localhost {
    reverse_proxy mealie:9000
}
```

Après modification du `Caddyfile`, redémarrer la stack :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"
docker compose down
docker compose up -d
```

---

## 5. Lancer Carl Kitchen

Se placer dans le dossier Docker de Mealie :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"
```

Lancer la stack :

```powershell
docker compose up -d
```

Vérifier les conteneurs :

```powershell
docker ps
```

Ouvrir dans le navigateur :

```text
http://charles-kitchen.localhost
```

---

## 6. Arrêter Carl Kitchen

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"
docker compose down
```

---

## 7. Redémarrer Carl Kitchen

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"
docker compose down
docker compose up -d
docker ps
```

---

## 8. Voir les logs

Tous les services :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"
docker compose logs -f
```

Service Mealie uniquement :

```powershell
docker compose logs -f mealie
```

Service Caddy uniquement :

```powershell
docker compose logs -f caddy
```

---

## 9. Configuration Edge

L’objectif est d’ouvrir Carl Kitchen comme une application dédiée, sans avoir une simple fenêtre navigateur classique.

### Option recommandée : installer le site comme application Edge

1. Ouvrir Microsoft Edge.
2. Aller sur :

```text
http://charles-kitchen.localhost
```

3. Cliquer sur les trois points `...`.
4. Aller dans **Applications**.
5. Choisir **Installer ce site en tant qu’application**.
6. Nommer l’application :

```text
Carl Kitchen
```

7. Épingler l’application à la barre des tâches.

Cette méthode donne un comportement proche d’une application Windows.

---

### Option alternative : lancer Edge en mode application

Commande possible :

```powershell
Start-Process "msedge.exe" -ArgumentList "--app=http://charles-kitchen.localhost"
```

Avec un profil dédié :

```powershell
Start-Process "msedge.exe" -ArgumentList "--app=http://charles-kitchen.localhost --user-data-dir=C:\Docker\CarlKitchen\edge-profile"
```

Cette option ouvre Carl Kitchen dans une fenêtre dédiée.

---

## 10. Script de lancement Windows

Script recommandé :

```text
C:\Docker\Appli\start-carl-kitchen.ps1
```

Exemple de contenu :

```powershell
$ProjectPath = "C:\Docker\CarlKitchen\mealie-lab"
$Url = "http://charles-kitchen.localhost"

Write-Host "======================================" -ForegroundColor DarkGray
Write-Host " Carl Kitchen Launcher" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor DarkGray

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERREUR : dossier projet introuvable : $ProjectPath" -ForegroundColor Red
    pause
    exit 1
}

Set-Location $ProjectPath

Write-Host "Démarrage de Docker Compose..." -ForegroundColor Yellow
docker compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERREUR : Docker Compose n'a pas démarré correctement." -ForegroundColor Red
    pause
    exit 1
}

Write-Host ""
Write-Host "Conteneurs actifs :" -ForegroundColor Cyan
docker ps

Write-Host ""
Write-Host "Ouverture de Carl Kitchen..." -ForegroundColor Green
Start-Process "msedge.exe" -ArgumentList "--app=$Url"

Write-Host ""
Write-Host "Carl Kitchen est lancé : $Url" -ForegroundColor Green
pause
```

Lancer le script :

```powershell
& "C:\Docker\Appli\start-carl-kitchen.ps1"
```

---

## 11. Générer un exécutable de lancement

Le dossier du lanceur peut être organisé ainsi :

```text
C:\Docker\Appli\CarlKitchenLauncher
├── CarlKitchenLauncher.ps1
├── icon.ico
└── CarlKitchen.exe
```

Installer `ps2exe` :

```powershell
Install-Module ps2exe -Scope CurrentUser
Import-Module ps2exe
```

Générer l’exécutable :

```powershell
cd "C:\Docker\Appli\CarlKitchenLauncher"

Invoke-ps2exe `
  -inputFile .\CarlKitchenLauncher.ps1 `
  -outputFile .\CarlKitchen.exe `
  -iconFile .\icon.ico `
  -noConsole
```

L’exécutable généré peut ensuite être épinglé à la barre des tâches.

---

## 12. Import des recettes

Dossier d’import :

```text
C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
```

Tester la connexion à Mealie :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"

.\import_mealie_configurable.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -TestConnection
```

Tester une recette sans import réel :

```powershell
.\import_mealie_configurable.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -TestFile ".\recipes_schema_org_json\01_preparations\P01_poulet_grille_neutre.json" `
  -DryRun
```

Importer seulement 3 recettes :

```powershell
.\import_mealie_configurable.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -Limit 3
```

Importer toutes les recettes :

```powershell
.\import_mealie_configurable.ps1 `
  -ConfigPath .\mealie-import.config.json
```

---

## 13. Import des ustensiles

Fichier source :

```text
mealie_tools.csv
```

Script recommandé :

```text
mealie_tools_v3.ps1
```

Lister les ustensiles :

```powershell
.\mealie_tools_v3.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -List
```

Tester sans appliquer :

```powershell
.\mealie_tools_v3.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -DryRun
```

Créer ou mettre à jour les ustensiles :

```powershell
.\mealie_tools_v3.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -ToolsCsv .\mealie_tools.csv `
  -Apply
```

---

## 14. Ajout des images de recettes

Script recommandé :

```text
add_mealie_recipe_image_v4.ps1
```

Upload d’une image :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"

.\add_mealie_recipe_image_v4.ps1 `
  -ConfigPath .\mealie-import.config.json `
  -RecipeSlug "p01-base-volaille-grillee" `
  -ImagePath ".\recipe_images\P01_base_volaille_grillee.png" `
  -ImagesDirectory ".\recipe_images"
```

Upload massif via manifeste :

```powershell
$ImageDir = "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import\recipe_images"
$Manifest = Import-Csv "$ImageDir\image_manifest.csv"

foreach ($item in $Manifest) {
  $ImagePath = Join-Path $ImageDir $item.ImageFile

  .\add_mealie_recipe_image_v4.ps1 `
    -ConfigPath .\mealie-import.config.json `
    -RecipeSlug $item.RecipeSlug `
    -ImagePath $ImagePath `
    -ImagesDirectory $ImageDir
}
```

---

## 15. Fichiers ignorés par Git

Le repo ne doit pas contenir les données locales, secrets ou fichiers lourds.

Ignorés volontairement :

```text
CarlKitchen/bdd-francaise/
CarlKitchen/mealie-lab/.env
CarlKitchen/mealie-lab/data/
CarlKitchen/mealie-lab/backups/
CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import.config.json
CarlKitchen/mealie-lab/carl-kitchen-import/recipe_images/
*.log
*.zip
*.exe
bin/
obj/
```

Versionnés volontairement :

```text
README.md
.gitignore
CarlKitchen/mealie-lab/docker-compose.yml
CarlKitchen/mealie-lab/Caddyfile
CarlKitchen/mealie-lab/.env.example
CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import.config.example.json
CarlKitchen/mealie-lab/carl-kitchen-import/recipes_schema_org_json/
CarlKitchen/mealie-lab/carl-kitchen-import/mealie_tools.csv
CarlKitchen/mealie-lab/carl-kitchen-import/image_manifest.csv
Appli/start-carl-kitchen.ps1
Appli/CarlKitchenLauncher/CarlKitchenLauncher.ps1
```

---

## 16. Utilisation Git

Le repo Git officiel est :

```text
https://github.com/charlesfuchez-droid/carlkitchenworkspace.git
```

La racine locale est :

```text
C:\Docker
```

Commandes habituelles :

```powershell
cd "C:\Docker"

git status
git add .
git commit -m "Message du commit"
git push
```

Vérifier les fichiers ignorés :

```powershell
git status --ignored --short
```

Tester une règle `.gitignore` :

```powershell
git check-ignore -v --no-index CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import.config.json
```

---

## 17. Sauvegarde

Les données Mealie ne sont pas versionnées dans Git.

À sauvegarder à part :

```text
CarlKitchen/mealie-lab/data/
CarlKitchen/mealie-lab/backups/
CarlKitchen/mealie-lab/.env
CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import.config.json
```

Exemple de sauvegarde manuelle :

```powershell
$Source = "C:\Docker\CarlKitchen\mealie-lab"
$Backup = "C:\Docker\CarlKitchen\mealie-lab\backups\backup-$(Get-Date -Format yyyyMMdd-HHmmss)"

New-Item -ItemType Directory -Force -Path $Backup

Copy-Item "$Source\docker-compose.yml" $Backup -Force
Copy-Item "$Source\Caddyfile" $Backup -Force
Copy-Item "$Source\.env" $Backup -Force -ErrorAction SilentlyContinue
Copy-Item "$Source\data" "$Backup\data" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item "$Source\carl-kitchen-import" "$Backup\carl-kitchen-import" -Recurse -Force -ErrorAction SilentlyContinue
```

---

## 18. Commandes utiles

Démarrer :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"
docker compose up -d
```

Arrêter :

```powershell
docker compose down
```

Redémarrer :

```powershell
docker compose down
docker compose up -d
```

Voir les conteneurs :

```powershell
docker ps
```

Voir les logs :

```powershell
docker compose logs -f
```

Ouvrir le hosts :

```powershell
notepad C:\Windows\System32\drivers\etc\hosts
```

Ouvrir le Caddyfile :

```powershell
notepad C:\Docker\CarlKitchen\mealie-lab\Caddyfile
```

Ouvrir l’application :

```text
http://charles-kitchen.localhost
```

---

## 19. Objectif produit

Carl Kitchen vise à devenir une application locale personnelle permettant de :

- gérer des recettes ;
- importer des préparations ;
- associer des images ;
- structurer les ustensiles ;
- calculer les apports énergétiques ;
- préparer des bases de batch cooking ;
- créer une expérience personnalisée autour de la cuisine saine, efficace et gastronomique.

---

## 20. Statut actuel

Le projet est en phase de stabilisation.

Les priorités sont :

1. stabiliser la structure Git ;
2. finaliser le `.gitignore` ;
3. documenter le lancement ;
4. fiabiliser le launcher Windows ;
5. sauvegarder les données Mealie ;
6. continuer la personnalisation Carl Kitchen.
