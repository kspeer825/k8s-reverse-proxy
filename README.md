# Kubernetes Reverse Proxy

[Kong](https://konghq.com/) offers an open source reverse-proxy service built on top of nginx that can run on [Kubernetes](https://docs.konghq.com/gateway/3.8.x/install/kubernetes/proxy/).

This repo demos how to run the Kong Gateway on K8s.

## Dependencies

* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/) k8s cli
* [helm](https://helm.sh/docs/intro/quickstart/) k8s package manager
* [colima](https://github.com/abiosoft/colima) local k8s orchestration

## Local Bootstrap

Start a [k3s](https://k3s.io/) node using colima:
```
colima start --kubernetes
```

Start up the Kong Gateway services:
```
make bootstrap
```

## Use Cases

### Proxy Gateway

A reverse proxy enables a single ingress point to upstream web services. The Kong Gateway accomplishes this through path based routing.

Create Service A:
```
curl "localhost:8001/services" -d name=serviceA -d url="https://speerportfolio.com"
```
And a corresponding Route:
```
curl "localhost:8001/services/serviceA/routes" -d paths="/"
```

Create Service B:
```
curl "localhost:8001/services" -d name=serviceB -d url="https://github.com/kspeer825"
```
And it's corresponding Route:
```
curl "localhost:8001/services/serviceB/routes" -d paths="/gh" -d preserve_host=true
```

You can now proxy requests from your local k8s cluster to my personal web site, and my Github profile via [localhost/](https://localhost/) and [localhost/gh](https://localhost/gh). This is useful for scenarios where you have upstream web apps or APIs that are non-public facing, yet you need to expose them safely to the internet. You can configure paths to your private web services in Kong, expose the K8s ingress entrypoint, and apply one of the supported authentication methods at the proxy level (see [Kong Auth plugins](https://docs.konghq.com/hub/?tier=free&category=authentication)).

### Response Caching
ToDo - example writeup

### Rate Limiting
ToDo - example writeup