#! /bin/bash

source scripts/ai/ai_vars.sh

# Create user key and certificate
openssl genrsa -out admin-user.key 2048

openssl req -new -key admin-user.key -out admin-user.csr -subj "/CN=admin-user/O=system:masters"

openssl x509 -req -in admin-user.csr \
    -CA /etc/kubernetes/pki/ca.crt \
    -CAkey /etc/kubernetes/pki/ca.key \
    -CAcreateserial \
    -out admin-user.crt \
    -days 365

# Update certificate with CODEDEPOT_API_HOST_IP
sudo rm /etc/kubernetes/pki/apiserver.crt
sudo rm /etc/kubernetes/pki/apiserver.key

sudo kubeadm init phase certs apiserver --apiserver-cert-extra-sans $CODEDEPOT_API_HOST_IP

# Creates cubeconfig for admin user -> WHAT DOES THIS DO?
kubectl config set-cluster $CODEDEPOT_CLUSTER_NAME \
    --server=https://$CODEDEPOT_API_HOST_IP:6443 \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --kubeconfig=admin-user.kubeconfig

kubectl config set-credentials admin-user \
    --client-certificate=admin-user.crt \
    --client-key=admin-user.key \
    --kubeconfig=admin-user.kubeconfig

kubectl config set-context admin-user-context \
    --cluster=$CODEDEPOT_CLUSTER_NAME \
    --user=admin-user \
    --kubeconfig=admin-user.kubeconfig

kubectl config use-context admin-user-context --kubeconfig=admin-user.kubeconfig

