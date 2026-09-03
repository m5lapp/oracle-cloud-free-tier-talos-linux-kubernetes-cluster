# Monitoring and Observability

## kube-prometheus-stack

The [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) is an easy way to install [Prometheus](https://prometheus.io/), [Grafana](http://grafana.com/) and a number of other useful monitoring and observability applications into the cluster.

### Installation

The kube-prometheus-stack can easily be installed via its Helm chart. In order to make this a bit more repeatable, we can create a [HelmChart resource](https://docs.k3s.io/helm#using-the-helm-controller) which we can deploy into the cluster; this will then do the installation as required with the given values configuration. The full list of available values are well documented in the chart's [values.yaml file](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml). See the `services/kube-prometheus-stack.yaml` as an example of the HelmChart resource to get you started.

As the cluster is quite underpowered it is a good idea to not enable any components that are not required. Additionally, ensure that the main components are provisioned on the more powerful control plane nodes using node selectors. Even then, it can take a good while for all the components to come up cleanly.

In order to persist metric data, you will probably want to [install Longhorn](storage.md) first to pool all of the nodes' disk into usable block storage.

Prometheus will scrape metrics from all its targets according to the  `prometheus.prometheusSpec.scrapeInterval` value and will store all the raw metrics it scrapes for as long as the `prometheus.prometheusSpec.retention` is set for. This means that its memory usage will climb over time until the retention period is reached and the expired metrics are deleted. It is therefore important to configure these values carefully and also set suitable resource limits to prevent the Pod from causing problems for other Pods on the node.

The following are example values for a reasonable set up to run on the OCI cluster and can be provided to the [kube-prometheus-stack Helm chart](https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack). These values target version `54.2.2` specifically.

```yaml
namespaceOverride: monitoring
alertmanager:
  alertmanagerSpec:
    nodeSelector:
      node-role.kubernetes.io/control-plane: "true"
    resources:
      limits:
        memory: 48Mi
      requests:
        memory: 48Mi
    retention: 48h
    storage:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 50Mi
          storageClassName: longhorn
grafana:
  adminPassword: prom-operator
  nodeSelector:
    node-role.kubernetes.io/control-plane: "true"
  resources:
    limits:
      memory: 768Mi
    requests:
      memory: 512Mi
nodeExporter:
  operatingSystems:
    darwin:
      enabled: false
prometheus:
  prometheusSpec:
    nodeSelector:
      node-role.kubernetes.io/control-plane: "true"
    resources:
      limits:
        memory: 2Gi
      requests:
        memory: 1.5Gi
    retention: 2d
    retentionSize: 4500MB
    scrapeInterval: 20s
    scrapeTimeout: 5s
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 5Gi
          storageClassName: longhorn
```

You can monitor the installation process by inspecting the helm-install Pod and its logs in the kube-system namespace as follows. If there are any problems, simply fix them in the YAML file and then run the apply command again (you may need to delete the file from the cluster first in some cases).

```bash
kubectl get pods -n kube-system -l batch.kubernetes.io/job-name=helm-install-kube-prometheus-stack
kubectl logs -n kube-system -l batch.kubernetes.io/job-name=helm-install-kube-prometheus-stack -f
```

The Prometheus, Grafana and AlertManager web interfaces can be accessed at [http://localhost:8080](http://localhost:8080) by port-forwarding to the appropriate service as follows (the default username and password for Grafana is `admin`/`prom-operator` unless configured otherwise):

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 8080:9093
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 8080:8080
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 8080:9090
```

