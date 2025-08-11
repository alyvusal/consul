git clone git@github.com:dryice-devops/consul.git
unzip counting-service_linux_amd64.zip
unzip dashboard-service_linux_amd64.zip
PORT=9002 COUNTING_SERVICE_URL="http://localhost:5000" ./dashboard-service_linux_amd64 &
PORT=9003 ./counting-service_linux_amd64 &

consul services register counting.hcl
consul services register dashboard.hcl

consul catalog services

# start the built-in sidecar proxy for the counting and dashboard services
consul connect proxy -sidecar-for counting-1 > counting-proxy.log &
consul connect proxy -sidecar-for dashboard > dashboard-proxy.log &

consul intention delete dashboard counting

consul intention create -deny -replace dashboard counting