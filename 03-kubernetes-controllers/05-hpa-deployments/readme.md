### Deploy the [ngx-admin-deployments.yml](ngx-admin-deployments.yml)
```bash
kubectl apply -f ngx-admin-deployments.yml
kubectl apply -f ngx-admin-hpa.yml

kubectl get svc
```

### To do the load testing, replace the IP
```bash
cassowary run -u http://34.69.27.55/ -c 1000 -n 10000 --duration 50

cassowary run -u http://34.69.27.55/ -c 10000 -n 10000 --duration 50
```

### To Use GCLOUD custom Metrics
- [Deploying Gateways](https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-gateways#enable-gateway)
- [Configuring horizontal Pod autoscaling](https://cloud.google.com/kubernetes-engine/docs/how-to/horizontal-pod-autoscaling)

