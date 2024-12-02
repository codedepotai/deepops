#! /bin/bash

mkdir user_keys
pushd user_keys

ADMIN_CONFIG=admin-user.kubeconfig
ADMIN_KEY=admin-user.key
ADMIN_CSR=admin-user.csr
ADMIN_CRT=admin-user.crt
source ../scripts/ai/ai_vars.sh

# Create user key and certificate
openssl genrsa -out $ADMIN_KEY 2048

openssl req -new -key $ADMIN_KEY -out $ADMIN_CSR -subj "/CN=admin-user/O=system:masters"

openssl x509 -req -in $ADMIN_CSR \
    -CA /etc/kubernetes/pki/ca.crt \
    -CAkey /etc/kubernetes/pki/ca.key \
    -CAcreateserial \
    -out $ADMIN_CRT \
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
    --kubeconfig=$ADMIN_CONFIG

kubectl config set-credentials admin-user \
    --client-certificate=$ADMIN_CRT \
    --client-key=$ADMIN_KEY \
    --kubeconfig=$ADMIN_CONFIG

kubectl config set-context admin-user-context \
    --cluster=$CODEDEPOT_CLUSTER_NAME \
    --user=admin-user \
    --kubeconfig=$ADMIN_CONFIG

cp $ADMIN_CONFIG $HOME/.kube/config.admin

popd