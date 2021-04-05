# Implementing your own ELK Stack on Azure through CLI

## Introduction
Some time ago I had to help a customer in a PoC over the implementation of ELK Stack (ElasticSearch, Logstash and Kibana) on Azure IaaS using Azure CLI. Then here are all steps maybe you should follow to implement something similar.

> Please note you have different options to deploy and use [ElasticSearch on Azure](https://azure.microsoft.com/en-us/overview/linux-on-azure/elastic/)

![elk](/elk-stack.png)

## Data flow

The illustration below refers to the logical architecture implemented to prove the concept. This architecture includes an application server, the Azure Redis service, a server with Logstash, a server with ElasticSearch and a server with Kibana and a web service (Nginx) installed.

![flow](/flow.png)
