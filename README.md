# Kubernetes Reverse Proxy

[Kong](https://konghq.com/) offers an open source reverse proxy service built on top of nginx that can run on [Kubernetes](https://docs.konghq.com/gateway/3.8.x/install/kubernetes/proxy/).

This repo demos how to spin up an instnace of the reverse proxy locally.

## Dependencies

* [colima](https://github.com/abiosoft/colima) local k8s orchestration
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/) k8s cli
* [helm](https://helm.sh/docs/intro/quickstart/) k8s package manager
* (optional) [k9s](https://k9scli.io/) k8s termina-based UI

## Demo

Start up the reverse proxy services:
```
make bootstrap
```

![k9s_pods](./images/k9s-pods.png)

Enable port forwarding in a separate shell:
```
make port-forward
```

Configure an endpoint:
```
make create-mock-service
```

Validate:
```
make test
```

Teardown:
```
make nuke
```

Note: This local implementation relies on runnning a [k3s](https://k3s.io/) node using colima. This can be ran separately independently from the reverse proxy services for other use cases.

Start k3s node:
```
colima start --kubernetes
```
Terminate k3s node:
```
colima stop
```

## Use Cases

### Proxy Gateway

A reverse proxy enables a single ingress point to upstream web services. The Kong Gateway accomplishes this through path based routing. This is useful for scenarios where you have upstream web apps or APIs that are non-public facing, but still require secure ingress from the internet. You can configure paths to your private web services in Kong, expose the K8s ingress entrypoint, and apply one of the supported authentication methods at the proxy level (see [Kong Auth plugins](https://docs.konghq.com/hub/?tier=free&category=authentication)).

Configure Service A:
```
curl "localhost:8001/services" -d name=serviceA -d url="https://speerportfolio.com"
```
And a corresponding Route:
```
curl "localhost:8001/services/serviceA/routes" -d paths="/"
```

Confiugre Service B:
```
curl "localhost:8001/services" -d name=serviceB -d url="https://github.com/kspeer825"
```
And it's corresponding Route:
```
curl "localhost:8001/services/serviceB/routes" -d paths="/gh" -d preserve_host=true
```

Validate:

You can now proxy requests from your local k8s cluster to two different websites using different paths: [localhost/](https://localhost/) and [localhost/gh](https://localhost/gh).

![portfolio](./images/portfolio.png)

![github](./images/github.png)

### Response Caching

Responses for frequently made requests can be cached at your ingress point in order to reduce response times, and lighten the load on upstream services. The open source [Proxy Cache](https://docs.konghq.com/hub/kong-inc/proxy-cache/) plugin can be configured based on request method, content type, and status code. It can be applied to a specific endpoint or requester.

Configure:
```
curl "localhost:8001/plugins" -d "name=proxy-cache" -d "config.request_method=GET" -d "config.response_code=200" -d "config.content_type=application/json" -d "config.cache_ttl=30" -d "config.strategy=memory"
```

Validate:
```
curl -s -i -X GET http://localhost:80/mock/anything | grep X-Cache
```

![cache_hit](./images/cache-hit.png)


### Rate Limiting

Rate limiting can be enabled in order to protect against DOS attaks, or to limit usage on upstream services. The open source [Rate Limiting](https://docs.konghq.com/hub/kong-inc/rate-limiting/) plugin can be configured based on requests per unit time (second, minute, hour, etc.). It can be applied to a specific endpoit or requester, and can aggregate requests by various fields.

Confiugre:
```
curl localhost:8001/plugins -d "name=rate-limiting" -d "config.minute=5" -d "config.policy=local"

```

Validate:
```
for _ in {1..6}; do curl -i -s localhost:80/mock/anything; sleep 1; done
```