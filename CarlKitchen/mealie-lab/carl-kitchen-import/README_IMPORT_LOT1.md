# Import Carl Kitchen — Lot 1 Préparations

Ce dossier contient uniquement les premières préparations Carl Kitchen à importer dans Mealie.

## Contenu

- `11` recettes de préparation au format `schema.org/Recipe` JSON.
- Un fichier global : `carl_kitchen_lot1_preparations_schema_org.json`.
- Un catalogue CSV : `catalogues/lot1_preparations_ingredients_ustensiles_nutrition.csv`.
- Un catalogue des ustensiles : `catalogues/ustensiles_cuisine_lot1.csv`.
- Un script d'import API : `import_lot1_to_mealie.ps1`.

## Préparations incluses

- P01 — Poulet grillé neutre
- P02 — Bœuf haché nature / steak maison
- P03 — Œufs durs / œufs mollets
- P04 — Mix Spicy Chicken
- P05 — Mix Curry Curcuma
- P06 — Mix Oriental Kefta
- P07 — Mix Tomate épicée
- P08 — Mix Citron-Herbes
- P09 — Sauce tomate épicée maison
- P10 — Crème vin blanc
- P11 — Crème curry-curcuma

## Import manuel recommandé

Dans Mealie :

1. Aller dans la page d'import / création de recette.
2. Choisir l'import HTML/JSON.
3. Coller soit le contenu d'un fichier JSON individuel, soit tester le fichier global.
4. Vérifier que la catégorie, les ingrédients, les étapes, les ustensiles et la nutrition sont visibles.

## Import API

Créer un token dans Mealie, puis lancer :

```powershell
cd .\carl_kitchen_lot1_preparations_mealie
.\import_lot1_to_mealie.ps1 -MealieUrl "http://localhost:9925" -Token "COLLE_TON_TOKEN_ICI"
```

Les ustensiles sont inclus dans chaque recette via le champ `tool`, le champ `utensils`, et dans le premier bloc d'instructions pour rester visibles même si l'importeur JSON ne mappe pas tout automatiquement.
