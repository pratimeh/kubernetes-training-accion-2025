
## Set firewall Rule to allow NodePort access
```gcloud
gcloud config set project k8s-training-accion
gcloud compute firewall-rules create test-node-port --allow tcp:31111
```
