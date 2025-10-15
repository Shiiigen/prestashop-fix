#!/bin/bash

# =========================================================
# Réinjection PrestaShop - Version finale 1.4.0
# =========================================================
# Historique des versions initiales :
# 
# Version 1.1.4 Réinjection Presta
# - Correction des URLs de téléchargement des versions 1.6.0.X de Presta
# - Ajout d'une détection améliorée pour les versions 1.7.x via config/autoload.php
#
# Version 1.1.5 Réinjection Presta
# - Correction de certaines commandes (history -c)
# - Ajout de modifications des droits de dossier/fichiers (755/644)
#
# Version 1.2 Réinjection Presta
# - Ajout du support de la version 9.0-1.0 PrestaShop
#
# Modifications finales (1.4.0) :
# Objectifs des modifications :
# 1. Rollback automatique : sauvegarde complète avant réinjection.
# 2. Dry-run interactif : possibilité de tester sans modifier les fichiers.
# 3. Sélection de version : automatique (détection) ou manuelle via prompt.
# 4. Test post-install : vérifie la présence du fichier settings.inc.php après réinjection.
# 5. Logging complet : fichier horodaté pour chaque exécution.
# 6. Sécurité : vérification existence commandes, dossiers, fichiers avant actions.
# 7. Compatibilité Linux/macOS : suppression de grep -P, utilisation de grep, cut, awk.
# =========================================================

set -e  # Arrête le script si une commande échoue

# ============================
# Variables
# ============================
LOG_FILE="prestashop_reinject_$(date +%Y%m%d_%H%M%S).log"
BACKUP_DIR="prestashop_backup_$(date +%Y%m%d_%H%M%S)"
TEMP_DIR="prestashop_temp"
DRY_RUN=false
PRESTASHOP_VERSION=""

# ============================
# Fonctions utilitaires
# ============================

# Logging avec horodatage
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Message d'erreur et sortie
error_exit() {
  log "ERREUR : $1"
  exit 1
}

# Vérifie que la commande est disponible
check_command() {
  command -v "$1" >/dev/null 2>&1 || error_exit "$1 est manquant. Installez-le pour continuer."
}

# Crée une sauvegarde complète du site
backup_site() {
  log "Création d'une sauvegarde complète dans $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  cp -vaR * "$BACKUP_DIR/"
}

# Restaure la sauvegarde en cas d'erreur
rollback() {
  log "Restauration depuis la sauvegarde $BACKUP_DIR"
  rm -vrf * 2>/dev/null || true
  cp -vaR "$BACKUP_DIR/"* .
  log "Rollback terminé."
}

# Téléchargement et extraction sécurisés
download_and_extract() {
  local url="$1"
  local zip_file="$2"
  local target_dir="$3"

  log "Téléchargement : $url"
  wget -O "$zip_file" "$url"

  log "Extraction : $zip_file"
  mkdir -p "$target_dir"
  unzip -o "$zip_file" -d "$target_dir"

  log "Suppression du zip : $zip_file"
  rm -f "$zip_file"
}

# Application des permissions sécurisées
set_permissions() {
  log "Application des permissions 644 pour fichiers et 755 pour dossiers"
  find . -type f -exec chmod 644 {} \;
  find . -type d -exec chmod 755 {} \;
}

# Test post-install minimal : vérifie que settings.inc.php existe
post_install_test() {
  if [ -f "config/settings.inc.php" ]; then
    log "Test post-install réussi : config/settings.inc.php présent"
  else
    error_exit "Test post-install échoué : config/settings.inc.php manquant"
  fi
}

# ============================
# Gestion des erreurs et rollback automatique
# ============================
trap 'log "Erreur détectée. Exécution du rollback..."; rollback; exit 1' ERR

# ============================
# Vérification commandes essentielles
# ============================
check_command wget
check_command unzip
check_command cp
check_command rm
check_command find

# ============================
# Détection automatique de la version PrestaShop
# ============================

prestashop_1_6() {
  local file="config/settings.inc.php"
  [ -f "$file" ] && grep "define('_PS_VERSION_'" "$file" | cut -d "'" -f4
}

prestashop_autoload() {
  local file="config/autoload.php"
  [ -f "$file" ] && grep "define('_PS_VERSION_'" "$file" | cut -d "'" -f4
}

