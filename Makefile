# Variables
DOCKER_USER=barrydevops

# -------------------------
#      DOCKER BUILD
# -------------------------

# Backend
backend-image:
	docker build -t $(DOCKER_USER)/onlyflick-backend:latest -f k8s/backend/Dockerfile .

# Frontend
frontend-image:
	docker build -t $(DOCKER_USER)/onlyflick-frontend:latest -f k8s/frontend/Dockerfile .

# -------------------------
#      DOCKER PUSH
# -------------------------

push-backend:
	docker push $(DOCKER_USER)/onlyflick-backend:latest

push-frontend:
	docker push $(DOCKER_USER)/onlyflick-frontend:latest

# -------------------------
#     K8S DEPLOYMENTS
# -------------------------

apply-backend:
	kubectl apply -f k8s/backend

apply-frontend:
	kubectl apply -f k8s/frontend

apply-ingress:
	kubectl apply -f k8s/ingress

apply-grafana:
	helm upgrade --install grafana oci://registry-1.docker.io/bitnamicharts/grafana \
	-n monitoring --create-namespace -f k8s/monitoring/grafana-values.yaml

# -------------------------
#     K8S CLEANUP
# -------------------------

clean:
	kubectl delete -f k8s/backend --ignore-not-found
	kubectl delete -f k8s/frontend --ignore-not-found
	kubectl delete -f k8s/ingress --ignore-not-found

delete-grafana:
	helm uninstall grafana -n monitoring || true

# -------------------------
#       ALL-IN-ONE
# -------------------------

all: backend-image frontend-image push-backend push-frontend apply-backend apply-frontend apply-ingress

reset: clean delete-grafana all apply-grafana
