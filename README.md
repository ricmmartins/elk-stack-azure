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

![redis](/redis.png)

**Logstash:** Processes and indexes the logs by reading from Redis and submitting to ElasticSearch.

**ElasticSearch:** Stores logs

**Kibana/Nginx**: Web interface for searching and viewing the logs that are proxied by Nginx
