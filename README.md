# Implementing your own ELK Stack on Azure through CLI

## Introduction
Some time ago I had to help a customer in a PoC over the implementation of ELK Stack (ElasticSearch, Logstash and Kibana) on Azure IaaS using Azure CLI. Then here are all steps maybe you should follow to implement something similar.

> Please note you have different options to deploy and use [ElasticSearch on Azure](https://azure.microsoft.com/en-us/overview/linux-on-azure/elastic/)

![elk](/elk-stack.png)

## Data flow

The illustration below refers to the logical architecture implemented to prove the concept. This architecture includes an application server, the Azure Redis service, a server with Logstash, a server with ElasticSearch and a server with Kibana and a web service (Nginx) installed.

![flow](/flow.png)


## Description of components

**Application Server**: To simulate an application server generating logs, a script was used that generates logs randomly. The source code for this script is available at [https://github.com/bitsofinfo/log-generator](https://github.com/bitsofinfo/log-generator). It was configured to generate the logs in /tmp/log-sample.log.

**Filebeat**: Agent installed on the application server and configured to send the generated logs to Azure Redis. Filebeat has the function of shipping the logs using the lumberjack protocol.

**Azure Redis Service**: Managed data storage service in memory. It was used because search engines can be an operational nightmare. Indexing can bring down a traditional cluster and data can end up being reindexed for a variety of reasons. Thus, the choice of Redis between the event source and parsing and processing is only to index/parse as fast as the nodes and databases involved can manipulate this data allowing it to be possible to extract directly from the flow of events instead to have events being inserted into the pipeline. Through Redis Monitor it is possible to see exactly what is happening in Redis: Filebeat sending the data and Logstash asking for them:

![redis](/redis-console.png)

**Logstash:** Processes and indexes the logs by reading from Redis and submitting to ElasticSearch.

**ElasticSearch:** Stores logs

**Kibana/Nginx**: Web interface for searching and viewing the logs that are proxied by Nginx

## Deployment

The deployment of the environment is done using Azure CLI commands in a shell script. In addition to serving as documentation on the services that have been deployed, they are a  good practice on IaC.

The script will perform the following steps:

1. Create the resource group
2. Create the Redis service
3. Create a VNET called myVnet with the prefix 10.0.0.0/16 and a subnet called mySubnet with the prefix 10.0.1.0/24
4. Create the Application server VM
   * Size: Standard_D2S_v3
   * User: elk
   * SSH keys: Public and private keys will be generated in ~/.ssh. To access the VMs run ssh -i ~/.ssh /id_rsa elk@<ip>
5. Log Generator Installation/Configuration
6. Installation / Configuration of Filebeat
7. Filebeat Start
8. Create the ElasticSearch server VM
9. Configure NSG and free access on port 9200 for subnet 10.0.1.0/24
10. Install Java
11. Installing/Configuring ElasticSearch
12. ElasticSearch Start
13. Create the Logstash server VM
14. Logstash Installation / Configuration
15. Logstash Start
16. Create the Kibana server VM
17. Configure NSG and allow access on port 80 to 0.0.0.0/0
18. Installing/Configuring Kibana
19. Installing/Configuring Nginx

## Script to setup ELK Stack

Available at: [https://gist.github.com/ricmmartins/fffbf5cfeb019c70ec029eab5192421b](https://gist.github.com/ricmmartins/fffbf5cfeb019c70ec029eab5192421b). Just download then:

```
chmod a+x elk-stack-azure.sh
./elk-stack-azure.sh
```

## Finishing the setup
