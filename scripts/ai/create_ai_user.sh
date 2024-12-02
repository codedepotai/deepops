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

# Creates cubeconfig for admin user
kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'


kubectl config set-cluster $CLUSTER_NAME \
    --server=https://<API_SERVER_IP>:6443 \
    --certificate-authority=/etc/kubernetes/pki/ca.crt \
    --embed-certs=true \
    --kubeconfig=admin-user.kubeconfig

kubectl config set-credentials admin-user \
    --client-certificate=admin-user.crt \
    --client-key=admin-user.key \
    --kubeconfig=admin-user.kubeconfig

kubectl config set-context admin-user-context \
    --cluster=$CLUSTER_NAME \
    --user=admin-user \
    --kubeconfig=admin-user.kubeconfig

kubectl config use-context admin-user-context --kubeconfig=admin-user.kubeconfig

