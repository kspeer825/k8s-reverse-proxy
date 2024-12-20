SHELL = /bin/zsh

.SILENT: bootstrap start-bootstrap end-bootstrap up down nuke nuke-msg test

.PHONY: bootstrap start-bootstrap end-bootstrap up down nuke nuke-msg test

up:
	echo "▶️  Helm install kong-cp:"
	helm install kong-cp kong/kong -n kong --values ./values-cp.yaml
	echo "⏸️. Waitig for CP to spin up..." && sleep 120
	echo "▶️  Helm install kong-dp:"
	helm install kong-dp kong/kong -n kong -f ./values-dp.yaml

down:
	helm uninstall kong-cp kong-dp || echo "⏭️  Skipping uninstall, releases likely already removed."

start-bootstrap:
	if [[ -z "$(shell colima status | grep 'colima is not running')" ]]; \
	  then; colima start --kubernetes; fi
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
	echo "⏹️  Bootstrap complete."

bootstrap: start-bootstrap up end-bootstrap

nuke-msg:
	echo "🧨 NUKING Kong... "

nuke: nuke-msg down
	kubectl delete namespace kong || echo "⏭️  Skipping delete, namespace likely already removed."
	colima stop

test:
	if [[ $(shell curl -s -w "%{http_code}" "localhost:8001" -o /dev/null) == 200 ]]; \
	  then; echo "✅ Kong CP is Active."; \
	  else; echo "❌ Kong CP is Inactive, you may need to set port-forwarding on the admin API."; \
	  echo "In a seperate shell, try running:\n\tkubectl port-forward -n kong service/kong-cp-kong-admin 8001"; fi
	if [[ $(shell curl -s -w "%{http_code}" "localhost:80/mock/anything" -o /dev/null) == 200 ]]; \
	  then; echo "✅ Kong DP is Active."; \
	  else; echo "❌ Kong DP is Inactive, you may need to create the mock service."; \
	  echo "Try running:\n\tmake create-mock-service"; fi

.PHONY: create-mock-service

create-mock-service:
	@echo "Creating mock service..."
	curl -s "localhost:8001/services" -d name=mock  -d url="https://httpbin.konghq.com" | jq .
	curl -s "localhost:8001/services/mock/routes" -d "paths=/mock" | jq .
