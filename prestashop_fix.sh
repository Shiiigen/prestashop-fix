#!/bin/bash

# Version 1.1.4 Réinjection Presta

# - Correction des URLs de téléchargement des versions 1.6.0.X de Presta
# - Ajout d'une détection améliorée pour les versions 1.7.x via config/autoload.php

# Version 1.1.5 Réinjection Presta

# - Correction de certaines commandes (history -c)
# - Ajout de modifications des droits de dossier/fichiers (755/644)

# Version 1.2 Réinjection Presta

# - Ajout du support de la version 9.0-1.0 prestashop.

prestashop_1_6() {
  local file="config/settings.inc.php"
  if [ -f "$file" ]; then
    grep -oP "define\('_PS_VERSION_', '\K[0-9\.]+" "$file"
  fi
}

prestashop_1_7() {
  local version=""

  version=$(prestashop_autoload)

  if [ -z "$version" ]; then
    local file="app/AppKernel.php"
    if [ -f "$file" ]; then
      version=$(grep -oP "const VERSION = '\K[0-9\.]+" "$file")
    fi
  fi

  echo "$version"
}

prestashop_autoload() {
  local file="config/autoload.php"
  if [ -f "$file" ]; then
    grep -oP "define\('_PS_VERSION_', '\K[0-9\.]+" "$file"
  fi
}

prestashop_8() {
  local file="app/AppKernel.php"
  if [ -f "$file" ]; then
    local major_version=$(grep -oP "const MAJOR_VERSION = \K[0-9]+" "$file")
    local minor_version=$(grep -oP "const MINOR_VERSION = \K[0-9]+" "$file")
    local release_version=$(grep -oP "const RELEASE_VERSION = \K[0-9]+" "$file")
    echo "$major_version.$minor_version.$release_version"
  fi
}

# Fonction beta, qui pourra changer.
prestashop_9() {
  local file="app/AppKernel.php"
  if [ -f "$file" ]; then
    local major_version=$(grep -oP "const MAJOR_VERSION = \K[0-9]+" "$file")
    local minor_version=$(grep -oP "const MINOR_VERSION = \K[0-9]+" "$file")
    local release_version=$(grep -oP "const RELEASE_VERSION = \K[0-9]+" "$file")

    if [[ "$major_version" == "9" ]]; then
      echo "$major_version.$minor_version.$release_version"
    fi
  fi
}

# Détection de la version de PrestaShop
prestashop_version=$(prestashop_1_6)

if [ -z "$prestashop_version" ]; then
  prestashop_version=$(prestashop_1_7)
fi

if [ -z "$prestashop_version" ]; then
  prestashop_version=$(prestashop_8)
fi

if [ -z "$prestashop_version" ]; then
  prestashop_version=$(prestashop_9)
fi

if [ -z "$prestashop_version" ]; then
  echo "Erreur : Impossible de déterminer la version de PrestaShop. Vérifiez le dossier."
  exit 1
fi

echo "La version de PrestaShop est : $prestashop_version"
PRESTASHOP_VERSION="$prestashop_version"

# Télécharger et réinjecter la bonne version
if [[ "$PRESTASHOP_VERSION" == 1.6* ]]; then
  echo "Téléchargement et extraction de la version $PRESTASHOP_VERSION pour PrestaShop 1.6"
  wget "https://dl.shiigen.fr/1.6/prestashop_$PRESTASHOP_VERSION.zip" &&
  unzip -o "prestashop_$PRESTASHOP_VERSION.zip" &&
  rm -vf "prestashop_$PRESTASHOP_VERSION.zip" Install_PrestaShop.html &&
  cp -vaR prestashop/* . &&
  rm -vrf admin/ install/ &&
  rm -vrf prestashop/ &&
  rm -f prestashop_fix.sh &&
  find . -type f -exec chmod 644 {} \; -print; find . -type d -exec chmod 755 {} \; -print

# Fonction beta, qui changera lorsque le build sera présent sur le repo git de prestashop.
elif [[ "$PRESTASHOP_VERSION" == 9.* ]]; then
  echo "Téléchargement et extraction de PrestaShop $PRESTASHOP_VERSION (édition basique)"
  wget "https://assets.prestashop3.com/dst/edition/corporate/9.0.0-1.0/prestashop_edition_basic_version_$PRESTASHOP_VERSION-1.0.zip" &&
  unzip -o "prestashop_edition_basic_version_$PRESTASHOP_VERSION-1.0.zip" &&
  unzip -o "prestashop.zip" &&
  rm -vf "prestashop_edition_basic_version_$PRESTASHOP_VERSION-1.0.zip" &&
  rm -vrf "prestashop.zip" &&
  cp -vaR prestashop/* . &&
  rm -vrf prestashop/ &&
  rm -vrf admin/ install/ var/cache &&
  rm -f prestashop_fix.sh &&
  find . -type f -exec chmod 644 {} \; -print; find . -type d -exec chmod 755 {} \; -print

else
  echo "Téléchargement et extraction de la version $PRESTASHOP_VERSION via GitHub"
  wget "http://github.com/PrestaShop/PrestaShop/releases/download/$PRESTASHOP_VERSION/prestashop_$PRESTASHOP_VERSION.zip" &&
  unzip -o "prestashop_$PRESTASHOP_VERSION.zip" &&
  rm -vf "prestashop_$PRESTASHOP_VERSION.zip" &&
  unzip -o prestashop.zip &&
  rm -vrf prestashop.zip &&
  rm -vrf install/ admin/ var/cache &&
  rm -f prestashop_fix.sh &&
  find . -type f -exec chmod 644 {} \; -print; find . -type d -exec chmod 755 {} \; -print
fi
