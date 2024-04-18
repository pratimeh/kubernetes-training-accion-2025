#!/bin/bash
gcloud compute networks create budget-k8s-training --subnet-mode custom

gcloud compute networks subnets create budget-k8s-nodes \
--network budget-k8s-training \
--range 10.240.0.0/24
##region us-central1

gcloud compute firewall-rules create budget-k8s-training-allow-internal \
--allow tcp,udp,icmp,ipip \
--network budget-k8s-training \
--source-ranges 10.240.0.0/24

gcloud compute firewall-rules create budget-k8s-training-allow-external \
--allow tcp:22,tcp:6443,icmp \
--network budget-k8s-training \
--source-ranges 0.0.0.0/0

gcloud compute instances create budget-controller \
  --async \
  --boot-disk-size 200GB \
  --can-ip-forward \
  --image-family ubuntu-2204-lts \
  --image-project ubuntu-os-cloud \
  --machine-type e2-medium \
  --private-network-ip 10.240.0.31 \
  --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
  --subnet budget-k8s-nodes \
  --zone us-central1-f \
  --tags budget-k8s-training,controller

for i in 0 1 2; do
  gcloud compute instances create budget-worker-${i} \
  --async \
  --boot-disk-size 200GB \
  --can-ip-forward \
  --image-family ubuntu-2204-lts \
  --image-project ubuntu-os-cloud \
  --machine-type e2-medium \
  --private-network-ip 10.240.0.4${i} \
  --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
  --subnet budget-k8s-nodes \
  --zone us-central1-f \
  --tags budget-k8s-training,worker
done
