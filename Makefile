# Backend
backend-image:
	docker build -t barrydevops/onlyflick-backend:latest -f k8s/backend/Dockerfile .

# Frontend
frontend-image:
	docker build -t barrydevops/onlyflick-frontend:latest -f k8s/frontend/Dockerfile .

# Push to Docker Hub
push-backend:
	docker push barrydevops/onlyflick-backend:latest

push-frontend:
	docker push barrydevops/onlyflick-frontend:latest

# Kubernetes Apply
apply-backend:
	kubectl apply -f k8s/backend

apply-frontend:
	kubectl apply -f k8s/frontend

apply-ingress:
	kubectl apply -f k8s/ingress

apply-monitoring:
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f k8s/monitoring/grafana-values.yaml

all: backend-image frontend-image push-backend push-frontend apply-backend apply-frontend apply-ingress
