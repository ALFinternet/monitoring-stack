#!/bin/bash

# Stolen from Project = https://gitlab.com/J-C-B/community-splunk-scripts/

# Handy commands for troubleshooting
## tcpdump -i eth0 'port 514'                                                               ## see the flow over a port as events are received (or not)
## /usr/sbin/syslog-ng -F -p /var/run/syslogd.pid                                           ## run syslog-ng and see more errors
## 0 5 * * * /bin/find /var/log/syslogs/ -type f -name \*.log -mtime +1 -exec rm {} \;   ## add this crontab to delete files off every day at 5am older than 1 day
## multitail -s 2 /var/log/syslogs/*/*/*.log  /opt/splunk/var/log/splunk/splunkd.log     ## monitor all the files in the splunk dir
## syslog-ng-ctl stats                                                                      ## See the stats for each filter


# add crontab to delete older log files automatically (optional)
#crontab -l | { cat; echo "0 5 * * * /bin/find /var/log/syslogs/ -type f -name \*.log -mtime +1 -exec rm {} \;"; } | crontab -

# Create users
adduser syslog-ng

# Add users to group required
groupadd syslog
usermod -aG syslog syslog-ng

mkdir /var/log/syslogs
#mkdir /var/log/syslogs/catch_all/

sudo chown -R syslog-ng:syslog /var/log/syslogs

# remove default sysloger
sudo apt erase rsyslog -y

#Add syslog-ng stable
wget -qO - https://ose-repo.syslog-ng.com/apt/syslog-ng-ose-pub.asc | sudo apt-key add -
echo "deb https://ose-repo.syslog-ng.com/apt/ stable ubuntu-focal" | sudo tee -a /etc/apt/sources.list.d/syslog-ng-ose.list

#Update package lists
sudo apt update -y

# Install tools
sudo apt install nano wget tcpdump syslog-ng syslog-ng-core multitail htop iptraf-ng -y

find /usr/share/nano -name '*.nanorc' -printf "include %p\n" > ~/.nanorc

# Create syslog listener config file
echo "
## Created from AF
# syslog-ng configuration file.
# https://www.splunk.com/blog/2016/03/11/using-syslog-ng-with-splunk.html
#
@version: 3.5
    options {
        chain_hostnames(no);
        create_dirs (yes);
        dir_perm(0755);
        dns_cache(yes);
        keep_hostname(yes);
        log_fifo_size(2048);
        log_msg_size(8192);
        perm(0644);
        time_reopen (10);
        use_dns(yes);
        use_fqdn(yes);
        };
    source s_network {
        syslog(transport(udp) port(514));
        };


#Destinations
    destination d_cisco_asa { file(\"/var/log/syslogs/cisco/asa/\$HOST/\$YEAR-\$MONTH-\$DAY-cisco-asa.log\" owner(\"syslog-ng\") group(\"syslog\") perm(0775) create_dirs(yes)); };
    destination d_fortinet { file(\"/var/log/syslogs/fortinet/\$HOST/\$YEAR-\$MONTH-\$DAY-fortigate.log\" owner(\"syslog-ng\") group(\"syslog\") perm(0775) create_dirs(yes)); };
    destination d_juniper { file(\"/var/log/syslogs/juniper/junos/\$HOST/\$YEAR-\$MONTH-\$DAY-juniper-junos.log\" owner(\"syslog-ng\") group(\"syslog\") perm(0775) create_dirs(yes)); };
    destination d_palo_alto { file(\"/var/log/syslogs/paloalto/\$HOST/\$YEAR-\$MONTH-\$DAY-palo.log\" owner(\"syslog-ng\") group(\"syslog\") perm(0775) create_dirs(yes)); };
    destination d_all { file(\"/var/log/syslogs/catch_all/\$HOST/\$YEAR-\$MONTH-\$DAY-catch_all.log\" owner(\"syslog-ng\") group(\"syslog\") perm(0775) create_dirs(yes)); };



# Filters
    filter f_cisco_asa { match(\"%ASA\" value(\"PROGRAM\")) or match(\"%ASA\" value(\"MESSAGE\")); };
    filter f_fortinet { match(\"devid=FG\" value(\"PROGRAM\")) or host(\"msu\") or match(\"devid=FG\" value(\"MESSAGE\")); };
    filter f_juniper { match(\"junos\" value(\"PROGRAM\")) or host(\"Internet\") or host(\"150.1.156.30\") or host(\"150.1.128.10\") or match(\"junos\" value(\"MESSAGE\")) or match(\"RT_FLOW:\" value(\"MESSAGE\")); };
    filter f_palo_alto { match(\"009401000570\" value(\"PROGRAM\")) or match(\"009401000570\" value(\"MESSAGE\")); };
    filter f_all { not (
    filter(f_cisco_asa) or
    filter(f_fortinet) or
    filter(f_juniper) or
    filter(f_palo_alto)
    );
};
# Log
    #log { source(s_network); filter(f_cisco_asa); destination(d_cisco_asa); };
    #log { source(s_network); filter(f_fortinet); destination(d_fortinet); };
    #log { source(s_network); filter(f_juniper); destination(d_juniper); };
    #log { source(s_network); filter(f_palo_alto); destination(d_palo_alto); };
    log { source(s_network); filter(f_all); destination(d_all); };

" >  /etc/syslog-ng/conf.d/listeners_4_syslogs.conf


#enable syslog-ng
sudo systemctl enable syslog-ng
sudo systemctl start syslog-ng

echo "
#################################################################
##########    Installation complete
#################################################################"