#!/bin/bash

# 🛠️ Scripts de développement OnlyFlick
# Usage: ./scripts/dev_commands.sh [command]

case "$1" in
  # === DÉVELOPPEMENT LOCAL ===
  "dev")
    echo "🚀 Lancement en mode développement..."
    flutter run --debug --dart-define=ENVIRONMENT=development
    ;;
    
  "dev-ios")
    echo "📱 Lancement iOS en mode développement..."
    flutter run --debug --dart-define=ENVIRONMENT=development -d ios
    ;;
    
  "dev-android")
    echo "🤖 Lancement Android en mode développement..."
    flutter run --debug --dart-define=ENVIRONMENT=development -d android
    ;;

  # === TESTS ===
  "test")
    echo "🧪 Lancement des tests..."
    flutter test
    ;;
    
  "test-integration")
    echo "🔗 Tests d'intégration..."
    flutter test integration_test/
    ;;
    
  "test-api")
    echo "🌐 Test de connexion API..."
    dart run test_connection.dart
    ;;

  # === BUILD DE DÉVELOPPEMENT ===
  "build-dev-android")
    echo "🔨 Build Android développement..."
    flutter build apk --debug --dart-define=ENVIRONMENT=development
    ;;
    
  "build-dev-ios")
    echo "🔨 Build iOS développement..."
    flutter build ios --debug --dart-define=ENVIRONMENT=development
    ;;

  # === BUILD DE PRODUCTION ===
  "build-prod-android")
    echo "🏭 Build Android production..."
    flutter build apk --release --dart-define=ENVIRONMENT=production
    ;;
    
  "build-prod-ios")
    echo "🏭 Build iOS production..."
    flutter build ios --release --dart-define=ENVIRONMENT=production
    ;;
    
  "build-prod-web")
    echo "🌐 Build Web production..."
    flutter build web --release --dart-define=ENVIRONMENT=production
    ;;

  # === NETTOYAGE ===
  "clean")
    echo "🧹 Nettoyage complet..."
    flutter clean
    rm -rf .dart_tool/
    rm -rf build/
    cd ios && rm -rf build/ && pod install && cd ..
    cd android && ./gradlew clean && cd ..
    flutter pub get
    ;;

  # === MAINTENANCE ===
  "update")
    echo "⬆️ Mise à jour des dépendances..."
    flutter pub upgrade
    cd ios && pod update && cd ..
    ;;
    
  "analyze")
    echo "🔍 Analyse du code..."
    flutter analyze
    ;;
    
  "format")
    echo "💅 Formatage du code..."
    dart format lib/ test/
    ;;

  # === GÉNÉRATION DE CODE ===
  "generate")
    echo "⚙️ Génération de code..."
    flutter packages pub run build_runner build --delete-conflicting-outputs
    ;;

  # === SERVEUR LOCAL ===
  "server")
    echo "🖥️ Démarrage du serveur Go local..."
    echo "Assurez-vous d'être dans le dossier du backend"
    echo "Commande: go run cmd/server/main.go"
    ;;

  # === HELP ===
  "help"|*)
    echo "🛠️ Commandes de développement OnlyFlick"
    echo "========================================"
    echo ""
    echo "DÉVELOPPEMENT:"
    echo "  dev              - Lance l'app en mode développement"
    echo "  dev-ios          - Lance sur iOS en mode développement" 
    echo "  dev-android      - Lance sur Android en mode développement"
    echo ""
    echo "TESTS:"
    echo "  test             - Lance les tests unitaires"
    echo "  test-integration - Lance les tests d'intégration"
    echo "  test-api         - Teste la connexion API"
    echo ""
    echo "BUILD DÉVELOPPEMENT:"
    echo "  build-dev-android - Build APK de développement"
    echo "  build-dev-ios     - Build iOS de développement"
    echo ""
    echo "BUILD PRODUCTION:"
    echo "  build-prod-android - Build APK de production"
    echo "  build-prod-ios     - Build iOS de production"
    echo "  build-prod-web     - Build Web de production"
    echo ""
    echo "MAINTENANCE:"
    echo "  clean            - Nettoyage complet du projet"
    echo "  update           - Mise à jour des dépendances"
    echo "  analyze          - Analyse du code"
    echo "  format           - Formatage du code"
    echo "  generate         - Génération de code"
    echo ""
    echo "SERVEUR:"
    echo "  server           - Aide pour démarrer le serveur Go"
    echo ""
    echo "Usage: ./scripts/dev_commands.sh [commande]"
    ;;
esac