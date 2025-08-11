# Consul deployment

[Download](https://releases.hashicorp.com/consul/1.7.4/consul_1.7.4_linux_amd64.zip)

## [Getting started](https://learn.hashicorp.com/consul/getting-started/agent)

After you install Consul you'll need to start the Consul agent.

In production you would run each Consul agent in either in server or client mode. Each Consul datacenter must have at least one server, which is responsible for maintaining Consul's state. This includes information about other Consul servers and clients, what services are available for discovery, and which services are allowed to talk to which other services.

Non-server agents run in client mode. A client is a lightweight process that registers services, runs health checks, and forwards queries to servers. A client must be running on every node in the Consul datacenter that runs services, since clients are the source of truth about service health.

---

### Dev Mode

Start the Consul agent in development mode.  

```shell
consul agent -dev
consul members
curl localhost:8500/v1/catalog/nodes
dig @127.0.0.1 -p 8600 Judiths-MBP.node.consul
consul leave
```

---

## [Register a Service with Consul Service Discovery](https://learn.hashicorp.com/consul/getting-started/services)

You can register services either by providing a service definition, which is the most common way to register services, or by making a call to the HTTP API. Here you will use a service definition.

First, create a directory for Consul configuration. Consul loads all configuration files in the configuration directory, so a common convention on Unix systems is to name the directory something like /etc/consul.d (the .d suffix implies "this directory contains a set of configuration files").

```shell
mkdir ./consul.d

echo '{
  "service": {
    "name": "web",
    "tags": [
      "rails"
    ],
    "port": 80
  }
}' > ./consul.d/web.json

consul agent -dev -enable-script-checks -config-dir=./consul.d -node=server1
```

Query services

```shell
dig @127.0.0.1 -p 8600 web.service.consul
dig @127.0.0.1 -p 8600 web.service.consul SRV
dig @127.0.0.1 -p 8600 rails.web.service.consul
curl http://localhost:8500/v1/catalog/service/web
curl 'http://localhost:8500/v1/health/service/web?passing'
```

Update services

```shell
echo '{
  "service": {
    "name": "web",
    "tags": [
      "rails"
    ],
    "port": 80,
    "check": {
      "args": [
        "curl",
        "localhost"
      ],
      "interval": "10s"
    }
  }
}' > ./consul.d/web.json

consul reload

dig @127.0.0.1 -p 8600 web.service.consul
```

## [Connect Services with Consul Service Mesh](https://learn.hashicorp.com/consul/getting-started/connect)

In addition to providing IP addresses directly to services with the DNS interface or HTTP API, Consul can connect services to each other via sidecar proxies that you deploy locally with each service instance. This type of deployment (local proxies that control network traffic between service instances) is a service mesh. Because sidecar proxies connect your registered services, Consul's service mesh feature is called Consul Connect.

### Start a Connect-unaware service

Begin by starting a service that is unaware of Connect. You will use socat to start a basic echo service, which will act as the "upstream" service in this guide. In production, this service would be a database, backend, or any service which another service relies on.

Socat is a decades-old Unix utility that lacks a concept of encryption or the TLS protocol. You will use it to demonstrate that Connect takes care of these concerns for you. If socat isn't installed on your machine, it should be available via a package manager.

Start the socat service and specify that it will listen for TCP connections on port 8181.

```shell
socat -v tcp-l:8181,fork exec:"/bin/cat"
nc 127.0.0.1 8181

echo '{
  "service": {
    "name": "socat",
    "port": 8181,
    "connect": {
      "sidecar_service": {}
    }
  }
}' > ./consul.d/socat.json

consul reload
consul connect proxy -sidecar-for socat

 echo '{
  "service": {
    "name": "web",
    "connect": {
      "sidecar_service": {
        "proxy": {
          "upstreams": [
            {
              "destination_name": "socat",
              "local_bind_port": 9191
            }
          ]
        }
      }
    }
  }
}' > ./consul.d/web.json

consul reload
consul intention create -deny web socat
nc 127.0.0.1 9191
consul intention delete web socat
nc 127.0.0.1 9191
```

## [Store Data in Consul KV](https://learn.hashicorp.com/consul/getting-started/kv)

```shell
consul kv put redis/config/minconns 1
consul kv put redis/config/maxconns 25
consul kv put -flags=42 redis/config/users/admin abcd1234
consul kv get redis/config/minconns
consul kv get -detailed redis/config/users/admin
consul kv get -recurse
consul kv delete redis/config/minconns
consul kv delete -recurse redis
consul kv put -h
```

## [Create a Local Consul Datacenter](https://learn.hashicorp.com/consul/getting-started/join)

```shell
mkdir consul-getting-started-join
cd consul-getting-started-join
wget https://raw.githubusercontent.com/hashicorp/consul/master/demo/vagrant-cluster/Vagrantfile
vagrant up

vagrant ssh n1
consul agent \
  -server \
  -bootstrap-expect=1 \
  -node=agent-one \
  -bind=172.20.20.10 \
  -data-dir=/tmp/consul \
  -config-dir=/etc/consul.d

vagrant ssh n2
consul agent \
  -node=agent-two \
  -bind=172.20.20.11 \
  -enable-script-checks=true \
  -data-dir=/tmp/consul \
  -config-dir=/etc/consul.d

consul members
```

Now you have two Consul agents running: one server and one client. The two agents still don't know about each other and each comprise their own single-node datacenters.

Verify this by ssh-ing into each VM and checking each agent's membership information. You'll need to open a new terminal window and change directories into consul-getting-started-join

```shell
vagrant ssh n2
# vagrant@n2:~
$ consul members

vagrant ssh n1
# vagrant@n1:~
$ consul members

# vagrant@n1:~
$ consul join 172.20.20.11
# vagrant@n1:~
$ consul members
```

**Tip:** To join a datacenter, a Consul agent only needs to learn about one other existing member, which can be a client or a server. After joining the datacenter, the agents automatically gossip with each other to propagate full membership information.

Query the node

```shell
# vagrant@n1:~
$ dig @127.0.0.1 -p 8600 agent-two.node.consul
...

;; QUESTION SECTION:
;agent-two.node.consul. IN  A

;; ANSWER SECTION:
agent-two.node.consul.  0 IN    A   172.20.20.11
```

### Stop the agents

Stop both of your agents gracefully by either typing `Ctrl-c` in the terminal windows where they are running, or issuing the `consul leave` command.

## helm chart install

- https://github.com/hashicorp/consul-helm
- https://github.com/kelseyhightower/consul-on-kubernetes
- https://www.consul.io/docs/k8s/helm

```shell
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install consul hashicorp/consul -f values.yml
```

You can clone and change values.yml
git clone https://github.com/hashicorp/consul-helm.git

```shell
kubectl create secret generic consul-gossip-encryption-key --from-literal=key=$(consul keygen)
```

TOKEN: `kubectl get secrets consul-consul-bootstrap-acl-token -o yaml | head -n 3 | grep token | cut -d " " -f 4 | base64 --decode`

Login to UI with TOKEN

### stub dns

- https://www.consul.io/docs/k8s/dns
- https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/

```shell
kubectl get svc consul-consul-dns -o jsonpath='{.spec.clusterIP}'
kubectl edit cm -n kube-system coredns 
```

```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }
        prometheus :9153
        forward . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
    consul {
         errors
         cache 30
         forward . 10.106.90.170
        }
kind: ConfigMap
```

**NOTE**  
When creating connectInject proxy, pod service account must match service account name when ACL enabled
https://learn.hashicorp.com/consul/gs-consul-service-mesh/secure-applications-with-consul-service-mesh

### Example

`kubectl apply -f  mesh.yml`

From gui ACL allow curl to web, and check

`kubectl exec -it curl -c curl  -- curl http://127.0.0.1:9091`

Below always works

`kubectl exec -it curl -c curl  -- curl http://web`

Default acl plocy is deny. You need to explicitky allow inter-service connection

```shell
[vagrant@master ~]$ kubectl get cm consul-consul-server-config  -o yaml
apiVersion: v1
data:
  acl-config.json: |-
    {
      "acl": {
        "enabled": true,
        "default_policy": "deny",
        "down_policy": "extend-cache",
        "enable_token_persistence": true
      }
    }
  central-config.json: |-
    {
      "enable_central_service_config": true
    }
  extra-from-values.json: '{}'
kind: ConfigMap
```

## Kubernetes manifest install

- https://github.com/testdrivenio/vault-consul-kubernetes
- https://caylent.com/hashicorp-vault-on-kubernetes
- https://testdriven.io/blog/running-vault-and-consul-on-kubernetes/
- https://learn.hashicorp.com/consul/kubernetes/kubernetes-deployment-guide
- https://www.consul.io/docs/k8s/installation/overview
- https://stackoverflow.com/questions/62023421/hashicorp-consul-how-to-do-verified-tls-from-pods-in-kubernetes-cluster
- https://learn.hashicorp.com/consul/datacenter-deploy/deployment-guide
- https://discuss.hashicorp.com/t/kubernetes-client-mode-consul-is-not-accepting-service/8993/3

```shell
kubectl create clusterrolebinding kubernetes-dashboard -n kube-system --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
```

## REFERENCE

> - [Enterprise Deployment](https://learn.hashicorp.com/consul/datacenter-deploy/deployment-guide)
> - [Installation](https://www.consul.io/docs/k8s/installation/overview)
> - <https://www.consul.io/docs/k8s/service-sync>
> - <https://www.consul.io/docs/k8s/connect>
> - <https://discuss.hashicorp.com/t/kubernetes-client-mode-consul-is-not-accepting-service/8993/5>
