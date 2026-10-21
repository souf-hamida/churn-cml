# Image d'ENTRAÎNEMENT du fil rouge churn (TP3).
#   docker build -t mlt-churn-train:0.1.0 .
#   docker run --rm --mount type=bind,src="$(pwd)/data",dst=/app/data,readonly \
#              --mount type=bind,src="$(pwd)/artifacts",dst=/app/artifacts mlt-churn-train:0.1.0
# Les données et les artefacts restent HORS de l'image (montages) : l'image ne contient
# que l'environnement et le code.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONHASHSEED=0 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    MPLCONFIGDIR=/tmp/matplotlib

WORKDIR /app

# Utilisateur sans privilèges (uid fixe : utile pour les droits des fichiers montés)
RUN useradd --create-home --uid 10001 mlops

# 1) Dépendances : couche mise en cache tant que requirements.txt ne change pas
COPY requirements.txt .
RUN pip install -r requirements.txt

# 2) Code : le paquet churn est installé (pas de sys.path bricolé)
COPY pyproject.toml README.md ./
COPY src ./src
RUN pip install --no-deps . && rm -rf build src/*.egg-info

# 3) Configuration (les données sont montées en lecture seule dans /app/data)
COPY config ./config
# Dossier des artefacts accessible en écriture à l'utilisateur (si rien n'est monté)
RUN mkdir -p artifacts && chown mlops:mlops artifacts

USER mlops
CMD ["python", "-m", "churn.train", "--config", "config/train.yaml"]
