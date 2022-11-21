# Build a Kubernetes cluster using k3s via Ansible

Author: <https://github.com/itwars>
Adapted by : <https://github.com/scorbarieu>  for Rocky, HA control pane, postinstall scripts, app samples

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

## Kubectl (OTIONNAL)

You can get access to your **Kubernetes** cluster from any of the nodes but also from your local machine:

First download kubectl :
On Linux:
```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.25.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
cd
mkdir .kube
scp rocky@master_ip:~/.kube/config ~/.kube/config
# check
kubectl cluster-info

```

On Windows use MobaXterm or any unix friendly environement (WSL or such)

```bash
KUBECTL_VERSION=v1.24.0
curl -L "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/windows/amd64/kubectl.exe" -o /drives/c/Users/corbarieus/AppData/Local/Microsoft/WindowsApps/kubectl.exe
# copy the file in your home dir
cd
mkdir .kube
scp rocky@master_ip:~/.kube/config ~/.kube/config
# check
kubectl cluster-info
```

or Powershell

```powershell
$KUBECTL_VERSION = v1.24.0
Invoke-WebRequest `
 -Uri https://dl.k8s.io/release/$KUBECTL_VERSION/bin/windows/amd64/kubectl.exe `
mv kubectl.exe C:\Users\corbarieus\AppData\Local\Microsoft\WindowsApps\
scp rocky@master_ip:~/.kube/config ~/.kube/config
# check
kubectl cluster-info
```


### kubectl bash auto completion (RECOMMENDED)
```bash
sudo dnf install bash-completion
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
```
on Windows:
```powershell
 mkdir C:\Users\corbarieus\Documents\WindowsPowerShell
 kubectl completion powershell >> $PROFILE
 ```

 
## Post installs

Feeling Lazy ? Run this script (but take a look below of what it does)
```bash
scripts/postinstall.sh
```

### check nodes (RECOMMENDED)
```
kubectl get nodes

NAME                        STATUS   ROLES                       AGE     VERSION
d2-4-gra5-pub-m-nifi-k3s1   Ready    control-plane,etcd,master   4d13h   v1.22.3+k3s1
d2-4-gra5-pub-m-nifi-k3s2   Ready    control-plane,etcd,master   4d9h    v1.22.3+k3s1
d2-4-gra5-pub-m-nifi-k3s3   Ready    control-plane,etcd,master   4d9h    v1.22.3+k3s1
```
### Check Network and DNS resolution (OTIONNAL)
https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/


### install helm (RECOMMENDED)
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### helm auto completion (RECOMMENDED)
```bash
sudo dnf install bash-completion
helm completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
```
on Windows:
```powershell
 mkdir C:\Users\corbarieus\Documents\WindowsPowerShell
 helm completion powershell >> $PROFILE
 ```

#### certmanager (RECOMMENDED)
This is used by lots of software to manage certificate generation/rotation automatically in deployments

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

### install rancher (RECOMMENDED)
```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.my.org \
  --set bootstrapPassword=admin
```

### install longhorn block storage (RECOMMENDED)
#### pre-req for longhorn storage for K3s

```bash
# pre-req for longhorn storage for K3s
sudo dnf -y  install iscsi-initiator-utils
sudo systemctl enable iscsid
sudo systemctl start iscsid
sudo dnf install nfs-utils -y
```
TODO enable Mount propagation on containerd
```bash

#check pre-req
sudo dnf install jq -y # required by the script
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.3.1/scripts/environment_check.sh | bash
```
#### Install longhorn storage for K3s

```bash
# install longhorn
# kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
# or with helm
helm repo add longhorn https://charts.longhorn.io
helm repo update
DATAPATH="/data/longhorn"
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --set defaultSettings.defaultDataPath=${DATAPATH}
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

#### create custom storage class with WaitForFirstConsumer bind mode
```bash
kubectl create -f appsamples/storageclass.yaml
```

#### zookeeper

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install zookeeper bitnami/zookeeper     --set resources.requests.memory=256Mi     --set resources.requests.cpu=250m     --set resources.limits.memory=256Mi     --set resources.limits.cpu=250m     --set global.storageClass=longhorn-wait     --set networkPolicy.enabled=true     --set replicaCount=3 --namespace nifi --create-namespace
```


#### Nifi Kop 

It is the K8s operator that will make it possible to deploy state of the art Nifi cluster on demand with almost no worries (PaaS)
reference : https://github.com/konpyutaika/nifiko
https://konpyutaika.github.io/nifikop

```bash
helm install nifikop oci://ghcr.io/konpyutaika/helm-charts/nifikop --namespace=nifi --version 0.15.0 --set image.tag=v0.15.0-release --set resources.requests.memory=256Mi --set resources.requests.cpu=250m --set resources.limits.memory=256Mi --set resources.limits.cpu=250m --set namespaces={"nifi"}
```

#### Nifi simple cluster
```bash
kubectl create -f appsamples/simplenificluster.yaml -n nifi
```
