# Readme

Uses the Hadoop jmx webservice to send `CapacityRemainingGB` to Zabbix server via `zabbix_sender`

## Setup

### Step one

Summary: Set up a "trapper" in Zabbix.

Zabbix uses an agent on the remote machines it is set to monitor.  Instead, we'll be pushing data into Zabbix.  You'll want to set up a "trapper" in Zabbix under a host so that Zabbix can accept this incoming data.

Make note of the `key` value that you assign, as you'll need that later.

Set up appropriate triggers and actions for your situation.  

### Step two

Summary: Install requires packages:

```
apt-get install curl zabbix-agent jq
```

JQ is used to parse the resulting json from the jmx webservice.

This setup requires `zabbix_sender`, which is usually part of the `zabbix-agent` package
and will likely be located at `/usr/bin/zabbix_sender` after installation.  Note the dash/underscore differences.

I found some references online that said `zabbix_sender` wasn't in the agent library, but this worked for me on ubuntu 18.04.

### Step three

Summary: 

Edit `check_hdfs_space.sh` and update:
1. the mesos cluster hostname in the curl command; port 50070 is the default but your setup might be differ
1. the "name" of the host you're monitoring in zabbix itself (`-s`, often the FQDN)
1. the hostname of the zabbix server (`-z`)
1. the key (`-k`) value that you specified above when creating the trapper item in zabbix.

This may or may not make a different, but note that the key is passed to `zabbix_sender` "as a variable," so to speak, and not enclosed in quotes as a string:

```
# works:
/usr/bin/zabbix_sender -z zabbix.server.com -p 10051 -s "node.name.in.zabbix" -k your_key_name_here -o "$gb_remaining"

# may or may not work:
/usr/bin/zabbix_sender -z zabbix.server.com -p 10051 -s "node.name.in.zabbix" -k "your_key_name_here -o" "$gb_remaining"
```

### Step four

Summary: Modify the systemd files if desired, move them to their appropriate places, and enable the timer

Notes:
* keep the `.service` itself set to `Type=oneshot`.  It is controlled by the `.timer`.
* example common run times:
  * once a day: `OnCalendar=daily` 
  * every 15 minutes: `OnCalendar=*:0/15`


Copy the script itself somewhere on the path and make it executeable (be sure to update the path in `.service` if you put it somewhere other than the following):

```
cp check-hdfs-space.sh /usr/local/bin
chmod +x /usr/local/bin/check-hdfs-space.sh
```

Copy timer and service to `/etc/systemd/system` and update permissions:

```
cp check-hdfs-space.service /etc/systemd/system
cp check-hdfs-space.timer /etc/systemd/system

chmod 644 /etc/systemd/system/check-hdfs-space.service 
chmod 644 /etc/systemd/system/check-hdfs-space.timer
```

reload systemd to pick up the changes:

```
systemctl daemon-reload
```

enable the timer:

```
$ systemctl enable check-hdfs-space.timer
Created symlink /etc/systemd/system/timers.target.wants/check-hdfs-space.timer → /etc/systemd/system/check-hdfs-space.timer.
```

to check current systemd timers:

```
$ systemctl list-timers --all
NEXT                         LEFT          LAST                         PASSED       UNIT                         ACTIVATES
[... snip ...]
n/a                          n/a           n/a                          n/a          check-hdfs-space.timer       check-hdfs-space.service
[... snip ...]
```

To start timer and run it right now:

```
systemctl start check-hdfs-space.timer
```

if you want to rerun your service manually:

```
systemctl start check-hdfs-space.service
```



## Modifications and other metrics

The bash script intentionally gets the entire output from the jmx and holds it in the `json` variable so that other metrics can be extracted and sent to Zabbix.  


## Why

I wanted a simple way to get some metrics from Hadoop / HDFS and into Zabbix monitoring.  Existing solutions like Apache Ambari were too complex and, after a few hours, I still couldn't get them to talk to each other.  It could be that Ambari doesn't play nice unless it has created the Hadoop cluster itself, which isn't the use case here.

Thus, these scripts.

## Future work

If this works for our use case, increase the robustness, add some error handling, parameterization, etc.