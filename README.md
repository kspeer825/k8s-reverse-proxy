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

TODO