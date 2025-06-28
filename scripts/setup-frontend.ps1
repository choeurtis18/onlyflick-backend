Write-Host "Setup du frontend Flutter OnlyFlick" -ForegroundColor Green

# 1. Ajouter le sous-module frontend
Write-Host "`n1. Ajout du sous-module Flutter..." -ForegroundColor Yellow
if (Test-Path "onlyflick-app") {
    Write-Host "Frontend deja present" -ForegroundColor Cyan
} else {
    git submodule add https://github.com/ibrahima-eemi/onlyflick.git onlyflick-app
    git commit -m "Ajout du frontend Flutter en sous-module"
}

# 2. Initialiser le frontend
Write-Host "`n2. Initialisation du frontend..." -ForegroundColor Yellow
cd onlyflick-app
flutter clean
flutter pub get

# 3. Build pour la production web
Write-Host "`n3. Build production web..." -ForegroundColor Yellow
flutter build web --release

Write-Host "`nFrontend Flutter ready!" -ForegroundColor Green
cd ../..
