consul {
  address = "consulserverinfra.corp.cloudlinux.com"
  token = "a8fe0fe5-e457-cc92-1c80-b3d7cdd69a4d"
}

log_level = "warn"

#vault {
#  address = "http://127.0.0.1:8200"
#  token = ""
#}

template {
  source = "./haproxy.conf.ctmpl"
  destination = "./haproxy.conf"
  command = "echo systemctl reload haproxy"
}
