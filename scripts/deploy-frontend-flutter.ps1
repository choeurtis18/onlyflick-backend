Write-Host "Deploiement Frontend Flutter OnlyFlick" -ForegroundColor Green

# 1. Vérifier si le frontend existe
Write-Host "`n1. Verification sous-module frontend..." -ForegroundColor Yellow
if (Test-Path "onlyflick-app") {
    Write-Host "✅ Frontend Flutter trouvé" -ForegroundColor Green
    cd onlyflick-app
    
    # 2. Build Flutter pour le web
    Write-Host "`n2. Build Flutter Web..." -ForegroundColor Yellow
    flutter clean
    flutter pub get
    flutter build web --release
    
    # 3. Créer image Docker pour le frontend
    Write-Host "`n3. Creation image Docker frontend..." -ForegroundColor Yellow
    @"
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
"@ | Out-File -FilePath Dockerfile -Encoding UTF8
    
    # 4. Configuration nginx pour Flutter
    @"
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;
    
    location / {
        try_files `$uri `$uri/ /index.html;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
"@ | Out-File -FilePath nginx.conf -Encoding UTF8
    
    # 5. Build image
    docker build -t onlyflick-frontend:latest .
    
    cd ../..
} else {
    Write-Host "❌ Frontend Flutter non trouvé" -ForegroundColor Red
    Write-Host "Deploiement d'un frontend temporaire..." -ForegroundColor Yellow
    
    # Créer un frontend HTML temporaire
    New-Item -ItemType Directory -Path "temp-frontend" -Force
    @"
<!DOCTYPE html>
<html>
<head>
    <title>OnlyFlick - Interface Flutter</title>
    <style>
        body { font-family: Arial; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; text-align: center; padding: 50px; }
        .container { max-width: 600px; margin: 0 auto; }
        .logo { font-size: 3em; margin-bottom: 20px; }
        .description { font-size: 1.2em; margin-bottom: 30px; }
        .api-link { background: rgba(255,255,255,0.2); padding: 15px; border-radius: 10px; margin: 10px; display: inline-block; text-decoration: none; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🎬 OnlyFlick</div>
        <div class="description">Interface Flutter en cours de déploiement</div>
        <div>
            <a href="/api/health" class="api-link">🔗 API Backend Health</a>
            <a href="http://api.onlyflick.local" class="api-link">🚀 API Direct</a>
            <a href="http://grafana.local" class="api-link">📊 Monitoring</a>
        </div>
        <p>Status: ✅ Backend opérationnel | 🔄 Frontend Flutter en préparation</p>
    </div>
</body>
</html>
"@ | Out-File -FilePath "temp-frontend/index.html" -Encoding UTF8
}

# 6. Deployer le frontend
Write-Host "`n4. Deploiement frontend sur Kubernetes..." -ForegroundColor Yellow
kubectl apply -f k8s/frontend/

Write-Host "`n✅ Frontend deploye!" -ForegroundColor Green
Write-Host "Testez: http://onlyflick.local" -ForegroundColor Cyan
