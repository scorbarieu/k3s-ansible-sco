#!/bin/bash

#set -x

SCRIPT_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}"  )" && pwd  )"
## name of the script
SCRIPTNAME=`basename $0 .sh`

echo "USAGE: scripts/postinstall.sh [ project ] will source envproject.sh"
# you must update env.sh accordingly to your needs
echo "sourcing $SCRIPT_HOME/env$1.sh"
source $SCRIPT_HOME/env$1.sh

HasHELM=$(which helm)
if [ -z $HasHELM ]; then
    echo "########################### installing helm ###########################"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    sudo dnf install bash-completion
    helm completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
fi
HasKUBECTL=$(which kubectl)
if [ -z $HasKUBECTL ]; then
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
helm install rancher rancher-stable/rancher --namespace cattle-system --create-namespace --set hostname=$RANCHERDNS   --set bootstrapPassword=$ADMINPASSWORD


echo "########################### installing longhorn block storage for PV ###########################"
echo "########################### checking longhorn pre-requisites ###########################"

sudo dnf install jq -y # required by the script
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.3.1/scripts/environment_check.sh | bash
if [ $? == 0 ]; then
    echo "########################### longhorn pre-requisites OK: proceeding ###########################"

    #kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml
    helm repo add longhorn https://charts.longhorn.io
    helm repo update
    
    helm install longhorn longhorn/longhorn \
    --namespace longhorn-system \
    --create-namespace \
    --set defaultSettings.defaultDataPath=${DATAPATH}
    #then set up the UI access (not REQUIRED as Rancher provide UI access to longhorn )
    # echo "${LONGHORNUIUSER}:$(openssl passwd -stdin -apr1 <<< ${LONGHORNUIPASSWORD})" >> auth
    # kubectl -n longhorn-system create secret generic basic-auth --from-file=auth
    # cat appsamples/longhorningress.yaml | envsubst | kubectl -n longhorn-system apply -f

    # EXAMPLE create a storage class longhorn-wait
    kubectl create -f appsamples/storageclass.yaml
    # EXAMPLE create a PV and pod
    kubectl create -f appsamples/pod_with_pvc.yaml
    echo "########################### checking longhorn is ok by looking if nay deployment below has failed  ###########################"
    kubectl get deployments.apps -n longhorn-system
else
    echo "########################### be sure pre-requistes for longhorn have been installed...skipping ###########################"
fi