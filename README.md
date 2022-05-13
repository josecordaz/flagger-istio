# Introduction
The purpose of this tutorial is to demonstrate how flagger works for a canary release and using the service mesh called Istio. 

# Prerequisites
- Kind 0.12.0 [install link](https://kind.sigs.k8s.io/)
- Istio 1.13.1 [download link](https://istio.io/latest/docs/setup/getting-started/#download)

# Environment setup in a single command:
```
chmod +x setup.sh
./setup.sh
```

# Individual steps to environment setup:
1.- Create kind cluster
```
kind create cluster --name istio-flagger
```
2.- Install Istio with telemetry support and Prometheus:
```
istioctl manifest install --set profile=default -y
```
```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/prometheus.yaml
```
3.- Install Flagger in the istio-system namespace:
```
kubectl apply -k github.com/fluxcd/flagger//kustomize/istio
```
4.- Create ingress gateway to expose the podinfo app outside of the mesh:
```
kubectl apply -f istio-ingress.yaml
```
5.- Create a test namespace with Istio sidecar injection enabled:
```
kubectl create ns test
kubectl label namespace test istio-injection=enabled
```
6.- Create a deployment and a horizontal pod autoscaler:
```
kubectl apply -k https://github.com/fluxcd/flagger//kustomize/podinfo?ref=main
```
7.- Deploy the load testing service to generate traffic during the canary analysis:
```
kubectl apply -k https://github.com/fluxcd/flagger//kustomize/tester\?ref\=main
```
8.- Apply canary configuration for podinfo:
```
kubectl apply -f podinfo-canary-config.yaml
```

# How to trigger the canary release
```
kubectl -n test set image deployment/podinfo \
podinfod=ghcr.io/stefanprodan/podinfo:6.0.2
```

# Brief description of what will happen

Flagger will react to the new image tag:
```
{...,"msg":"New revision detected! Scaling up podinfo.test","canary":"podinfo.test"}
```
Then new podinfo pods (canary deployment) will scale up using the new version `6.0.2`

The testloader will start generating traffic and it will be redirected gradually to the canary deployment.

If everything goes well with testing, 100% of traffic will be redirected to the canary deployment, which will result in primary pod deployment restarting using the new image tag.

Then the traffic will be redirected back to the primary deployment:
```
{..., "msg":"Routing all traffic to primary","canary":"podinfo.test"}
```

And finally the canary deployment will be deleted:
```
{..., "msg":"Promotion completed! Scaling down podinfo.test","canary":"podinfo.test"}
```

If for some reason the canary release fails then flagger will rollback the image tag to the previous one:
```
{...,"msg":"Rolling back podinfo.test failed checks threshold reached 5","canary":"podinfo.test"}
{...,"msg":"Canary failed! Scaling down podinfo.test","canary":"podinfo.test"}

```

# Problems I faced

1.- Misleading logs like:
```
Halt advancement no values found for istio metric request-duration probably podinfo.test is not receiving traffic
```
2.- Hard to debug:

There was a wrong url in the load test webhook leading to the release to fail, but it wasn't pretty clear anywhere what the problem was.