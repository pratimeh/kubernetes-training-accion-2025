#!/bin/bash
gcloud compute networks create k8s-training-nw --subnet-mode custom

gcloud compute networks subnets create k8s-training-nodes \
--network k8s-training-nw \
--range 10.240.0.0/24
## --zone asia-south1

gcloud compute firewall-rules create k8s-training-allow-internal \
--allow tcp,udp,icmp,ipip \
--network k8s-training-nw \
--source-ranges 10.240.0.0/24
## --zone asia-south1

gcloud compute firewall-rules create k8s-training-allow-external \
--allow tcp:22,tcp:6443,icmp \
--network k8s-training-nw \
--source-ranges 0.0.0.0/0

# Create a Master Controller
gcloud compute instances create controller \
  --async \
  --boot-disk-size 200GB \
  --can-ip-forward \
  --image-family ubuntu-2204-lts \
  --image-project ubuntu-os-cloud \
  --machine-type n1-standard-2 \
  --private-network-ip 10.240.0.11 \
  --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
  --subnet k8s-training-nodes \
  --zone us-central1-f \
  --tags k8s-training,controller

## Create workers - 3 nodes
for i in 0 1 2; do
  gcloud compute instances create worker-${i} \
  --async \
  --boot-disk-size 200GB \
  --can-ip-forward \
  --image-family ubuntu-2204-lts \
  --image-project ubuntu-os-cloud \
  --machine-type n1-standard-2 \
  --private-network-ip 10.240.0.2${i} \
  --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
  --subnet k8s-training-nodes \
  --zone us-central1-f \
  --tags k8s-training,worker
done
