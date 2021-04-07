#!/bin/bash

# Define variables
rg="$1"
location="$2"
redisname="$3"

# Validate parameters
if [ "$1" = "" ]; then
    echo "Wrong usage! You need inform the parameters."
    echo "Example: ./elk-setup.sh <resource group name> <location> <redis name>"
exit 1
elif [ "$1" != "" ]; then

# Create Resource Group
az group create --name $rg  --location $location

# Create Redis Service
az redis create --name $redisname --resource-group $rg --location $location --sku Standard --vm-size C1 --enable-non-ssl-port

# Get Redis Info
az redis show --resource-group $rg --name $redisname
az redis list-keys --resource-group $rg --name $redisname

# Create VNET
az network vnet create --resource-group $rg --name myVnet --address-prefix 10.0.0.0/16 --subnet-name mySubnet --subnet-prefix 10.0.1.0/24

# Create App VM

## Create VM
az vm create --resource-group $rg --name app-vm \
--size Standard_D2S_v3  \
--image Canonical:UbuntuServer:18.04-LTS:latest  \
--admin-username elk \
--generate-ssh-keys \
--no-wait \
--vnet-name myVnet \
--subnet  mySubnet \
--nsg nsg-app-vm

sleep 60

# Setup Log Generator

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "cd /tmp && git clone https://github.com/bitsofinfo/log-generator.git && cd /tmp/log-generator && python ./log_generator.py --logFile /tmp/log-sample.log &"

# Setup Filebeat

redis_host="$(az redis show --resource-group $rg --name $redisname | tail -1 | awk '{ print $2 }')"
redis_primary_key="$(az redis list-keys --resource-group $rg --name $redisname | tail -1 | awk '{ print $2 }')"

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "cd /tmp && curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-6.4.1-amd64.deb && sudo dpkg -i filebeat-6.4.1-amd64.deb && sudo /bin/cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.ori"

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "sudo sed -i.bak 's/enabled: false/enabled: true'/g /etc/filebeat/filebeat.yml"

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "sudo sed -i.bak 's/\/var\/log\//\/tmp\/'/g /etc/filebeat/filebeat.yml"

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "sudo sed -i.bak 's/setup.kibana/#setup.kibana'/g /etc/filebeat/filebeat.yml"

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "sudo sed -i.bak 's/output.elasticsearch/#output.elasticsearch'/g /etc/filebeat/filebeat.yml"

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "sudo sed -i.bak 's/hosts/#hosts'/g /etc/filebeat/filebeat.yml"

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "cat <<'EOT' >> /etc/filebeat/filebeat.yml
output.redis:
  hosts: ['$redis_host']
  password: '$redis_primary_key'
  key: 'filebeat'
  db: 0
  timeout: 5
EOT"

## Start Filebeat

az vm run-command invoke -g $rg -n app-vm \
--command-id RunShellScript --scripts "sudo service filebeat start"

# Create Elasticsearch VM

## Create VM
az vm create --resource-group $rg --name elasticsearch-vm \
--size Standard_D2S_v3  \
--image Canonical:UbuntuServer:18.04-LTS:latest  \
--admin-username elk \
--generate-ssh-keys \
--no-wait \
--vnet-name myVnet \
--subnet  mySubnet \
--nsg nsg-elasticsearch-vm

sleep 60

## Create NSG Rule

az network nsg rule create --resource-group $rg --nsg-name nsg-elasticsearch-vm \
--name port-9200-rule \
--access Allow \
--protocol Tcp \
--direction Inbound \
--priority 300 \
--source-address-prefix 10.0.1.0/24 \
--source-port-range "*" \
--destination-address-prefix "*" \
--destination-port-range 9200

## Install Java 

az vm run-command invoke -g $rg -n elasticsearch-vm \
--command-id RunShellScript --scripts "sudo apt update && sudo apt-get install -y openjdk-8-jdk"

## Install Elasticsearch

az vm run-command invoke -g $rg -n elasticsearch-vm \
--command-id RunShellScript --scripts "wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -"

az vm run-command invoke -g $rg -n elasticsearch-vm \
--command-id RunShellScript --scripts "sudo apt-get install -y apt-transport-https"

az vm run-command invoke -g $rg -n elasticsearch-vm \
--command-id RunShellScript --scripts "echo deb https://artifacts.elastic.co/packages/7.x/apt stable main | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list"

az vm run-command invoke -g $rg -n elasticsearch-vm \
--command-id RunShellScript --scripts "sudo apt-get update && sudo apt-get install -y elasticsearch"


## Configure Elasticsearch

az vm run-command invoke -g $rg -n elasticsearch-vm \
--command-id RunShellScript --scripts "sudo /bin/cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.ori && > /etc/elasticsearch/elasticsearch.yml"

