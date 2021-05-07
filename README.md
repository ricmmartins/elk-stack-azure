# Implementing your own ELK Stack on Azure through CLI

## Introduction
Some time ago I had to help a customer in a PoC over the implementation of ELK Stack (ElasticSearch, Logstash and Kibana) on Azure VMs using Azure CLI. Then here are all steps you should follow to implement something similar.

> Please note you have different options to deploy and use [ElasticSearch on Azure](https://azure.microsoft.com/en-us/overview/linux-on-azure/elastic/)

![elk](/images/elk-stack.png)

## Data flow

The illustration below refers to the logical architecture implemented to prove the concept. This architecture includes an application server, the Azure Redis service, a server with Logstash, a server with ElasticSearch and a server with Kibana and Nginx installed.

![flow](/images/flow.png)

## Description of components

**Application Server**: To simulate an application server generating logs, a script was used that generates logs randomly. The source code for this script is available at [https://github.com/bitsofinfo/log-generator](https://github.com/bitsofinfo/log-generator). It was configured to generate the logs in /tmp/log-sample.log.

**Filebeat**: Agent installed on the application server and configured to send the generated logs to Azure Redis. Filebeat has the function of shipping the logs using the lumberjack protocol.

**Azure Redis Service**: Managed service for in-memory data storage. It was used because search engines can be an operational nightmare. Indexing can bring down a traditional cluster and data can end up being reindexed for a variety of reasons. Thus, the choice of Redis between the event source and parsing and processing is only to index/parse as fast as the nodes and databases involved can manipulate this data allowing it to be possible to extract directly from the flow of events instead to have events being inserted into the pipeline. 

**Logstash:** Processes and indexes the logs by reading from Redis and submitting to ElasticSearch.

**ElasticSearch:** Stores logs

**Kibana/Nginx**: Web interface for searching and viewing the logs that are proxied by Nginx

## Deployment

The deployment of the environment is done using Azure CLI commands in a shell script. In addition to serving as documentation about the services deployed, they are a  good practice on IaC. In this demo I'll be using [Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview) once is fully integrated to Azure.

I'll be using the Azure Cloud Shell once is fully integrated to Azure and with all modules I need already installed. Make sure to swhich to Bash:

![select-shell](/images/select-shell-drop-down.png)


The script will perform the following steps:

1. Create the resource group
2. Create the Redis service
3. Create a VNET called myVnet with the prefix 10.0.0.0/16 and a subnet called mySubnet with the prefix 10.0.1.0/24
4. Create the Application server VM
5. Log Generator Installation/Configuration
6. Installation / Configuration of Filebeat
7. Filebeat Start
8. Create the ElasticSearch server VM
9. Configure NSG and allow access on port 9200 for subnet 10.0.1.0/24
10. Install Java
11. Install/Configure ElasticSearch
12. Start ElasticSearch 
13. Create the Logstash server VM
14. Install/Configure Logstash
15. Start Logstash
16. Create the Kibana server VM
17. Configure NSG and allow access on port 80 to 0.0.0.0/0
18. Install/Configure Kibana and Nginx

> Note that Linux User is set to **elk**. Public and private keys will be generated in ~/.ssh. To access the VMs run ssh -i ~/.ssh /id_rsa elk@ip

## Script to setup ELK Stack

The script is [available here](/elk-stack-azure.sh). Just download then execute the following:

```
wget https://raw.githubusercontent.com/ricmmartins/elk-stack-azure/main/elk-stack-azure.sh
chmod a+x elk-stack-azure.sh
./elk-stack-azure.sh <resource group name> <location> <redis name>
```
![cloudshell](/images/cloudshell.png)

After a few minutes the execution of the script will be completed, then you have just to finish the setup through Kibana interface.

## Finishing the setup

To finish the setup, the next step is to connect to the public IP address of the Kibana/Nginx VM. Once connected, the home screen should look like this:

![kibana-1](/images/kibana-1.png)

Then click to create **Explore my own**. In the next screen click on **Discover**

![kibana-2](/images/kibana-2.png)

Now click on **Create index pattern**

![kibana-3](/images/kibana-3.png)

On the next screen type **logstash** on the step 1 of 2, then click to **Next step**

![kibana-4](/images/kibana-4.png)

On the step 2 of 2, point to **@timestamp** 

![kibana-5](/images/kibana-5.png)

Then click to **Create index pattern**

![kibana-5-1](/images/kibana-5-1.png)

![kibana-6](/images/kibana-6.png)

After a few seconds you will have this:

![kibana-7](/images/kibana-7.png)

Click on **Discover** on the menu

![kibana-8](/images/kibana-8.png)

Now you have access to all indexed logs and the messages generated by Log Generator:

![kibana-9](/images/kibana-9.png)

## Final notes

As mentioned earlier, this was done for a PoC purposes. If you want add some extra layer for security, you can restrict the access adding [HTTP Basic Authentication for NGINX](https://docs.nginx.com/nginx/admin-guide/security-controls/configuring-http-basic-authentication/) or restricting the access trough private IPs and a VPN.
