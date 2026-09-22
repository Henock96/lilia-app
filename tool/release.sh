#!/usr/bin/env bash
#
# La commande de release — écrite une fois, versionnée, et la seule.
#
# ## Pourquoi ce fichier existe
#
# `main.dart` lit trois valeurs par `String.fromEnvironment` : `API_URL`,
# `WS_URL` et `SENTRY_DSN`. Les deux premières ont un défaut de production ;
# la troisième n'en a pas, et un DSN vide **désactive Sentry en silence**.
#
# Aucune commande de build du dépôt ne le passait. `AGENTS.md` documentait
# `flutter build apk` nu, `CLAUDE.md` mentionnait `API_URL` et `WS_URL` — dans
# la section des tests d'intégration. Un binaire publié par l'une de ces deux
# commandes ne remonte aucun plantage, et rien ne le dit : sur la console
# Sentry, zéro événement ressemble à zéro plantage.
#
# La clé Maps et le trousseau de signature, eux, cassent le build quand ils
# manquent (`android/app/build.gradle.kts`). Ce script applique le même soin à
# ce qui reste, et couvre iOS, que Gradle ne voit pas.
#
# ## Usage
#
#   export SENTRY_DSN='https://…@…ingest.sentry.io/…'
#   tool/release.sh android          # app bundle pour le Play Store
#   tool/release.sh ios              # archive .ipa
#   tool/release.sh android ios      # les deux
#
# Pour renoncer délibérément à la télémétrie sur un build local :
#
#   SENTRY_DSN='' SENTRY_OPT_OUT=1 tool/release.sh android
#
set -euo pipefail

cd "$(dirname "$0")/.."

API_URL="${API_URL:-https://lilia-backend.onrender.com}"
WS_URL="${WS_URL:-https://lilia-backend.onrender.com}"
SENTRY_ENV="${SENTRY_ENV:-production}"

rouge() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
vert()  { printf '\033[32m%s\033[0m\n' "$*"; }
titre() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# ── Garde : le DSN doit être un choix, pas un oubli ───────────────────────────
#
# On accepte un DSN vide — mais seulement s'il est réclamé. La différence entre
# « je ne veux pas de télémétrie » et « j'ai oublié » ne se lit pas dans le
# binaire ; elle doit se lire dans la commande.
if [[ -z "${SENTRY_DSN:-}" && "${SENTRY_OPT_OUT:-}" != "1" ]]; then
  rouge "SENTRY_DSN n'est pas défini."
  rouge ""
  rouge "  export SENTRY_DSN='https://…@…ingest.sentry.io/…'"
  rouge ""
  rouge "Sans DSN, le binaire publié ne remonte AUCUN plantage et rien ne le"
  rouge "signale. Pour y renoncer délibérément : SENTRY_OPT_OUT=1"
  exit 1
fi
SENTRY_DSN="${SENTRY_DSN:-}"

if [[ $# -eq 0 ]]; then
  rouge "Usage : tool/release.sh [android] [ios]"
  exit 2
fi

# ── Garde : version et mécanisme de mise à jour (OPS-001) ────────────────────
#
# La version comparée au seuil `minAppVersion` est celle du binaire
# (`package_info_plus`, UPD-001). Ces tests vérifient que le pubspec est
# lisible par `AppVersion` et que les dialogues de mise à jour ne peuvent pas
# enfermer l'utilisateur. Un échec ici arrête la release avant la compilation.
titre "Garde : analyse et mise à jour"
flutter analyze
flutter test test/core/update/
vert "  analyse et tests de mise à jour : OK"

DEFINES=(
  "--dart-define=API_URL=${API_URL}"
  "--dart-define=WS_URL=${WS_URL}"
  "--dart-define=SENTRY_DSN=${SENTRY_DSN}"
  "--dart-define=SENTRY_ENV=${SENTRY_ENV}"
)

titre "Configuration"
echo "  API_URL     ${API_URL}"
echo "  WS_URL      ${WS_URL}"
echo "  SENTRY_ENV  ${SENTRY_ENV}"
if [[ -n "${SENTRY_DSN}" ]]; then
  # Jamais le DSN en clair dans un journal de build : il contient une clé
  # publique de projet, et les journaux de CI se partagent.
  echo "  SENTRY_DSN  défini (${#SENTRY_DSN} caractères)"
else
  echo "  SENTRY_DSN  VIDE — télémétrie désactivée, à la demande"
fi

# ── Les portes de qualité, avant de fabriquer quoi que ce soit ────────────────
#
# Un binaire produit à partir d'un arbre qui ne passe pas l'analyse ou les
# tests n'a pas à exister : on ne veut pas avoir à se demander, plus tard, si
# l'artefact publié correspond à un état vert.
titre "flutter analyze"
flutter analyze

titre "flutter test"
flutter test

for cible in "$@"; do
  case "$cible" in
    android)
      titre "flutter build appbundle --release"
      flutter build appbundle --release "${DEFINES[@]}"
      vert "✓ build/app/outputs/bundle/release/app-release.aab"
      ;;
    ios)
      titre "flutter build ipa --release"
      flutter build ipa --release "${DEFINES[@]}"
      vert "✓ build/ios/ipa/"
      ;;
    *)
      rouge "Cible inconnue : ${cible} (attendu : android, ios)"
      exit 2
      ;;
  esac
done

titre "Reste à faire, et qu'aucun script ne peut faire à votre place"
cat <<'RAPPEL'
  · Installer l'artefact sur un appareil et parcourir les écrans critiques.
    R8 obfusque le binaire de release sans qu'aucune règle de conservation
    n'ait été écrite : « ça compile » ne dit rien de « ça démarre ».
  · Vérifier qu'un événement de test arrive réellement sur le projet Sentry.
  · iOS : vérifier la réception d'un push sur un build TestFlight.
RAPPEL
