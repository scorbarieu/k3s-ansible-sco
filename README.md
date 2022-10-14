# Build a Kubernetes cluster using k3s via Ansible

Author: <https://github.com/itwars>

## K3s Ansible Playbook

Build a Kubernetes cluster using Ansible with k3s. The goal is easily install a Kubernetes cluster on machines running:

- [X] Debian
- [X] Ubuntu
- [X] CentOS
- [X] Rocky

on processor architecture:

- [X] x64
- [X] arm64
- [X] armhf

## System requirements

### ansible install
Deployment environment must have Ansible 2.12.2+

```bash
sudo dnf -y install ansible-core.x86_64
```

You must install the following modules in one single command:
```bash
ansible-galaxy install -r ./collections/requirements.yml
```

or separate commands:
for SElinux: ansible-galaxy collection install ansible.posix
for modprobe: ansible-galaxy collection install community.general

Master and nodes must have passwordless SSH access

## Usage

First create a new directory based on the `sample` directory within the `inventory` directory:

```bash
cp -R inventory/sample inventory/my-cluster
```

Second, edit `inventory/my-cluster/hosts.ini` to match the system information gathered above. For example:

```bash
[master]
192.16.35.12

[node]
192.16.35.[10:11]

[k3s_cluster:children]
master
node
```

If needed, you can also edit `inventory/my-cluster/group_vars/all.yml` to match your environment.

Start provisioning of the cluster using the following command:

```bash
ansible-playbook site.yml -i inventory/my-cluster/hosts.ini
```

## Kubeconfig

To get access to your **Kubernetes** cluster from your local machine if you DON'T already HAVE a config file just use

```bash
scp debian@master_ip:~/.kube/config ~/.kube/config
```
## Post installs

### 
```bash
sudo dnf install bash-completion
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
```

### check nodes
```
kubectl get nodes

NAME                        STATUS   ROLES                       AGE     VERSION
d2-4-gra5-pub-m-nifi-k3s1   Ready    control-plane,etcd,master   4d13h   v1.22.3+k3s1
d2-4-gra5-pub-m-nifi-k3s2   Ready    control-plane,etcd,master   4d9h    v1.22.3+k3s1
d2-4-gra5-pub-m-nifi-k3s3   Ready    control-plane,etcd,master   4d9h    v1.22.3+k3s1
```
### Check Network and DNS resolution
https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/


### install helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```
### install longhorn block storage
#### pre-req for longhorn storage for K3s

```bash
sudo dnf -y  install iscsi-initiator-utils
sudo dnf install nfs-utils -y
```
TODO enable Mount propagation on containerd
```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
#then set up the UI access
USER=<USERNAME_HERE>; PASSWORD=<PASSWORD_HERE>; echo "${USER}:$(openssl passwd -stdin -apr1 <<< ${PASSWORD})" >> auth
kubectl -n longhorn-system create secret generic basic-auth --from-file=auth
kubectl -n longhorn-system apply -f appsamples/longhorningress.yaml
# EXAMPLE create a storage class
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/master/examples/storageclass.yaml
# EXAMPLE create a PV and pod (not WORKING on vagrant rocky8...yet... volome created but failed to attach to container)
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/master/examples/pod_with_pvc.yaml

```

## OPTIONNAL INSTALL/EXAMPLES

### install Nifi on K8s
Source
https://konpyutaika.github.io/nifikop/docs/2_deploy_nifikop/1_quick_start
#### zookeeper

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami

helm install zookeeper bitnami/zookeeper     --set resources.requests.memory=256Mi     --set resources.requests.cpu=250m     --set resources.limits.memory=256Mi     --set resources.limits.cpu=250m     --set global.storageClass=local-path     --set networkPolicy.enabled=true     --set replicaCount=3 --namespace nifi --create-namespace
```

#### certmanager
```bash
# If you have installed the CRDs manually instead of with the `--set installCRDs=true` option added to your Helm install command, you should upgrade your CRD resources before upgrading the Helm chart:
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.7.1 \
  --set installCRDs=true
```
#### Nifi Kop 

It is the K8s operator that will make it possible to deploy state of the art Nifi cluster on demand with almost no worries (PaaS)

```bash
helm install nifikop \
    oci://ghcr.io/konpyutaika/helm-charts/nifikop \
    --namespace=nifikop \
    --version 0.14.1 \
    --set image.tag=v0.14.1-release \
    --set resources.requests.memory=256Mi \
    --set resources.requests.cpu=250m \
    --set resources.limits.memory=256Mi \
    --set resources.limits.cpu=250m \
    --set namespaces={"nifikop"}
```

#### Nifi simple cluster
```bash
#get a sample deployment file:

curl -o simplenificluster.yaml https://raw.githubusercontent.com/konpyutaika/nifikop/master/config/samples/simplenificluster.yaml
```

change this line in the file
storageClassName: "local-path"

