
PROJECT_ID=$(shell gcloud config list project --format=flattened | awk 'FNR == 1 {print $$2}')
ZONE=us-west1-b

CLUSTER_NAME=my-istio-cluster
CLUSTER_VERSION=1.10

ZIPKIN_POD_NAME=$(shell kubectl -n istio-system get pod -l app=zipkin -o jsonpath='{.items[0].metadata.name}')
JAEGER_POD_NAME=$(shell kubectl -n istio-system get pod -l app=jaeger -o jsonpath='{.items[0].metadata.name}')
SERVICEGRAPH_POD_NAME=$(shell kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}')
GRAFANA_POD_NAME=$(shell kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
PROMETHEUS_POD_NAME=$(shell kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')

SLACKBOT_POD_NAME=$(shell kubectl get pod -l app=slackbot -o jsonpath='{.items[0].metadata.name}')

GCLOUD_USER=$(shell gcloud config get-value core/account)
GKE_CLUSTER=$(shell kubectl config get-clusters | grep my-istio-cluster)
CONTAINER_NAME=istiotest

# Boot the whole stack up from scratch
boot: create-cluster deploy-istio deploy get-stuff logs
	echo "Done!"

base:
	docker build --tag=alpine-java:base --rm=true -f Dockerfile.base .

run:
	gradle bootRun

build:
	gradle bootRepackage


all: base build package


deploy-swarm:
	docker stack deploy slackbot -c stack.yml

ls:
	docker stack ps slackbot

delete:
	docker stack rm slackbot


download-istio:
	wget https://github.com/istio/istio/releases/download/1.0.0/istio-1.0.0-linux.tar.gz
	tar -zxvf istio-1.0.0-linux.tar.gz

genereate-istio-template:
	helm template istio-1.0.0/install/kubernetes/helm/istio --name istio --namespace istio-system --set global.mtls.enabled=true --set tracing.enabled=true --set servicegraph.enabled=true --set grafana.enabled=true > istio.yaml

create-cluster:
	gcloud container --project "$(PROJECT_ID)" clusters create "$(CLUSTER_NAME)" --zone "$(ZONE)" --machine-type "n1-standard-1" --image-type "COS" --disk-size "100" --scopes "https://www.googleapis.com/auth/compute","https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "4" --network "default" --enable-cloud-logging --enable-cloud-monitoring --cluster-version=$(CLUSTER_VERSION)
	kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(GCLOUD_USER)

deploy-istio:
	-kubectl create namespace istio-system
	kubectl apply -f istio.yaml
	kubectl label namespace default istio-injection=enabled --overwrite
	sleep 60

deploy-stuff:
	kubectl apply -f ./configs/kube/services.yaml
	-sed -e 's~<PROJECT_ID>~$(PROJECT_ID)~g' ./configs/kube/deployments.yaml | kubectl apply -f -

get-stuff:
	kubectl get pods && kubectl get svc && kubectl get svc istio-ingressgateway -n istio-system

ingress:
	kubectl apply -f ./configs/istio/ingress.yaml
egress:
	kubectl apply -f ./configs/istio/egress.yaml
prod:
	kubectl apply -f ./configs/istio/destinationrules.yaml
	kubectl apply -f ./configs/istio/routing-1.yaml
retry:
	kubectl apply -f ./configs/istio/routing-2.yaml
canary:
	kubectl apply -f ./configs/istio/routing-3.yaml


start-monitoring-services:
	echo "Jager http://localhost:16686"
	echo "ServiceGraph http://localhost:8088"
	echo "Grafana http://localhost:3000"
	echo "Prometehus http://localhost:9090"
	$(shell kubectl -n istio-system port-forward $(JAEGER_POD_NAME) 16686:16686 & kubectl -n istio-system port-forward $(SERVICEGRAPH_POD_NAME) 8088:8088 & kubectl -n istio-system port-forward $(GRAFANA_POD_NAME) 3000:3000 & kubectl -n istio-system port-forward $(PROMETHEUS_POD_NAME) 9090:9090)

package: build
	docker build -t gcr.io/$(PROJECT_ID)/slackbot .

push: package
	-gcloud auth configure-docker
	docker push gcr.io/$(PROJECT_ID)/slackbot
	kubectl set image deployment/slackbot slackbot=gcr.io/$(PROJECT_ID)/slackbot:latest
	kubectl rollout status deployment slackbot

undeploy:
	kubectl delete deployment slackbot

deploy:
	-sed -e 's~<PROJECT_ID>~$(PROJECT_ID)~g' ./configs/deployment.yml | kubectl apply -f -

run-local:
	docker run -ti --network host gcr.io/$(PROJECT_ID)/$(CONTAINER_NAME):1.0
	    
restart-demo:
	-kubectl delete svc --all
	-kubectl delete deployment --all
	-kubectl delete VirtualService --all
	-kubectl delete DestinationRule --all
	-kubectl delete Gateway --all
	-kubectl delete ServiceEntry --all
	-kubectl delete PersistentVolumeClaim --all
	-kubectl delete PersistentVolume --all

uninstall-istio:
	-kubectl delete ns istio-system

delete-cluster: uninstall-istio
	-kubectl delete service slackbot
	-kubectl delete ingress istio-ingress
	gcloud container clusters delete "$(CLUSTER_NAME)" --zone "$(ZONE)"

run-jaeger-local:
	docker run -ti --name jaeger -e COLLECTOR_ZIPKIN_HTTP_PORT=9411 --network host jaegertracing/all-in-one:latest

port-forward:
	$(shell kubectl port-forward $(SLACKBOT_POD_NAME) 8080:8080)

migrate-poll:
	kubectl exec $(POLL_POD_NAME) python manage.py db init
	kubectl exec $(POLL_POD_NAME) python manage.py db migrate

logs:
	kubectl logs deployments/slackbot -c slackbot

user-rbac:
	kubectl create namespace office
	kubectl config set-context employee-context --cluster=$(GKE_CLUSTER) --namespace=office --user=employee
	kubectl create -f configs/rbac/role.yml