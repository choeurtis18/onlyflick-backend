#!/bin/bash

echo "🚀 Build OnlyFlick APK pour la production"
echo "=========================================="

# 1. Nettoyage du projet
echo "🧹 Nettoyage du projet..."
flutter clean

# 2. Récupération des dépendances
echo "📦 Récupération des dépendances..."
flutter pub get

# 3. Vérification du code
echo "🔍 Analyse du code..."
flutter analyze

# 4. Test de compilation
echo "🔧 Test de compilation..."
flutter build apk --debug

if [ $? -eq 0 ]; then
    echo "✅ Compilation debug réussie"
else
    echo "❌ Erreur de compilation debug"
    exit 1
fi

# 5. Build APK de production
echo "🏗️  Génération de l'APK de production..."
flutter build apk --release

if [ $? -eq 0 ]; then
    echo "✅ APK de production généré avec succès !"
    echo ""
    echo "📁 Emplacement de l'APK :"
    echo "   build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    
    # Afficher la taille du fichier
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    if [ -f "$APK_PATH" ]; then
        SIZE=$(du -h "$APK_PATH" | cut -f1)
        echo "📊 Taille de l'APK : $SIZE"
    fi
    
    echo ""
    echo "🎯 Prochaines étapes :"
    echo "   1. Testez l'APK sur un appareil Android"
    echo "   2. L'APK est configuré pour pointer vers votre API de production"
    echo "   3. Distribuez l'APK ou uploadez sur Play Store"
    
else
    echo "❌ Erreur lors de la génération de l'APK de production"
    exit 1
fi

# 6. (Optionnel) Build App Bundle pour Play Store
echo ""
read -p "🤔 Voulez-vous aussi générer l'App Bundle pour Play Store ? (y/n): " generate_bundle

if [ "$generate_bundle" = "y" ] || [ "$generate_bundle" = "Y" ]; then
    echo "🏗️  Génération de l'App Bundle..."
    flutter build appbundle --release
    
    if [ $? -eq 0 ]; then
        echo "✅ App Bundle généré avec succès !"
        echo "📁 Emplacement : build/app/outputs/bundle/release/app-release.aab"
        
        BUNDLE_PATH="build/app/outputs/bundle/release/app-release.aab"
        if [ -f "$BUNDLE_PATH" ]; then
            SIZE=$(du -h "$BUNDLE_PATH" | cut -f1)
            echo "📊 Taille de l'App Bundle : $SIZE"
        fi
    else
        echo "❌ Erreur lors de la génération de l'App Bundle"
    fi
fi

echo ""
echo "🎉 Build terminé !"