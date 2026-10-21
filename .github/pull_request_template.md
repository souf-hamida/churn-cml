## Quoi
-

## Pourquoi
- Closes #

## Comment tester
```bash
pip install -r requirements-dev.txt
pip install -e .
pytest -q
python -m churn.train --config config/train.yaml
```

## Preuve (avant / après, jeu de test)
| Métrique | main | cette PR |
|---|---:|---:|
| f1 | | |
| roc_auc | | |

## Checklist
- [ ] Tests et ruff au vert
- [ ] Aucun fichier de `data/` ni d'`artifacts/` commité
- [ ] Configuration modifiée documentée (`config/train.yaml`)
- [ ] Notebook nettoyé (sorties supprimées) si modifié
