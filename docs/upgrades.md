# Upgrades

## Upgrading Talos Linux

As well as the Kubernetes version, the Talos Linux version should also be upgraded to keep the cluster secure and up to date.

As the Talos machine configuration specification can change between versions, it is recommended to always upgrade one minor version at a time, such as from `1.10.x` to `1.10.X`, then to `1.11.X` and then to `1.12.X` where `x` is an arbitrary patch version and `X` is the highest supported patch version for that minor version. This is the only way that Talos guarantees that it will handle these configuration changes for you.

In order to maintain Kubernetes API compatibility between all of the nodes in the cluster, the **control planes nodes should always be upgraded before the worker nodes**.

To upgrade your Talos nodes, you simply need to provide the `talosctl upgrade` command with a nodes you want to upgrade and an installer image at the appropriate version. The following command will update it to `1.13.0` for example. You can provide the upgrade command with a comma-separated list of nodes which will all be updated in parallel, but for such a small cluster as this with only four nodes, it generally makes sense to do them one at a time. In fact, as the cluster only has two control plane nodes, you will be unable to by default even upgrade one of them at a time as it will complain that `etcd member count(2) is insufficient to maintain quorum if upgrade commences`. To get around this, you need to provide the `--force` flag for the control plane nodes which will bypass these etcd checks. The `talosctl upgrade --help` output advises that there is a risk of data loss by doing this, but unfortunately there is no real alternative in our case.

As the worker nodes are very memory constrained, the upgrade may appear to work, but no actual update gets performed and the node stays on the old version. This happens as Talos downloads the entire installer image into memory and extracts the file system from there which it is unable to do. The solution here is to pass the `--stage` flag to the `upgrade` command so that the upgrade is staged and then performed after the reboot.

The image supplied via the `--image` flag needs to contain the schematic ID that was used when the cluster was first created so that it is upgraded with the same configuration. See this project's main README.md for more information about the schematic ID. Alternatively, if you wish to modify the installation image, for example to add or remove extensions, then you can generate a new **schematic ID** via the [Talos Image Facotry](https://factory.talos.dev/) and use that for the upgrade instead.

The `upgrade` command will _cordon_ and _drain_ each node before it performs the upgrade. If this might be a problem for your workloads, then you should be sure to manually move any sensitive workloads yourself first.

```bash
export TALOS_NODE="10.0.1.2"
# Or multiple nodes comma-separated.
export TALOS_NODE="10.0.1.12,10.0.1.13"

export TALOS_SCHEMATIC_ID="613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245"
export TALSO_NEW_VERSION="1.13.9"

# First, for the control plane nodes, use the --force flag to bypass the
# etcd quorum check.
talosctl upgrade \
    --nodes "${TALOS_NODE}" \
    --image "factory.talos.dev/installer/${TALOS_SCHEMATIC_ID}:v${TALOS_NEW_VERSION}" \
    --force

# Secondly, for worker nodes, use the --stage flag to stage the upgrade first
# to avoid any out of memory issues during the upgrade.
talosctl upgrade \
    --nodes "${TALOS_NODE}" \
    --image "factory.talos.dev/installer/${TALOS_SCHEMATIC_ID}:v${TALOS_NEW_VERSION}" \
    --stage

# If the upgrade fails or you need to roll back for any other reason, then this
# can be done as follows:
talosctl rollback --nodes "${TALOS_NODE}"
```

After a few minutes, your node should be back up and running with the new Talos version which you can validate with the following two commands:

```bash
talosctl version --nodes "${TALOS_NODE}"

# This outputs the given node's current world view of the cluster.
talosctl get members --nodes "${TALOS_NODE}"

# This only works on control plane nodes.
talosctl health --nodes "${TALOS_NODE}"
```

### A Note About Node Names

You may find that after upgrading your cluster for the first time, the node names have changed from something like `control-plane-N` or `worker-N` to something like `talos-abc-def` like this:

```bash
kubectl get nodes 
# NAME            STATUS                        ROLES           AGE   VERSION
# talos-7b4-nil   Ready                         control-plane   95m   v1.35.2
# talos-i5z-5k2   Ready                         control-plane   78m   v1.35.2
# worker-0        NotReady,SchedulingDisabled   <none>          13d   v1.35.2
# worker-1        NotReady,SchedulingDisabled   <none>          13d   v1.35.2
# ...
```

This is because when the cluster is first bootstrapped, the nodes may inherit their hostnames from the cloud provider's metadata instead of using an auto-generated stable hostname as defined by the machine config. In this case, you can simply remove the old nodes which are in `NotReady` state from the cluster as follows and the new hostnames should be persisted through all future upgrades.

```bash
kubectl delete nodes control-plane-0 control-plane-1
```

## Upgrading Kubernetes

As per the [Talos Linux documentation](https://docs.siderolabs.com/kubernetes-guides/advanced-guides/upgrading-kubernetes), the Kubernetes version of your Talos cluster can easily be upgraded using the `talosctl upgrade-k8s` subcommand.

Each Talos minor version supports a specific range of Kubernetes minor versions, so depending on which minor version of Talos your cluster is running, you can only upgrade as far as the maximum supported Kubernetes minor version. If you wish to upgrade beyond that maximum supported Kubernetes version, then you must upgrade your Talos cluster version first. See the [support matrix](https://docs.siderolabs.com/talos/v1.13/getting-started/support-matrix) to see which Kubernetes versions your Talos version supports (be sure to select your Talos version from the drop-down). You can see the available Kubernetes versions on their [release page](https://kubernetes.io/releases/).

Unlike the `talosctl upgrade` subcommand which targets and upgrades a specific node in the cluster, the `upgrade-k8s` subcommand is a cluster-wide command and will upgrade the control plane components and kubelets across all nodes in a single CLI call. The node specified by the `--nodes` flag is a control plane node from which to run the Kubernetes upgrade.

When running the `upgrade-k8s` subcommand, it may fail with a message saying something like `compatibility check failed on node "10.0.1.2": compatibility with version 1.13.9 is not supported`. this happens when your client version is too low. For instance if the cluster is running Talos version `1.13.x`, but your client is still version `1.12.x`. 

The `--dry-run` flag can be used to test the upgrade without applying it and see exactly what changes would be made.

```bash
talosctl upgrade-k8s --nodes 10.0.1.2 --to 1.35.8 --dry-run

talosctl upgrade-k8s --nodes 10.0.1.2 --to 1.35.8

kubectl get nodes -o wide
```

