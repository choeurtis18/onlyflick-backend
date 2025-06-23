.PHONY: \
	backend-image frontend-image flutter-build \
	push-backend push-frontend \
	apply-backend apply-frontend apply-ingress apply-monitoring \
	rollout rollouts rollout-backend rollout-frontend \
	health-check deploy \
	all

# ========== Configuration ==========

ENV ?= onlyflick
NAMESPACE = $(ENV)
TAG ?= latest
BACKEND_IMAGE = barrydevops/onlyflick-backend
FRONTEND_IMAGE = barrydevops/onlyflick-frontend

# ========== Build Images ==========

backend-image:
	docker build -t $(BACKEND_IMAGE):$(TAG) -f k8s/backend/Dockerfile .

flutter-build:
	cd frontend/onlyflick-app && \
	flutter clean && flutter pub get && flutter build web

frontend-image: flutter-build
	docker build -t $(FRONTEND_IMAGE):$(TAG) -f frontend/onlyflick-app/Dockerfile frontend/onlyflick-app

# ========== Push to Docker Hub ==========

push-backend:
	docker push $(BACKEND_IMAGE):$(TAG)

push-frontend:
	docker push $(FRONTEND_IMAGE):$(TAG)

# ========== Kubernetes Apply ==========

apply-backend:
	kubectl apply -f k8s/backend -n $(NAMESPACE)

apply-frontend:
	kubectl apply -f k8s/frontend -n $(NAMESPACE)

apply-ingress:
	kubectl apply -f k8s/ingress -n $(NAMESPACE)

apply-monitoring:
	helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		-n monitoring --create-namespace \
		-f k8s/monitoring/grafana-values.yaml

# ========== Restart Deployments ==========

rollout-backend:
	kubectl rollout restart deployment/onlyflick-backend -n $(NAMESPACE)

rollout-frontend:
	kubectl rollout restart deployment/onlyflick-frontend -n $(NAMESPACE)

rollout: rollout-backend rollout-frontend

# ========== Health Check ==========

health-check:
	kubectl run test-health --image=curlimages/curl --rm -i --restart=Never -n $(NAMESPACE) -- \
		curl -f http://onlyflick-backend-service.$(NAMESPACE).svc.cluster.local/health

# ========== Main Shortcuts ==========

all: backend-image frontend-image push-backend push-frontend apply-backend apply-frontend apply-ingress

deploy: all rollout
