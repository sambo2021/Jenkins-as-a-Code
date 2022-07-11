#! /bin/bash 
if [[ ! -f "./Minikube-Infra/TF_key.pem" ]]; then
    # creating empty key and inventory
    touch ./Minikube-Infra/TF_key.pem
    # building minikube cluster locally and using its local exec 
    # to set ec2 ip to inventory in ../Ansible-Credentials/inventory and kubernetes provider in ../Kubernetes-Resources/main.tf
    cd ./Minikube-Infra
    terraform init
    terraform apply -auto-approve

fi

