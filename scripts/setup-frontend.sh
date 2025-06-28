#!/bin/bash

# Script de setup du frontend Flutter OnlyFlick pour macOS
# Équivalent de setup-frontend.ps1

set -e  # Arrêter en cas d'erreur

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "${GREEN}$1${NC}"; }
print_info() { echo -e "${YELLOW}$1${NC}"; }
print_cyan() { echo -e "${CYAN}$1${NC}"; }

print_step "Setup du frontend Flutter OnlyFlick"

# 1. Ajouter le sous-module frontend
echo ""
print_info "1. Ajout du sous-module Flutter..."

if [ -d "onlyflick-app" ]; then
    print_cyan "Frontend déjà présent"
else
    echo "📦 Ajout du sous-module Git..."
    
    # Créer le répertoire frontend s'il n'existe pas
    mkdir -p frontend
    
    # Ajouter le sous-module
    git submodule add https://github.com/ibrahima-eemi/onlyflick.git onlyflick-app
    
    # Commit le changement
    git add .gitmodules onlyflick-app
    git commit -m "Ajout du frontend Flutter en sous-module" || true
    
    echo "✅ Sous-module ajouté"
fi

# 2. Initialiser le frontend
echo ""
print_info "2. Initialisation du frontend..."

# Vérifier que Flutter est installé
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter n'est pas installé${NC}"
    echo "Installation: https://docs.flutter.dev/get-started/install/macos"
    echo "Ou avec Homebrew: brew install --cask flutter"
    exit 1
fi

echo "✅ Flutter détecté: $(flutter --version | head -1)"

# Aller dans le répertoire du frontend
cd onlyflick-app

echo "🧹 Nettoyage des dépendances..."
flutter clean

echo "📦 Installation des dépendances..."
flutter pub get

# 3. Build pour la production web
echo ""
print_info "3. Build production web..."

echo "🔨 Build web en cours..."
flutter build web --release

echo ""
print_step "Frontend Flutter ready!"

# Retourner au répertoire racine
cd ../..

# Afficher des informations utiles
echo ""
print_info "📁 Structure créée:"
echo "  onlyflick-app/          # Code source Flutter"
echo "  onlyflick-app/build/web/ # Build web prêt pour déploiement"
echo ""
print_info "🧪 Pour tester localement:"
echo "  cd onlyflick-app"
echo "  flutter run -d web-server --web-port 3000"
echo ""
print_info "🚀 Le build web est dans: onlyflick-app/build/web/"