az vm run-command invoke -g $rg -n elasticsearch-vm \
--command-id RunShellScript --scripts "cat <<'EOT' >> /etc/elasticsearch/elasticsearch.yml
network.host: 0.0.0.0
discovery.type: single-node
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
EOT"

## Start ElasticSearch

az vm run-command invoke -g $rg -n elasticsearch-vm \
--command-id RunShellScript --scripts "sudo systemctl enable elasticsearch.service && sudo systemctl start elasticsearch.service"


# Create Logstash VM

## Create VM
az vm create --resource-group $rg --name logstash-vm \
--size Standard_D2S_v3  \
--image Canonical:UbuntuServer:18.04-LTS:latest  \
--admin-username elk \
--generate-ssh-keys \
--no-wait \
--vnet-name myVnet \
--subnet  mySubnet \
--nsg nsg-logstash-vm

sleep 60

## Install Java 

az vm run-command invoke -g $rg -n logstash-vm \
--command-id RunShellScript --scripts "sudo apt-get update && sudo apt-get install -y openjdk-8-jdk"

## Install Logstash

az vm run-command invoke -g $rg -n logstash-vm \
--command-id RunShellScript --scripts "wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -"

az vm run-command invoke -g $rg -n logstash-vm \
--command-id RunShellScript --scripts "sudo apt-get install -yl apt-transport-https"

az vm run-command invoke -g $rg -n logstash-vm \
--command-id RunShellScript --scripts "echo deb https://artifacts.elastic.co/packages/7.x/apt stable main | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list"


az vm run-command invoke -g $rg -n logstash-vm \
--command-id RunShellScript --scripts "sudo apt-get update && sudo apt-get install -y logstash"


# Configure Logstash

redis_host="$(az redis show --resource-group $rg --name $redisname | tail -1 | awk '{ print $2 }')"
redis_primary_key="$(az redis list-keys --resource-group $rg --name $redisname | tail -1 | awk '{ print $2 }')"
elasticsearch_host="$(az vm show -g $rg  -n elasticsearch-vm -d --query privateIps -otsv)"

az vm run-command invoke -g $rg -n logstash-vm \
--command-id RunShellScript --scripts "cat <<'EOT' >> /etc/logstash/conf.d/logstash.conf
# Logstash Config

input {
        redis {
                host        => \"$redis_host\"
                port        => \"6379\"
                password    => \"$redis_primary_key\"
                db          => \"0\"
                data_type   => \"list\"
                key         => \"filebeat\"
        }
}
output {
  elasticsearch {
    hosts => [\"http://$elasticsearch_host:9200\"]
    }
}
EOT"

## Start Logstash

az vm run-command invoke -g $rg -n logstash-vm \
--command-id RunShellScript --scripts "sudo systemctl enable logstash.service && sudo systemctl start logstash.service"


# Create Kibana VM

az vm create --resource-group $rg --name kibana-vm \
--size Standard_D2S_v3  \
--image Canonical:UbuntuServer:18.04-LTS:latest  \
--admin-username elk \
--generate-ssh-keys \
--no-wait \
--vnet-name myVnet \
--subnet  mySubnet \
--nsg nsg-kibana-vm

sleep 60

## Create NSG Rule
az network nsg rule create --resource-group $rg --nsg-name nsg-kibana-vm \
--name port-80-rule \
--access Allow \
--protocol Tcp \
--direction Inbound \
--priority 300 \
--source-address-prefix Internet \
--source-port-range "*" \
--destination-address-prefix "*" \
--destination-port-range 80

## Install Kibana

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -"

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "echo deb https://artifacts.elastic.co/packages/7.x/apt stable main | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list"

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "sudo apt-get update && sudo apt-get install -y kibana"

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "sudo /bin/systemctl daemon-reload && sudo /bin/systemctl enable kibana.service"

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "sudo /bin/cp /etc/kibana/kibana.yml /etc/kibana/kibana.yml.ori && > /etc/kibana/kibana.yml"

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "cat <<EOT >> /etc/kibana/kibana.yml
server.host: "localhost"
server.port: 5601
elasticsearch.hosts: http://"$elasticsearch_host:9200"
EOT"

## Start Kibana

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "sudo systemctl start kibana.service"

## Install Nginx

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "sudo apt-get install -y nginx"

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "> /etc/nginx/sites-available/default"

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "cat <<'EOT' >> /etc/nginx/sites-available/default
# Nginx Config

    server {
        listen 80;
        server_name _;
        location / {
            proxy_pass http://localhost:5601;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
EOT"

## Start Nginx

az vm run-command invoke -g $rg -n kibana-vm \
--command-id RunShellScript --scripts "sudo systemctl restart nginx"

fi
exit
