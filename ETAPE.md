# Étape TP4 — Partie 4 « CI/CD pour le ML : GitHub Actions + CML »

État du dépôt à la **fin du TP4** (= `../app/`, sans les balises de synchronisation) :
le projet du TP3 + un workflow `.github/workflows/ci.yml` et le générateur de rapport
`src/churn/report.py`. **Point de départ de l'étape 5 (DVC).**

Sources reprises et corrigées : TP3 Word (`TPs/TP3_MLOps_CICD_CML_HAMIDA.docx`), Atelier 3,
`Chapter 3/cml-github` (`script.py`, `cml-churn.yaml`), chapitre 3 (baseline vs PR, matrice,
`compare_metrics.py`, `make_report.py`).

## Contenu ajouté par rapport à l'étape 3

| Fichier | Rôle |
|---|---|
| `.github/workflows/ci.yml` | 4 jobs : `quality` (ruff + pytest) → `train` (branche + porte de qualité + baseline `main` ré-entraînée) et `matrix` (C = 0,01 / 0,1 / 1,0) → `report` (report.md, résumé du job, `cml comment update`) |
| `src/churn/report.py`, `tests/test_report.py` | rapport Markdown : tableau main / PR / écart, matrice de confusion, matrice d'hyperparamètres |
| `.gitignore` | **provisoire** : `!/data/churn.csv` (données versionnées pour que la CI entraîne ; retirées au TP5) |
| `ci_local/simuler_ci.sh` | exécute localement, dans l'ordre, les commandes du workflow (dépôt « origin » nu local) |
| `debogage/ci_casse.yml` | **exercice** : workflow avec 8 erreurs |
| `corrige_enseignant/` | corrigé, sorties actionlint, rejeux locaux, `report.md` produits |

## Le workflow en bref

- Déclencheurs : `pull_request` vers `main` et `push` sur `main` ; `concurrency` annule les
  runs obsolètes d'une même PR.
- Permissions : `contents: read` pour tout le workflow ; `pull-requests: write` pour le seul
  job `report`.
- Actions (versions de `plan/decisions.md`, vérifiées le 2026-10-18 ; à revérifier avant la
  séance) : `actions/checkout@v7`, `actions/setup-python@v7` (cache pip intégré),
  `actions/upload-artifact@v7`, `actions/download-artifact@v8`, `iterative/setup-cml@v2`.
  Python 3.12 en CI.
- Baseline : `git worktree add ../baseline origin/<branche cible>` puis entraînement du code
  de `main` avec `PYTHONPATH=src` (`continue-on-error` : premier run sans baseline possible).
- Matrice : un artefact **par job** (`matrix-C-<C>`), récupérés par `pattern: matrix-*` ;
  un seul commentaire CML mis à jour (`--watermark-title`).

## Résultats observés (2026-10-18)

- `actionlint` 1.7.12 (avec shellcheck 0.11.0) : **0 erreur** sur `ci.yml`
  (`corrige_enseignant/preuves/actionlint.txt`).
- Rejeu local, PR `feature/c-0.01` → `main` (`preuves/ci_locale_c001.txt`) : ruff OK,
  35 tests, porte de qualité franchie, baseline main F1 0,4820, PR F1 0,4915 (**+0,0095**),
  ROC AUC −0,0006 ; matrice : C = 0,01 → 0,4915 ; 0,1 → 0,4854 ; 1,0 → 0,4820.
  `report.md` produit : `preuves/report_c001/report.md`.
- Extension, PR `feature/random-forest` (`preuves/ci_locale_random_forest.txt`) : F1 0,6198
  (+0,1378), ROC AUC 0,8607 ; la matrice sur C donne 3 lignes **identiques** (C n'est pas
  un paramètre de la forêt) — à exploiter en question.
- [NON EXÉCUTÉ] exécution sur GitHub Actions et publication `cml comment update` (pas de
  compte GitHub ; CML 0.20.6 n'a pas d'option `--dry-run` ; un appel local téléverserait
  l'image vers asset.cml.dev).

## Écarts volontaires avec les sources

- `on: pull_request` + `push: main` au lieu de `on: [push]` (plus de commit vide pour obtenir
  le rapport dans la PR) ; `permissions: write-all` remplacé par le moindre privilège ;
  `setup-node` (Node 16) supprimé ; `setup-cml@v1` → `@v2`.
- Baseline ré-entraînée (la source lisait `artifacts/metrics.json` sur `origin/main`, dossier
  ignoré par Git : baseline jamais trouvée).
- Artefacts de matrice nommés de façon unique (même nom depuis 3 jobs = échec depuis
  upload-artifact v4) ; la matrice passe réellement le paramètre (`--set model.C=...`).
- Tests et lint avant tout entraînement ; porte de qualité (`--check-gate`).
- Rapport généré par un module testé (`churn.report`) au lieu d'un heredoc dans le YAML.
