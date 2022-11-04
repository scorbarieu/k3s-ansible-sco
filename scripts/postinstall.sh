#!/bin/bash

CERTMANAGER_VERSION=v1.7.1
ADMINPASSWORD=TestMeteo#2022
LONGHORNUIUSER=longhorn; 
LONGHORNUIPASSWORD=$ADMINPASSWORD;
#ADMINUSER=vagrant #requires sudo
CLUSTERADMINUSER=corbarieus
CLUSTERMASTER=nifif31-sidev.meteo.fr



if [ ! -f /usr/local/bin/helm ]; then
    echo "########################### installing helm ###########################"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    sudo dnf install bash-completion
    helm completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
fi
if [ ! -f /usr/local/bin/kubectl ]; then
    echo "########################### install kubectl ###########################"
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.25.0/bin/linux/amd64/kubectl
    chmod +x ./kubectl
    sudo mv ./kubectl /usr/local/bin/kubectl
    mkdir ~/.kube
    sudo dnf install bash-completion
    kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
fi

if [ ! -f ~/.kube/config ]; then
    echo "########################### install kubectl config ###########################"
    scp $CLUSTERADMINUSER@$CLUSTERMASTER:~/.kube/config ~/.kube/config
fi

echo "########################### checking nodes ###########################"
kubectl get nodes

echo "########################### Install certmanager ###########################"
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager   --namespace cert-manager   --create-namespace   --version $CERTMANAGER_VERSION   --set installCRDs=true

echo "########################### install rancher ###########################"
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
kubectl create namespace cattle-system
helm install rancher rancher-stable/rancher   --namespace cattle-system   --set hostname=rancher.poc.meteo.fr   --set bootstrapPassword=$ADMINPASSWORD


echo "########################### installing longhorn block storage for PV ###########################"
echo "########################### checking longhorn pre-requisites ###########################"
sudo dnf install jq -y # required by the script
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.3.1/scripts/environment_check.sh | bash
if [ $? == 0 ]; then
    echo "########################### longhorn pre-requisites OK: proceeding ###########################"

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
    echo "########################### checking longhorn is ok by looking if nay deployment below has failed  ###########################"
    kubectl get deployments.apps -n longhorn-system
else
    echo "########################### be sure pre-requistes for longhorn have been installed...skipping ###########################"
fi