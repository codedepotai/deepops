import os 
import sys
def ansible_inventory(self, host: str, workers: list[str]) -> str:
    # mgmt01  ansible_host=192.18.138.177
    # gpu01   ansible_host=146.235.207.25

    with open(os.path.join('scripts', 'ai', 'config', 'inventory.base'), 'r') as f:
        base = f.read()

    host_nodes = [f"mgmt{id:03d}" for id, _ in enumerate([host])]
    worker_nodes = [f"wrkr{id:03d}" for id, _ in enumerate(workers)]

    host_alias = [f"{node} ansible_host={ip}" for node,
                    ip in zip(host_nodes, [host])]
    worker_alias = [f"{node} ansible_host={ip}" for node,
                    ip in zip(worker_nodes, workers)]

    host_nodes_str = "\n".join(host_nodes)
    host_alias_str = "\n".join(host_alias)
    worker_nodes_str = "\n".join(worker_nodes)
    worker_alias_str = "\n".join(worker_alias)

    return (
        base.replace("%%MGMT_NODES%%", host_nodes_str)
            .replace("%%MGMT_ALIAS%%", host_alias_str)
            .replace("%%WORKER_NODES%%", worker_nodes_str)
            .replace("%%WORKER_ALIAS%%", worker_alias_str)
    )


if __name__ == "__main__":
    out_file = sys.argv[1]
    host = os.environ['CODEDEPOT_CLUSTER_HOST']
    workers = os.environ['CODEDEPOT_CLUSTER_WORKERS'].split(',')
    with open(out_file, 'w') as f:
        f.write(ansible_inventory(host, workers))
