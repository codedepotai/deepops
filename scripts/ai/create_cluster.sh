#! /bin/bash

# Read and strip CODEDEPOT_CLUSTER_PREFIX from the file
ROOT_DIR="/home/ubuntu/${CODEDEPOT_CLUSTER_PREFIX}"  # Root directory of DeepOps
DEEPOPS_ROOT="${ROOT_DIR}/deepops"  # Root directory of DeepOps
CLUSTER_CREATION_LOG="${ROOT_DIR}/${CODEDEPOT_CLUSTER_PREFIX}.log"

# Function to log messages
log() {
    local MESSAGE="$@"
    echo "$(date '+%Y-%m-%d %H:%M:%S') $MESSAGE" | tee -a "$CLUSTER_CREATION_LOG"
}

# Proxy wrapper
as_sudo(){
    cmd="sudo bash -c '$@'"
    eval $cmd >> "$CLUSTER_CREATION_LOG" 2>&1
    if [ $? -ne 0 ]; then
        log "Command $cmd failed"
        echo "Command $cmd failed"
        exit 1
    fi
}

# Function to run a command as a user and log output
as_user() {
    cmd="bash -c '$@'"
    eval $cmd >> "$CLUSTER_CREATION_LOG" 2>&1
    if [ $? -ne 0 ]; then
        log "Command $cmd failed"
        echo "Command $cmd failed"
        exit 1
    fi
}

log "Adding ssh-key to agent"
eval `ssh-agent`
ssh-add ~/.ssh/id_rsa.${CODEDEPOT_CLUSTER_PREFIX}

log "Installing dependencies"
# Configuration

ANSIBLE_VERSION="${ANSIBLE_VERSION:-4.8.0}"     # Ansible version to install
ANSIBLE_TOO_NEW="${ANSIBLE_TOO_NEW:-5.0.0}"    # Ansible version too new
ANSIBLE_LINT_VERSION="${ANSIBLE_LINT_VERSION:-5.4.0}"
CONFIG_DIR="${CONFIG_DIR:-${DEEPOPS_ROOT}/config}"            # Default configuration directory location
JINJA2_VERSION="${JINJA2_VERSION:-2.11.3}"      # Jinja2 required version
JMESPATH_VERSION="${JMESPATH_VERSION:-0.10.0}"    # jmespath pegged version, actual version probably not that crucial
MARKUPSAFE_VERSION="${MARKUPSAFE_VERSION:-1.1.1}"  # MarkupSafe version
PIP="${PIP:-pip3}"                              # Pip binary to use
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3}"    # Python3 path
VENV_DIR="${VENV_DIR:-/opt/deepops/env}"        # Path to python virtual environment to create
DEPS_DEB=(git virtualenv python3-virtualenv sshpass wget)

# Install dependencies
as_sudo "apt-get -q update"
as_sudo "apt-get -yq install ${DEPS_DEB[@]}"

as_sudo "mkdir -p ${VENV_DIR}"
as_sudo "chown -R $(id -u):$(id -g) ${VENV_DIR}"
deactivate nondestructive &> /dev/null
virtualenv -q --python="${PYTHON_BIN}" "${VENV_DIR}"
. "${VENV_DIR}/bin/activate"
as_user "${PIP} install -q --upgrade pip"
as_user "${PIP} install -q --upgrade \
    ansible==${ANSIBLE_VERSION} \
    ansible-lint==${ANSIBLE_LINT_VERSION} \
    Jinja2==${JINJA2_VERSION} \
    netaddr \
    ruamel.yaml \
    PyMySQL \
    paramiko \
    jmespath==${JMESPATH_VERSION} \
    MarkupSafe==${MARKUPSAFE_VERSION} \
    selinux"

cp -rfp "${DEEPOPS_ROOT}/config.example" "${CONFIG_DIR}"

log "Updating Ansible Galaxy roles..."
initial_dir="$(pwd)"
roles_path="${DEEPOPS_ROOT}/roles/galaxy"
collections_path="${DEEPOPS_ROOT}/collections"

cd "${DEEPOPS_ROOT}"
as_user ansible-galaxy collection install -p "${collections_path}" --force -r "roles/requirements.yml" >/dev/null
as_user ansible-galaxy role install -p "${roles_path}" --force -r "roles/requirements.yml" >/dev/null

# Install any user-defined config requirements
if [ -d "${CONFIG_DIR}" ] && [ -f "${CONFIG_DIR}/requirement.yml" ] ; then
    cd "${CONFIG_DIR}"
    as_user ansible-galaxy collection install -p "${collections_path}" --force -i -r "requirements.yml" >/dev/null
    as_user ansible-galaxy role install -p "${roles_path}" --force -i -r "requirements.yml" >/dev/null
fi
cd "${initial_dir}"

as_user git submodule update --init

ansible localhost -m lineinfile -a "path=$HOME/.bashrc create=yes mode=0644 backup=yes line='source ${VENV_DIR}/bin/activate'"

# Replace config/inventory and config/group_vars/k8s-cluster.yaml with ../inventory and ../k8s-cluster.yaml
log "Copying inventory and group_vars"
rm config/inventory
rm config/group_vars/k8s-cluster.yml
as_user python script/ai/config.py config/inventory
cp ai/config/k8s-cluster.yml config/group_vars/k8s-cluster.yml
log "Checking ansible with nodes"
as_user ansible all -m raw -a "hostname"
log "Running ansible playbook"
as_user ansible-playbook -l k8s-cluster playbooks/k8s-cluster.yml
log "Checking k8s cluster"
as_user kubectl get nodes
#log "Deploying load balancer"
#as_user ./scripts/k8s/deploy_loadbalancer.sh

log "Deploying kubeflow"
as_user ./scripts/k8s/deploy_kubeflow.sh

#log "Starting Cluster Frontend Service"
# as_user ./scripts/ai/deploy_frontend.sh


log "Cluster setup complete"
