SHELL = /bin/zsh

#########
# SETUP #
#########

.SILENT: bootstrap start-bootstrap end-bootstrap up down nuke nuke-msg test

.PHONY: bootstrap start-bootstrap end-bootstrap up down nuke nuke-msg test

up:
	echo "▶️  Helm install kong-cp:"
	helm install kong-cp kong/kong -n kong --values ./values-cp.yaml
	echo "⏸️. Waiting for CP to spin up..." && sleep 120
	echo "▶️  Helm install kong-dp:"
	helm install kong-dp kong/kong -n kong -f ./values-dp.yaml

down:
	helm uninstall kong-cp kong-dp || echo "⏭️  Skipping uninstall, releases likely already removed."

start-bootstrap:
	if [[ -z "$(shell colima status | grep 'colima is not running')" ]]; \
	  then; colima start --cpu 4 --memory 8 --kubernetes; fi
	echo "▶️  Bootstrapping Kong 🦍..."
	echo "▶️  Pulling helm charts..."
	helm repo add kong https://charts.konghq.com
	helm repo update
	echo "▶️  Setting up kong namespace ..."
	kubectl create namespace kong
	kubectl create secret generic kong-enterprise-license --from-literal=license="'{}'" -n kong
	echo "▶️  Setting cluster certs..."
	$(eval $(shell openssl req -new -x509 -nodes -newkey ec:<(openssl ecparam -name secp384r1) -keyout ./tls.key -out ./tls.crt -days 1095 -subj "/CN=kong_clustering"))
	kubectl create secret tls kong-cluster-cert --cert=./tls.crt --key=./tls.key -n kong

end-bootstrap:
	echo "⏹️  Bootstrap complete.\n\n"

bootstrap: start-bootstrap up end-bootstrap

nuke-msg:
	echo "🧨 NUKING Kong... "

nuke: nuke-msg down
	kubectl delete namespace kong || echo "⏭️  Skipping delete, namespace likely already removed."
	colima stop

port-forward:
	$(eval export POD=$(shell kubectl get pods --selector=app.kubernetes.io/instance=kong-dp -o name))
	kubectl port-forward -n kong service/kong-cp-kong-admin 8001 & \
	kubectl port-forward -n kong $(POD) 8005:8005 &
	@echo "CP Port Forwarding:  8001->8001 (Admin API)  8005->8005 (internal API)"
	@echo "CTRL-C to halt..."
	wait

test:
	if [[ $(shell curl -s -w "%{http_code}" "localhost:8001" -o /dev/null) == 200 ]]; \
	  then; echo "✅ Kong CP is Active."; \
	  else; echo "❌ Kong CP is Inactive, you may need to set port-forwarding on the admin API."; \
	  echo "In a seperate shell, try running:\n\tkubectl port-forward -n kong service/kong-cp-kong-admin 8001"; fi
	if [[ $(shell curl -s -w "%{http_code}" "localhost:80/mock/anything" -o /dev/null) == 200 ]]; \
	  then; echo "✅ Kong DP is Active."; \
	  else; echo "❌ Kong DP is Inactive, you may need to create the mock service."; \
	  echo "Try running:\n\tmake create-mock-service"; fi

#################
# CONFIGURATION #
#################

.PHONY: create-mock-service enable-metrics-plugin enable-caching-plugin

create-mock-service:
	@echo "Creating mock service..."
	curl -s "localhost:8001/services" -d name=mock  -d url="https://httpbin.konghq.com" | jq .
	curl -s "localhost:8001/services/mock/routes" -d "paths=/mock" | jq .

enable-metrics-plugin:
	@echo "Enabling metrics via prometheus plugin..."
	@curl -s -X POST http://localhost:8001/plugins \
	  --header "accept: application/json" \
	  --header "Content-Type: application/json" \
	  --data '{"name":"prometheus","config":{"status_code_metrics":true}}' | jq .

enable-caching-plugin:
	@echo "Enabling proxy caching..."
	@curl -s -X POST http://localhost:8001/plugins \
	  -d "name=proxy-cache" \
	  -d "config.request_method=GET" \
	  -d "config.response_code=200" \
	  -d "config.content_type=application/json" \
	  -d "config.cache_ttl=30" \
	  -d "config.strategy=memory" | jq .

enable-rate-limiting-plugin:
	@echo "Enabling rate limiting..."
	@curl -s -X POST http://localhost:8001/plugins \
	  -d "name=rate-limiting" \
	  -d "config.minute=5" \
	  -d "config.policy=local" | jq .
