# Storage

[Longhorn](https://longhorn.io/) is a "cloud native distributed block storage for Kubernetes". Essentially, it allows you to combine the disks from each Node in the cluster into a single, distributed pool from which PersistentVolumes can be dynamically provisioned. It even comes with a web interface for managing everything.

It's worth noting that Longhorn is quite resource intensive and can cause a lot of issues when run on the two small workers nodes in the cluster, including grinding them to a complete stop. Ideally, try to use an external storage solution if you can.

## Longhorn Installation

Lognhorn can either be installed by applying the raw YAML manifests from Github:

```sh
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.12.1/deploy/longhorn.yaml
```

Alternatively, you can install Longhorn via Helm:

```sh
helm repo add longhorn https://charts.longhorn.io
helm repo update
kubectl create namespace longhorn-system
helm install longhorn longhorn/longhorn --namespace longhorn-system
```

Additionally, for both methods you have to remove local-path as default provisioner and set Longhorn as default:

```sh
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

Check the Longhorn `storageclass`:

```sh
kubectl get storageclass
```

After some minutes, all pods are in the running state and you can connect to the Longhorn UI by forwarding the port to your machine:

```sh
kubectl port-forward deployment/longhorn-ui 8000:8000 -n longhorn-system
```

Use this URL to access the interface: [http://127.0.0.1:8000](http://127.0.0.1:8000).

