# Carl Kitchen Workspace

Carl Kitchen Workspace est un environnement local permettant de faire tourner **Carl Kitchen**, une application personnelle de gestion de recettes basée sur **Mealie**.

Le projet s’appuie sur :

- **Docker Compose** pour lancer les services ;
- **Mealie** comme moteur de gestion de recettes ;
- **Caddy** comme reverse proxy local ;
- **PowerShell** pour les scripts d’import et de lancement ;
- **Microsoft Edge** pour ouvrir l’application comme une app Windows ;
- **Git** pour versionner uniquement la configuration, les scripts et la documentation utile.

---

## 1. Structure actuelle du workspace

La racine Git du projet est :

```text
C:\Docker
```

Structure actuelle :

```text
C:\Docker
├── .git
├── .gitignore
├── README.md
│
├── Appli
│   └── CarlKitchenLauncher
│
└── CarlKitchen
    ├── .gitignore
    ├── bdd-francaise                  # ignoré par Git
    ├── mealie_2026.05.02.21.43.07.zip # archive locale ignorée par Git
    │
    └── mealie-lab
        ├── .env.example
        ├── Caddyfile
        ├── docker-compose.yml
        ├── docker-compose_old.yml.txt
        ├── custom-brand
        │
        └── carl-kitchen-import
            ├── catalogues
            ├── recipes_schema_org_json
            ├── recipe_images           # ignoré par Git
            ├── add_mealie_recipe_image_ascii.ps1
            ├── add_mealie_recipe_image_v4.ps1
            ├── carl_kitchen_lot1_preparations_schema_org.json
            ├── config.sample.json
            ├── create_mealie_tools.ps1
            ├── create_mealie_tools_from_openapi.ps1
            ├── fix_tools_created_as_categories.ps1
            ├── import_lot1_to_mealie.ps1
            ├── import_mealie_configurable.ps1
            ├── inspect_mealie_openapi.ps1
            ├── mealie-import-state.json # ignoré par Git
            ├── mealie-import.config.example.json
            ├── mealie-import.config.json # ignoré par Git
            ├── mealie-import.log         # ignoré par Git
            ├── mealie_openapi_endpoints.csv
            ├── mealie_tools.csv
            ├── mealie_tools_v3.ps1
            └── README_*.md
```

---

## 2. Rôle des principaux dossiers

### `C:\Docker`

Racine du workspace Git.

Toutes les commandes Git doivent être lancées depuis ce dossier :

```powershell
cd "C:\Docker"

git status
git add .
git commit -m "Message du commit"
git push
```

---

### `C:\Docker\CarlKitchen`

Dossier principal du projet Carl Kitchen.

Il contient :

- la stack Mealie ;
- la base française locale ;
- les fichiers d’import ;
- les fichiers de personnalisation ;
- les anciennes archives locales.

---

### `C:\Docker\CarlKitchen\mealie-lab`

Dossier principal de l’application Mealie.

C’est depuis ce dossier que Docker Compose doit être lancé.

Fichiers principaux :

```text
docker-compose.yml
Caddyfile
.env.example
docker-compose_old.yml.txt
custom-brand
carl-kitchen-import
```

---

### `C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import`

Dossier contenant les outils d’import vers Mealie.

Il contient :

- les recettes au format JSON ;
- les scripts d’import ;
- les scripts de création d’ustensiles ;
- les scripts d’upload d’images ;
- les fichiers CSV utiles ;
- les README techniques associés aux scripts.

---

### `C:\Docker\Appli\CarlKitchenLauncher`

Dossier prévu pour le futur lanceur Windows de Carl Kitchen.

Objectif :

- lancer Docker Compose ;
- ouvrir Carl Kitchen dans Edge ;
- générer éventuellement un `.exe` épinglable à la barre des tâches.

---

## 3. Prérequis

Installer :

- Docker Desktop ;
- WSL2 ;
- Git ;
- PowerShell ;
- Microsoft Edge.

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

## 4. Configuration du fichier hosts Windows

Carl Kitchen utilise une URL locale personnalisée :

```text
http://charles-kitchen.localhost
```

Pour que cette URL fonctionne, ouvrir le fichier `hosts` en administrateur.

Lancer PowerShell en administrateur puis exécuter :

```powershell
notepad C:\Windows\System32\drivers\etc\hosts
```

Ajouter à la fin du fichier :

```text
127.0.0.1 kitchen.localhost
127.0.0.1 charles-kitchen.localhost
127.0.0.1 carl-kitchen.localhost
```

Tester ensuite :

```powershell
ping charles-kitchen.localhost
```

Résultat attendu :

```text
127.0.0.1
```

---

## 5. Configuration Caddy

Le fichier Caddy est situé ici :

```text
C:\Docker\CarlKitchen\mealie-lab\Caddyfile
```

Configuration recommandée :

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

