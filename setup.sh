kind create cluster --name istio-flagger
istioctl manifest install --set profile=default -y
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.8/samples/addons/prometheus.yaml
kubectl apply -k github.com/fluxcd/flagger//kustomize/istio
kubectl apply -f istio-ingress.yaml
kubectl create ns test
kubectl label namespace test istio-injection=enabled
kubectl apply -k https://github.com/fluxcd/flagger//kustomize/podinfo\?ref\=main
kubectl apply -k https://github.com/fluxcd/flagger//kustomize/tester\?ref\=main
kubectl apply -f podinfo-canary-config.yaml