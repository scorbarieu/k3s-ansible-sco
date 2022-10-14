#!/bin/bash

CERTMANAGER_VERSION=v1.7.1
ADMINPASSWORD=TestMeteo#2022
LONGHORNUIUSER=longhorn; 
LONGHORNUIPASSWORD=$ADMINPASSWORD;


echo "checking nodes"
kubectl get nodes

echo "installing helm"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "Install certmanager"
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager   --namespace cert-manager   --create-namespace   --version $CERTMANAGER_VERSION   --set installCRDs=true

echo "install rancher"
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
kubectl create namespace cattle-system
helm install rancher rancher-stable/rancher   --namespace cattle-system   --set hostname=rancher.my.org   --set bootstrapPassword=$ADMINPASSWORD

echo "installing longhorn block storage for PV"
sudo dnf -y  install iscsi-initiator-utils
sudo dnf install nfs-utils -y
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
#then set up the UI access
echo "${LONGHORNUIUSER}:$(openssl passwd -stdin -apr1 <<< ${LONGHORNUIPASSWORD})" >> auth
kubectl -n longhorn-system create secret generic basic-auth --from-file=auth
kubectl -n longhorn-system apply -f appsamples/longhorningress.yaml
# EXAMPLE create a storage class
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/master/examples/storageclass.yaml
# EXAMPLE create a PV and pod (not WORKING on vagrant rocky8...yet... volome created but failed to attach to container)
# For some reason the volume fails to attach
kubectl create -f https://raw.githubusercontent.com/longhorn/longhorn/master/examples/pod_with_pvc.yaml
