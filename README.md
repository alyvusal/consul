# Hashicorp Consul

[back](../README.md)

## Install

```bash
helm upgrade -i consul hashicorp/consul \
  --create-namespace --namespace consul \
  --version 1.6.1 \
  -f k8s/helm/consul.yaml

kubectl -n consul port-forward svc/consul-ui 8501:443

export CONSUL_HTTP_ADDR=https://consul-192.168.0.100.nip.io
export CONSUL_HTTP_ADDR=https://127.0.0.1:8501
export CONSUL_HTTP_SSL_VERIFY=false
export CONSUL_HTTP_TOKEN=$(kubectl get -n consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)
consul catalog services
consul members
consul operator raft list-peers

kubectl get gatewayClassConfigs -o yaml
```

Reference tutorial files: `examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local/helm`

## Sample Apps

### v1

```bash
# label ns for sidecar inject
kubectl label ns default connect-inject=enabled
# also add annotation to deployment: consul.hashicorp.com/connect-inject: "true",
# if in helm connectInject.default is false (true means auto injet to all pods even annotation not not added)

kubectl logs -n consul deploy/consul-connect-injector -f

# cd examples/tutorial
# git clone https://github.com/hashicorp-education/learn-consul-get-started-kubernetes.git
kubectl apply -f examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local/hashicups/v1

# This configuration deployed Consul in secure mode with ACLs set to a default deny policy and is automatically managed by Consul and Kubernetes.
# This means that the only allowed service-to-service communications are the ones explicitly specified by intentions.
consul intention list

kubectl port-forward svc/nginx --namespace default 8080:80
# Open http://localhost:8080
# Notice that while you can reach the nginx instance because of the port forwarding, the nginx service is unable to access its upstreams and the connection is refused
```

Create intentions to allow inter service traffic

```bash
kubectl apply -f examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local/hashicups/intentions/allow.yaml
```

Create Consul ingress gw

```bash
# create ingress gw, add routes from gw to service and create intentions
kubectl apply -f examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local/api-gw

# Now that Consul API Gateway is operational in your cluster, you will deploy role-based access control (RBAC) and Reference Grant resources.
# RBAC enables the Consul API gateway to interact with Consul datacenter resources and reference grants
# enable the Consul API Gateway to route traffic between different namespaces.
# deploy rbac
kubectl apply -f examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local/hashicups/v2
```

### Observability

```bash
# The ProxyDefaults configuration entry lets you configure global defaults across all services for Consul service mesh proxy configurations.
kubectl apply -f examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local/proxy/proxy-defaults.yaml

# Restart sidecar proxies
kubectl delete -f examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local/hashicups/v1
kubectl apply -f examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local/hashicups/v1

# confiurm if defaults added
kubectl port-forward deploy/frontend 19000:19000
# http://localhost:19000/config_dump
# socket_address { "address": "0.0.0.0", "port_value": 20200}

# deploy metrics servers (grafana, prometheus etc)
cd examples/tutorial/learn-consul-get-started-kubernetes/self-managed/local
bash install-observability-suite.sh

# kubectl port-forward deployments/prometheus-server 9090
# checl http://127.0.0.1:9090/targets for errors
```

### REFERENCE

- [Get Started on Kubernetes](https://developer.hashicorp.com/consul/tutorials/get-started-kubernetes)
