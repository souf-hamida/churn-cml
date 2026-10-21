#!/usr/bin/env bash
# TP4 — exécution LOCALE, dans l'ordre, des commandes du workflow .github/workflows/ci.yml
# pour une PR « feature/c-0.01 » vers main. Un dépôt « origin » nu local remplace GitHub,
# ce qui permet d'utiliser exactement la commande de baseline du workflow
# (git worktree add ../baseline origin/main).
#   bash ci_local/simuler_ci.sh DOSSIER_DE_TRAVAIL [SCENARIO]
#   SCENARIO : c-0.01 (défaut) ou random-forest
# Ce qui n'est PAS simulé : runners GitHub, cache pip, upload/download réels (copies de
# dossiers à la place), publication CML (exige un jeton GitHub et une PR réelle).
set -euo pipefail
export PYTHONUTF8=1 PYTHONHASHSEED=0

SRC="$(cd "$(dirname "$0")/.." && pwd)"           # etape_tp4
WORK="${1:?usage : simuler_ci.sh DOSSIER [SCENARIO]}"
SCENARIO="${2:-c-0.01}"
rm -rf "$WORK" && mkdir -p "$WORK"
section() { echo; echo "### $*"; }
d=0
at() { d=$((d + 1)); export GIT_AUTHOR_DATE="2026-10-20T0$d:00:00+01:00" GIT_COMMITTER_DATE="2026-10-20T0$d:00:00+01:00"; }

section "0. Dépôt local : main (état de l'étape 4) poussé sur un « origin » nu"
cd "$WORK"
git init -q --bare origin.git
git -C origin.git config core.longpaths true   # Windows : chemins longs (configuration locale)
mkdir repo && cd repo
( cd "$SRC" && tar cf - --exclude=./corrige_enseignant --exclude=./debogage \
    --exclude=./ci_local --exclude=./ETAPE.md --exclude=./artifacts \
    --exclude='*/__pycache__' --exclude=./.pytest_cache --exclude=./.ruff_cache . ) | tar xf -
mkdir artifacts && touch artifacts/.gitkeep
git init -q -b main
git config user.name "Étudiant Démo"; git config user.email "etudiant.demo@example.org"
git config core.autocrlf false
git add -A
at; git commit -q -m "feat: churn baseline with CI workflow and CML report"
git ls-files | grep -E '^(data/|\.github/workflows/)'
git remote add origin ../origin.git
git push -q origin main
case "$SCENARIO" in
  c-0.01)
    git switch -q -c feature/c-0.01
    sed -i 's/^  C: 1.0 /  C: 0.01/' config/train.yaml
    git add config/train.yaml; at; git commit -q -m "feat(config): stronger regularisation C=0.01" ;;
  random-forest)
    git switch -q -c feature/random-forest
    sed -i 's/^  name: logistic_regression /  name: random_forest       /' config/train.yaml
    git add config/train.yaml; at; git commit -q -m "feat(model): switch to random forest (300 trees, depth 10)" ;;
esac
git push -q origin HEAD
git fetch -q origin
git log --oneline --all --graph
git diff origin/main --stat

export GITHUB_WORKSPACE="$(pwd -W 2>/dev/null || pwd)"   # chemin compris par Python (Windows)
export PYTHONPATH="$GITHUB_WORKSPACE/src"     # équivaut au « pip install --no-deps -e . » du workflow

section "Job quality : ruff check / ruff format --check / pytest -q"
ruff check .
ruff format --check .
python -m pytest -q -m "not performance" 2>&1 | tail -2

section "Job train : entraînement de la branche (la porte de qualité vient après les artefacts)"
python -m churn.train --config config/train.yaml

section "Job train : baseline = branche cible de la PR (BASE_REF=main) ré-entraînée"
BASE_REF=main
git worktree add -q ../baseline "origin/${BASE_REF}"
( cd ../baseline
  PYTHONPATH=src python -m churn.train --config config/train.yaml \
    --artifacts-dir "${GITHUB_WORKSPACE}/baseline-run" )
git worktree list

section "Job train (dernière étape) : porte de qualité, après la conservation des artefacts"
python -m churn.evaluate --config config/train.yaml --check-gate && echo "porte : OK" || echo "porte : ÉCHEC (le rapport sera quand même publié)"

section "Job matrix : C = 0.01 / 0.1 / 1.0 (un artefact par valeur)"
for C in 0.01 0.1 1.0; do
  python -m churn.train --config config/train.yaml \
    --set "model.C=${C}" --artifacts-dir "matrix/C-${C}" | head -1
done

section "Transfert des artefacts (upload-artifact -> download-artifact, simulé par copie)"
mkdir -p dl/runs dl/matrix
cp -r artifacts dl/runs/run-pr
cp -r baseline-run dl/runs/run-baseline
for C in 0.01 0.1 1.0; do
  mkdir -p "dl/matrix/matrix-C-${C}"
  cp "matrix/C-${C}/metrics.json" "matrix/C-${C}/report.json" "dl/matrix/matrix-C-${C}/"
done
find dl -type f | sort

section "Job report : génération de report.md (contenu publié par cml comment update)"
cd dl
PYTHONPATH="${GITHUB_WORKSPACE}/src" python -m churn.report --current runs/run-pr \
  --baseline runs/run-baseline --matrix-dir matrix \
  --image runs/run-pr/confusion_matrix.png --out report.md
echo "----- report.md -----"
cat report.md
echo "---------------------"
echo "[NON EXÉCUTÉ] cml comment update --watermark-title=\"Rapport churn\" report.md (exige GitHub)"
