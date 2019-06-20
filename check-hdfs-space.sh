#!/bin/bash

json=$(curl -s http://path.to.mesos.cluster:50070/jmx?qry=Hadoop:*)

gb_remaining=$( echo $json | jq '.beans[]| select(.name =="Hadoop:service=NameNode,name=FSNamesystem").CapacityRemainingGB' )

/usr/bin/zabbix_sender -z zabbix.server.hostname -p 10051 -s "name of host as it appears in zabbix" -k trapper_key_name -o "$gb_remaining"