prestashop_1_7() {
  local version=$(prestashop_autoload)
  if [ -z "$version" ]; then
    local file="app/AppKernel.php"
    [ -f "$file" ] && version=$(grep "const VERSION" "$file" | cut -d "'" -f2)
  fi
  echo "$version"
}

prestashop_8() {
  local file="app/AppKernel.php"
  if [ -f "$file" ]; then
    local major=$(grep "const MAJOR_VERSION" "$file" | awk '{print $3}')
    local minor=$(grep "const MINOR_VERSION" "$file" | awk '{print $3}')
    local release=$(grep "const RELEASE_VERSION" "$file" | awk '{print $3}')
    echo "$major.$minor.$release"
  fi
}

prestashop_9() {
  local file="app/AppKernel.php"
  if [ -f "$file" ]; then
    local major=$(grep "const MAJOR_VERSION" "$file" | awk '{print $3}')
    local minor=$(grep "const MINOR_VERSION" "$file" | awk '{print $3}')
    local release=$(grep "const RELEASE_VERSION" "$file" | awk '{print $3}')
    [[ "$major" == "9" ]] && echo "$major.$minor.$release"
  fi
}

# ============================
# Prompt utilisateur pour dry-run et version
# ============================
read -p "Voulez-vous activer le mode dry-run (test sans modifications) ? (y/N) : " DRY_INPUT
[[ "$DRY_INPUT" =~ ^[Yy]$ ]] && DRY_RUN=true

log "Mode dry-run : $DRY_RUN"

# Détection automatique
detected_version=$(prestashop_1_6)
[ -z "$detected_version" ] && detected_version=$(prestashop_1_7)
[ -z "$detected_version" ] && detected_version=$(prestashop_8)
[ -z "$detected_version" ] && detected_version=$(prestashop_9)

read -p "Version détectée automatiquement : $detected_version. Voulez-vous utiliser une version différente ? (laisser vide = automatique) : " user_version
PRESTASHOP_VERSION="${user_version:-$detected_version}"

[ -z "$PRESTASHOP_VERSION" ] && error_exit "Impossible de déterminer la version de PrestaShop."
log "Version sélectionnée pour réinjection : $PRESTASHOP_VERSION"

# ============================
# Backup avant réinjection
# ============================
backup_site

# ============================
# Téléchargement et extraction
# ============================
mkdir -p "$TEMP_DIR"

if [[ "$PRESTASHOP_VERSION" == 1.6* ]]; then
  log "Réinjection PrestaShop 1.6"
  URL="https://dl.shiigen.fr/1.6/prestashop_$PRESTASHOP_VERSION.zip"
elif [[ "$PRESTASHOP_VERSION" == 9.* ]]; then
  log "Réinjection PrestaShop 9 (édition basique)"
  URL="https://dl.shiigen.fr/9/prestashop_$PRESTASHOP_VERSION.zip"
else
  log "Réinjection PrestaShop via GitHub"
  URL="http://github.com/PrestaShop/PrestaShop/releases/download/$PRESTASHOP_VERSION/prestashop_$PRESTASHOP_VERSION.zip"
fi

if [ "$DRY_RUN" = false ]; then
  download_and_extract "$URL" "prestashop_$PRESTASHOP_VERSION.zip" "$TEMP_DIR"
else
  log "Dry-run activé : téléchargement et extraction simulés"
fi

# ============================
# Copie des fichiers extraits
# ============================
if [ "$DRY_RUN" = false ]; then
  if [ -d "$TEMP_DIR/prestashop" ]; then
    log "Copie des fichiers dans le répertoire courant"
    cp -vaR "$TEMP_DIR/prestashop/"* .
  else
    error_exit "Dossier prestashop introuvable après extraction."
  fi
else
  log "Dry-run : copie simulée"
fi

# ============================
# Nettoyage
# ============================
if [ "$DRY_RUN" = false ]; then
  log "Nettoyage des dossiers temporaires et admin/install/cache"
  rm -vrf "$TEMP_DIR" admin/ install/ var/cache 2>/dev/null || true
  rm -f prestashop_fix.sh
else
  log "Dry-run : nettoyage simulé"
fi

# ============================
# Permissions
# ============================
if [ "$DRY_RUN" = false ]; then
  set_permissions
else
  log "Dry-run : permissions simulées"
fi

# ============================
# Test post-install minimal
# ============================
if [ "$DRY_RUN" = false ]; then
  post_install_test
else
  log "Dry-run : test post-install simulé"
fi

log "Réinjection PrestaShop terminée avec succès !"