## 6. Lancer Carl Kitchen

Se placer dans le dossier Mealie :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"
```

Démarrer la stack :

```powershell
docker compose up -d
```

Vérifier les conteneurs :

```powershell
docker ps
```

Ouvrir l’application :

```text
http://charles-kitchen.localhost
```

---

## 7. Arrêter Carl Kitchen

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"

docker compose down
```

---

## 8. Redémarrer Carl Kitchen

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"

docker compose down
docker compose up -d
docker ps
```

---

## 9. Voir les logs

Tous les services :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab"

docker compose logs -f
```

Logs Mealie :

```powershell
docker compose logs -f mealie
```

Logs Caddy :

```powershell
docker compose logs -f caddy
```

---

## 10. Configuration Microsoft Edge

L’objectif est d’ouvrir Carl Kitchen comme une application dédiée plutôt que comme un simple onglet navigateur.

### Option recommandée : installer le site comme application Edge

1. Ouvrir Microsoft Edge.
2. Aller sur :

```text
http://charles-kitchen.localhost
```

3. Cliquer sur les trois points `...`.
4. Aller dans **Applications**.
5. Cliquer sur **Installer ce site en tant qu’application**.
6. Nommer l’application :

```text
Carl Kitchen
```

7. Épingler l’application à la barre des tâches.

---

### Option alternative : lancer Edge en mode application

```powershell
Start-Process "msedge.exe" -ArgumentList "--app=http://charles-kitchen.localhost"
```

Avec un profil Edge dédié :

```powershell
Start-Process "msedge.exe" -ArgumentList "--app=http://charles-kitchen.localhost --user-data-dir=C:\Docker\CarlKitchen\edge-profile"
```

---

## 11. Scripts d’import des recettes

Dossier :

```text
C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import
```

Se placer dans le dossier :

```powershell
cd "C:\Docker\CarlKitchen\mealie-lab\carl-kitchen-import"
```

Tester la connexion à Mealie :

```powershell
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

## 12. Scripts d’import des ustensiles

Script recommandé :

```text
mealie_tools_v3.ps1
```

Fichier source :

```text
mealie_tools.csv
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

## 13. Scripts d’ajout des images

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

## 14. Fichiers sensibles ou lourds ignorés par Git

Ces éléments ne doivent pas être versionnés :

```text
CarlKitchen/bdd-francaise/
CarlKitchen/mealie-lab/.env
CarlKitchen/mealie-lab/data/
CarlKitchen/mealie-lab/backups/
CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import.config.json
CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import-state.json
CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import.log
CarlKitchen/mealie-lab/carl-kitchen-import/recipe_images/
*.zip
*.log
*.exe
bin/
obj/
```

Raisons :

- `bdd-francaise/` : base externe volumineuse ;
- `.env` : configuration locale potentiellement sensible ;
- `data/` : données applicatives locales ;
- `backups/` : sauvegardes locales ;
- `mealie-import.config.json` : peut contenir un token API ;
- `recipe_images/` : images lourdes ou générées ;
- `*.zip` : archives temporaires ;
- `*.exe` : fichiers générés.

---

## 15. Fichiers à versionner

Ces éléments doivent rester dans Git :

```text
README.md
.gitignore
CarlKitchen/mealie-lab/docker-compose.yml
CarlKitchen/mealie-lab/Caddyfile
CarlKitchen/mealie-lab/.env.example
CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import.config.example.json
CarlKitchen/mealie-lab/carl-kitchen-import/config.sample.json
CarlKitchen/mealie-lab/carl-kitchen-import/recipes_schema_org_json/
CarlKitchen/mealie-lab/carl-kitchen-import/catalogues/
CarlKitchen/mealie-lab/carl-kitchen-import/mealie_tools.csv
CarlKitchen/mealie-lab/carl-kitchen-import/mealie_openapi_endpoints.csv
CarlKitchen/mealie-lab/carl-kitchen-import/*.ps1
CarlKitchen/mealie-lab/carl-kitchen-import/README_*.md
Appli/CarlKitchenLauncher/
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

Git ne remplace pas une sauvegarde.

À sauvegarder à part :

```text
CarlKitchen/mealie-lab/data/
CarlKitchen/mealie-lab/backups/
CarlKitchen/mealie-lab/.env
CarlKitchen/mealie-lab/carl-kitchen-import/mealie-import.config.json
CarlKitchen/mealie-lab/carl-kitchen-import/recipe_images/
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

Ouvrir le fichier hosts :

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

Priorités actuelles :

1. finaliser la structure Git ;
2. nettoyer les anciennes sauvegardes `.git_OLD_*` ;
3. fiabiliser le lancement via `CarlKitchenLauncher` ;
4. clarifier la stratégie de sauvegarde ;
5. stabiliser l’import des recettes ;
6. poursuivre la personnalisation Carl Kitchen.
