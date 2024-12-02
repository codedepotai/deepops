#! /bin/bash

set -x

source scripts/ai/ai_vars.sh

# Get absolute path for script and root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOT_DIR="${SCRIPT_DIR}/../.."

FRONTEND_YAML="${SCRIPT_DIR}/ai/frontend.yaml"
if [ ! -f "${frontend_yaml}" ]; then
    echo "Can't find frontend.yaml in ${SCRIPT_DIR}/ai"
    exit 1
fi

kubectl create namespace ${FRONTEND_NAMESPACE}
kubectl apply -n ${FRONTEND_NAMESPACE} -f "${FRONTEND_YAML}"

