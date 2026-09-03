# Ingress

## Automatic Certificate Creation via Let's Encrypt

For propagating your services, it is strongly recommended to use TLS encryption. It's best to deploy TLS certificates for all services that are reachable via the internet. To fulfill this requirement, you can use [Traefik](https://traefik.io/) for the ingress controller and [`cert-manager`](https://cert-manager.io/) to request, deploy and renew TLS certificates. A more detailed explanation of how to set this up can be found on [sysadmins.co.za](https://sysadmins.co.za/https-using-letsencrypt-and-traefik-with-k3s/).

These instructions assume that you already have some service running in your cluster that you wish to expose.

### Installation and Configuration

Firstly, you need to install Traefik which is best done via the [Helm chart](https://github.com/traefik/traefik-helm-chart). The following Helm values are the key pieces of configuration that you need to supply to work with this project's default OCI load balancer set up. This will allow for HTTP traffic to be received on port 80 (which is useful for proving that you own a specific domain to a TLS certificate issuer using an HTTP challenge) and HTTPS traffic on port 443. If you wish to expose any other ports, then these must be first added to the OCI load balancer; see the main README.md for more information about this.

```yaml
deployment:
  kind: DaemonSet
service:
  enabled: true
  type: NodePort
  spec:
    # Since we are using a Load Balancer that doesn't preserve source IP,
    # 'Cluster' is fine. If this is later changed to preserve the source IP,
    # then this should be set this to 'Local'.
    externalTrafficPolicy: Cluster
ports:
  web:
    port: 8000
    exposedPort: 80
    protocol: TCP
    nodePort: 30080
  websecure:
    port: 8443
    exposedPort: 443
    protocol: TCP
    nodePort: 30443
additionalArguments:
# If Proxy Protocol is enabled on the OCI NLB later, then the client IPs
# will need to be added to the trusted list here.
- "--entrypoints.web.proxyProtocol.trustedIPs=127.0.0.1/32,10.0.0.0/16"
- "--entrypoints.websecure.proxyProtocol.trustedIPs=127.0.0.1/32,10.0.0.0/16"
api:
  dashboard: true
  insecure: false
```

After doing this, Traefik will be running a Pod on every Node in the cluster and be listening for traffic from the OCI load balancer on the given NodePorts.

Secondly, you need to install cert-manager either by Helm using their supplied [Helm chart](https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager), or by [applying YAML files from Github](https://cert-manager.io/docs/installation/kubectl/) as follows:
```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.21.1/cert-manager.yaml
```

Thirdly, add a ClusterIssuer by replacing the placeholder email address in the YAML config below with your own email and then applying it into your cluster:
```sh
cat > cluster_issuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: YOUR_EMAIL_HERE # replace
    privateKeySecretRef:
      name: prod-issuer-account-key
    server: https://acme-v02.api.letsencrypt.org/directory
    solvers:
    - http01:
        ingress:
          class: traefik
      selector: {}
EOF

sed -i 's/YOUR_EMAIL_HERE/your.real.email@address.com/' cluster_issuer.yaml

k apply -f services/cert-manager/cluster_issuer.yaml
```

Finally, when you deploy a service you have to add an ingress resource to instruct your ingress controller how to handle and route the traffic. You can use the following resource as an example and edit it for your service; the key things to change are `.spec.rules[0].host`, `.spec.rules[0].http.paths[0].backend.service.name` and `.spec.tls[0].hosts`:

```sh
cat > ingress_resource.yaml <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: mysite-ingress
  namespace: mysite
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/redirect-entry-point: https
spec:
  ingressClassName: traefik
  rules:
  - host: YOUR_DOMAIN_HERE
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: YOUR_SERVICE_HERE
            port:
                number: 8080
  tls:
  - hosts:
    - YOUR_DOMAIN_HERE
    secretName: mysite-tls-prod
EOF

k apply -f ingress_resource.yaml
```

The last step needs to be done for every service that you want to expose. In this deployment step, cert-manager will handle the communication to Let's Encrypt and add the certificate to your service's ingress resource.

### Multiple Subdomains for a Single Domain

The nice thing about this approach is that it allows you to easily get around the issue of Let's Encrypt not allowing for wildcard certificates when using the [HTTP01 Challenge Type](https://letsencrypt.org/docs/challenge-types/#http-01-challenge). This allows you to essentially have unlimited number of subdomains routed to different services/applications just by creating a new Ingress resource for each one.

All you need to do is create a DNS **A record** that points to the public IP address exposed by the OCI load balancer, then create a **CNAME DNS record** that maps the wildcard subdomain address (i.e. `*.example.com`) to the A record you just created. For example:

| Type  | Host name   | Data         |
| ----- | ----------  | ------------ |
| A     | example.com | 123.45.67.85 |
| CNAME | *.example   | example.com. | 

Once you have the DNS entries set up, you can then just create an ingress resource for each sub-domain that you want to use, there is no need to configure a specific DNS record. Each Ingress resource needs to be in the same namespace as the `Service` it is routing to.

## Using mTLS (Client Certificates) with Traefik Ingress

If any of your services exposed via Ingress are only to be accessed by a small number of known users, then you can configure the route to use mutual TLS (client certificates) so that only clients that present a certificate signed by a particular certificate authority can access the service. This is a huge boon for security and is fairly simple to set up. The following instructions were inspired by a post on [blog.rymcg.tech](https://blog.rymcg.tech/blog/k3s/k3s-07-mutual-tls/).

### Create the CA and Required Certificates

The first thing to do is to create the CA and the required certificates. This can either be done using the `step` CLI or cert-manager.

#### Manual Method Using step-cli

```bash
# Create the root CA certificates.
step certificate create "example.com" \
    --profile root-ca ca-root.crt ca-root.key

# Create the intermediate CA certificates.
step certificate create "mysite.example.com" \
    ca-intermediate.crt ca-intermediate.key \
    --profile intermediate-ca --ca ca-root.crt --ca-key ca-root.key

# Combine both of the CA certificates in a single bundle file.
cat ca-intermediate.crt ca-root.crt > ca-certs.crt

# Create the CA certificate Secret from the bundle file.
kubectl create secret generic certificate-authority \
   --namespace mysite --from-file=tls.ca=ca-certs.crt

# Generate a client certificate.
step certificate create client-mysite \
    client-mysite.crt client-mysite.key \
    --profile leaf --not-after=8760h \
    --ca ca-intermediate.crt \
    --ca-key ca-intermediate.key \
    --insecure --no-password --bundle

# Convert the client certificate and key to PKCS12 format for use in browsers.
openssl pkcs12 -export -clcerts \
    -inkey client-mysite.key -in client-mysite.crt \
    -out client-mysite.p12 -name "mysite.example.com"
```

#### Automated Method Using cert-manager

To avoid having to manually manage the certificates used for the CA, cert-manager can be leveraged to do this for us.

Traefik expects a CA certificate chain bundle to be provided to it in a Secret, therefore, we can additionally use [trust-manager](https://cert-manager.io/docs/trust/trust-manager/) at version >=v0.7.0 (since this allows for this bundle to be written to a Secret rather than just to a ConfigMap) to create this Secret for us automatically. It can be installed with Helm as follows. Note that the name `example-com-ca-certs-bundle` is the name of a Secret that trust-manager will be allowed to read and write across all namespaces. More information about the configurable fields can be found on [Artifact Hub](https://artifacthub.io/packages/helm/cert-manager/trust-manager).

```bash
helm repo add jetstack https://charts.jetstack.io --force-update

helm upgrade -i -n cert-manager trust-manager jetstack/trust-manager \
    --set defaultPackage.enabled=false \
    --set secretTargets.enabled=true \
    --set "secretTargets.authorizedSecrets={mysite-example-com-ca-certs-bundle,mysite2-example-com-ca-certs-bundle}" \
    --version 0.7.0 \
    --wait
```
Now we need to create the cert-manager resources required for generating the CA and client certificates. These all need to be created in the same namespace, `cert-manager` is a good candidate, or a new one could be created for it. This is so that the CA certificates can be accessed and added into a Bundle resource for applications to use in their own namespaces.

The first thing we need is a root CA. From here on, we will create resources for a service called `mysite` at the domain `mysite.example.com` running in the `mysite` namespace.

```yaml
# Create a self-signed Issuer to bootstrap the root CA with.
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: example-com-bootstrap-issuer
  namespace: cert-manager
spec:
  selfSigned: {}

---

# Create the root CA certificate using the bootstrap-issuer.
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com-root-ca-cert
  namespace: cert-manager
spec:
  isCA: true
  commonName: example.com
  secretName: example-com-root-ca-cert
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: example-com-bootstrap-issuer
    kind: Issuer
    group: cert-manager.io

---

# Create the root CA issuer using the root CA certificate.
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: example-com-root-ca-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: example-com-root-ca-cert
```

As we may have multiple applications we want to create client certificates for, it's a good idea to create a new intermediate CA for each one. This can be done as follows, still in the main `cert-manager` namespace:

```yaml
# Create a certificate for the intermediate mysite CA.
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: mysite-example-com-ca-cert
  namespace: cert-manager
spec:
  isCA: true
  commonName: mysite.example.com
  secretName: mysite-example-com-ca-cert
  privateKey:
    algorithm: ECDSA
    size: 256
  issuerRef:
    name: example-com-root-ca-issuer
    kind: Issuer
    group: cert-manager.io

---

# Create an intermediate CA issuer using the intermediate mysite CA certificate.
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: mysite-example-com-ca-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: mysite-example-com-ca-cert
```

Now that we have both our CAs created, we can create an instance of the trust-manager Bundle CR to bundle the certificates of them both into a single Secret that will be deployed to the namespace(s) determined by the `namespaceSelector`.

Note that the `.spec.name` field here need to match one of the `secretTargets.authorizedSecrets` Secret names that was configured when trust-manager was installed via Helm. This the name that will be given to the Secret resource that gets created by trust-manager for this bundle.

```yaml
# Create a CA certificate bundle and deploy it to the mysite namespace.
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: example-com-ca-certs-bundle
spec:
  sources:
  - useDefaultCAs: false
  - secret:
      name: mysite-example-com-ca-cert
      key: tls.crt
  - secret:
      name: example-com-root-ca-cert
      key: tls.crt
  target:
    secret:
      key: ca.crt
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: mysite
```

### Create the Client Certificate and Key

To create a client certificate and key pair for a client of the service, create a Certificate resource like the one below. You will need to create one for each user of the service. In this example, the username **userx** is used.

```yaml
# Create a certificate for the client using the intermediate CA.
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: mysite-example-com-userx-client-cert
  namespace: cert-manager
spec:
  isCA: false
  commonName: mysite.example.com
  dnsNames:
  - mysite.example.com
  emailAddresses:
  - userx@mysite.example.com
  duration: 8760h
  privateKey:
    algorithm: ECDSA
    size: 256
  secretName: mysite-example-com-userx-client-cert
  issuerRef:
    name: mysite-example-com-ca-issuer
    kind: Issuer
    group: cert-manager.io
```

Once that's deployed, the client certificate and key can then be exported using `openssl` as follows. Use a suitably strong password when prompted, this will be required when importing it for use.

```bash
openssl pkcs12 -export -out mysite-userx.p12 -name "mysite.example.com" \
    -in <(kubectl get secrets mysite-example-com-userx-client-cert \
              -n cert-manager \
              -o go-template='{{index .data "tls.crt"}}' | base64 -d) \
    -inkey <(kubectl get secrets mysite-example-com-userx-client-cert \
                -n cert-manager \
                -o go-template='{{index .data "tls.key"}}' | base64 -d)
```

Once the client certificate and key have been exported, the corresponding Certificate and Secret resources can be removed from the cluster if desired, alternatively, they can be left in-place and cert-manager will renew the certificate when it's due and the previous command can be used to extract the updated certificate and key from the cluster again.

```bash
kubectl delete secret -n cert-manager mysite-example-com-userx-client-cert
kubectl delete certificate -n cert-manager mysite-example-com-userx-client-cert
```

The PKCS12 client certificate can be imported into a browser and then selected when prompted by the browser upon visiting the website.

To install on *Chrome*, open **Settings**, then navigate to **Privacy and Security** > **Security** > **Manage device certificates** and then import the PKCS12 version of the client certificate.

For *Firefox*, open **Settings**, then navigate to **Privacy & Security** and under the **Certificates** section, click the **View Certificates** button and click the **Import** button in the **Your Certificates** tab.

On *Android*, open **Settings**, then navigate to **Security and privacy** > **More security and privacy** > **Encryption and credentials** > **Install a certificate**. You then need to install the the PKCS12 client certificate as a **VPN and app user certificate**.

Unfortunately, on Android, Firefox does not support client certificates — even with support for third-party CA certificates turned on via the secret menu. Brave, Chrome, Edge and Opera all do however, and will prompt for which installed certificate to use when the site is visited.

### Configure the Ingress

Finally, as per the `services/ingress_mtls_example.yaml` file, create a Traefik `TLSOption` resource with the `secretNames` field set to the name of the CA certificate bundle Secret created previously. You must also add the required two "router" annotations to the Ingress resource. The format of the second annotation's value is `${NAMESPACE}-${TLSOPTION_RESOURCE_NAME}@kubernetescrd`.

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: TLSOption
metadata:
  name: mtls
  namespace: mysite
spec:
  minVersion: VersionTLS12
  maxVersion: VersionTLS13
  clientAuth:
    secretNames:
    - example-com-ca-certs-bundle
    clientAuthType: RequireAndVerifyClientCert

---

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  labels:
    domain: mysite.example.com
  name: mysite-ingress
  namespace: mysite
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/redirect-entry-point: https
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls.options: mysite-mtls@kubernetescrd
  ...
```

This works just fine with server TLS certificates created by Let's Encrypt. The client CA we have created is completely independent of that.

Once everything has been deployed into the cluster, the endpoint can then be accessed using the client certificate and key previously installed into the browser. Alternatively, the endpoint can be called via cURL as follows:

```bash
curl --cert-type P12 --cert mysite-userx.p12:Pa55W0rd https://mysite.example.com/
```

