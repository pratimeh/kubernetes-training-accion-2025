## 🔹 PREPARATION ON GCP — Infrastructure Provisioning

### STEP 1: Create VPC, Subnet, IG, FW Rules

#### 1. Create a VPC

```bash
gcloud compute networks create k8s-vpc --subnet-mode=custom
```

#### 2. Create a Subnet with static IP range

```bash
gcloud compute networks subnets create k8s-subnet \
  --network=k8s-vpc \
  --region=us-central1 \
  --range=10.240.0.0/24
```

#### 3. Enable internet connectivity (Cloud NAT)

```bash
gcloud compute routers create k8s-router \
  --network=k8s-vpc \
  --region=us-central1

gcloud compute routers nats create k8s-nat \
  --router=k8s-router \
  --region=us-central1 \
  --auto-allocate-nat-external-ips \
  --nat-all-subnet-ip-ranges
```

#### 4. Allow SSH and Kubernetes API access

```bash
gcloud compute firewall-rules create k8s-fw-internal \
  --network=k8s-vpc \
  --allow tcp,udp,icmp \
  --source-ranges=10.240.0.0/24

gcloud compute firewall-rules create k8s-fw-ssh \
  --network=k8s-vpc \
  --allow tcp:22 \
  --source-ranges=0.0.0.0/0

gcloud compute firewall-rules create k8s-fw-k8s-api \
  --network=k8s-vpc \
  --allow tcp:6443 \
  --source-ranges=0.0.0.0/0
```

---

### STEP 2: Create the VMs (Ubuntu 22.04)

#### 1. Create 2 master nodes

```bash
for i in 1 2; do
  gcloud compute instances create master-${i} \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --subnet=k8s-subnet \
    --private-network-ip=10.240.0.1${i} \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=50GB \
    --tags=kubernetes \
    --can-ip-forward \
    --scopes=https://www.googleapis.com/auth/cloud-platform
  done
```

#### 2. Create 1 worker nodes

```bash
  gcloud compute instances create worker-1} \
    --zone=us-central1-a \
    --machine-type=e2-medium \
    --subnet=k8s-subnet \
    --private-network-ip=10.240.0.21 \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=50GB \
    --tags=kubernetes \
    --can-ip-forward \
    --scopes=https://www.googleapis.com/auth/cloud-platform
```

---

# 🧩 Kubernetes HA Setup with NGINX TCP Load Balancer



## 🔹 Step 2: Install NGINX with Stream (TCP) Support



SSH into the **NGINX Load Balancer VM** and install NGINX:



```

sudo apt update

sudo apt install -y nginx

Enable TCP stream module by editing the NGINX configuration:

sudo nano /etc/nginx/nginx.conf

Add the following block outside the http {} section, usually at the top:



nginx

Copy

Edit

stream {

    upstream kube_masters {

        server 10.240.0.11:6443;  # master-1

        server 10.240.0.12:6443;  # master-2

    }



    server {

        listen 6443;

        proxy_pass kube_masters;

    }

}

Save and restart NGINX:

sudo nginx -t

sudo systemctl restart nginx

🔹 Step 3: Open Port 6443 on NGINX VM

Create a firewall rule to allow external access to the Kubernetes API via NGINX:

gcloud compute firewall-rules create nginx-lb-k8s-api \

  --network=k8s-vpc \

  --allow tcp:6443 \

  --target-tags=nginx-lb \

  --source-ranges=0.0.0.0/0

🔹 Step 4: Use NGINX IP in kubeadm

Get the internal IP of your NGINX Load Balancer:

gcloud compute instances describe nginx-lb \

  --zone=us-central1-a \

  --format="get(networkInterfaces[0].networkIP)"

Use this IP (e.g. 10.240.0.100) as the --control-plane-endpoint when initializing the first master:

kubeadm init \

  --control-plane-endpoint "10.240.0.100:6443" \

  --upload-certs \

  --pod-network-cidr=10.244.0.0/16

✅ Make sure 10.240.0.100 is the internal IP of the NGINX VM.



🔹 Step 5: Join Additional Masters and Workers

All kubeadm join commands for the second master and all worker nodes should also point to the NGINX IP as the --control-plane-endpoint.



✅ Validation

On any node, validate the connection to the Kubernetes API via NGINX:

curl -k https://10.240.0.100:6443

kubectl get nodes

 or

Kill One Master and Retest
SSH into a master node (e.g. master-1) and stop the kube-apiserver:

sudo systemctl stop kubelet
Retest the API again via load balancer:

curl -k https://<NGINX_LB_IP>:6443/version
✅ If the output still returns successfully, your NGINX is correctly failing over to the second master.

### STEP 3: NODE PREPARATION (BOTH MASTER & WORKER)

SSH into each node and execute:

#### 1. System prep

```bash
sudo apt update && sudo apt install -y curl apt-transport-https ca-certificates gnupg lsb-release software-properties-common

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/99-k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

#### 2. Install and configure containerd

```bash
sudo apt install -y containerd

sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

#### 3. Add Kubernetes APT repo (v1.30)

```bash
sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

#### 4. Install Kubernetes tools

```bash
sudo apt update
sudo apt install -y kubeadm kubelet kubectl
sudo apt-mark hold kubeadm kubelet kubectl
```

---

### STEP 4: MASTER-1 INITIALIZATION

```bash
sudo kubeadm init \
  --control-plane-endpoint "10.240.0.11:6443" \
  --pod-network-cidr=10.244.0.0/16 \
  --upload-certs

mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

---

### STEP 5: Install Pod Network (Calico)

```bash
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/calico.yaml
```

### 👷 JOIN WORKER NODES

Use the join command provided by master-1 on both worker nodes.

---

### STEP 6: VALIDATE

```bash
kubectl get nodes
kubectl get pods -A
```

Ensure all nodes are in `Ready` state and CNI pods are running.

---

## 🔻 Delete Kubernetes Network Infrastructure on GCP

### STEP 1. Delete Compute Instances

```bash
for i in 1 2; do
  gcloud compute instances delete master-${i} --zone=us-central1-a --quiet
done

for i in 1 2; do
  gcloud compute instances delete worker-${i} --zone=us-central1-a --quiet
done
```

### ✅ STEP 2. Delete VPC, Firewall, NAT, Subnet and Networks

#### 1️⃣ Delete Firewall Rules

```bash
gcloud compute firewall-rules delete k8s-fw-internal --quiet
gcloud compute firewall-rules delete k8s-fw-ssh --quiet
gcloud compute firewall-rules delete k8s-fw-k8s-api --quiet
```

#### 2️⃣ Delete Cloud NAT and Router

```bash
gcloud compute routers nats delete k8s-nat \
  --router=k8s-router \
  --region=us-central1 \
  --quiet

gcloud compute routers delete k8s-router \
  --region=us-central1 \
  --quiet
```

#### 3️⃣ Delete Subnet

```bash
gcloud cocmpute networks subnets delete k8s-subnet \
  --region=us-central1 \
  --quiet
```



#### 4️⃣ Delete VPC Network

```bash
gcloud compute networks delete k8s-vpc --quiet
```




