# consul template

Commands:

Install

```shell
wget https://releases.hashicorp.com/consul-template/0.27.0/consul-template_0.27.0_linux_amd64.zip
```

```shell
# run command on consul node web1 and stop container
consul exec -node web1 docker stop web1

consul-template -consul-addr=consulserverinfra.corp.cloudlinux.com \
  -template="./haproxy.conf.ctmpl:./haproxy.conf" -dry
```

To run with config file

```shell
consul-template -config config.hcl
```

## REFERENCE

> https://github.com/hashicorp/consul-template
