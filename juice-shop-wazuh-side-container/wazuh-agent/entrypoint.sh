#!/bin/bash
set -e

echo "Starting Wazuh Agent Setup..."

# Ensure that the 'wazuh' group exists, and create it if it doesn't
if ! getent group wazuh >/dev/null; then
    echo "Creating group 'wazuh'..."
    groupadd -r wazuh
fi

# Ensure that the 'wazuh' user exists, and create it if it doesn't
if ! id -u wazuh >/dev/null 2>&1; then
    echo "Creating user 'wazuh'..."
    useradd -r -g wazuh -d /var/ossec -s /bin/false wazuh
fi

# Ensure proper ownership on /var/ossec and subdirectories
find /var/ossec -path /var/ossec/etc/authd.pass -prune -o -exec chown wazuh:wazuh {} +
# find /var/ossec \( -path /var/ossec/etc/authd.pass -o -path /var/ossec/etc/ossec.conf \) -prune -o -exec chown wazuh:wazuh {} +

# Set execute permissions on the binary, if not already set.
if [ -f "/var/ossec/bin/wazuh-control" ]; then
    chmod +x /var/ossec/bin/wazuh-control
fi

# Check if Wazuh is already installed
if [ ! -f "/var/ossec/bin/wazuh-control" ]; then
    echo "Wazuh agent not found. Installing..."
    apt update && \
    JOIN_MANAGER_API_PORT="55000" WAZUH_MANAGER="wazuh-workers.wazuh.svc.cluster.local" WAZUH_MANAGER_PORT="1514" WAZUH_REGISTRATION_SERVER="wazuh.wazuh.svc.cluster.local" WAZUH_REGISTRATION_PORT="1515" WAZUH_REGISTRATION_PASSWORD="password" apt install -y wazuh-agent=4.10.1-1

    # Ensure the authentication password is set
    if [ -f "/var/ossec/etc/authd.pass" ]; then
        echo "Using provided authd.pass from secret."
    else
        echo "Error: authd.pass file is missing!"
        exit 1
    fi

cat <<EOF > /var/ossec/etc/ossec.conf
# replaced
<ossec_config>
  <client>
    <server>
      <address>wazuh-workers.wazuh.svc.cluster.local</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>ubuntu, ubuntu24, ubuntu24.04</config-profile>
    <notify_time>10</notify_time>
    <time-reconnect>60</time-reconnect>
    <auto_restart>yes</auto_restart>
    <crypto_method>aes</crypto_method>
    <enrollment>
      <enabled>yes</enabled>
      <manager_address>wazuh.wazuh.svc.cluster.local</manager_address>
      <port>1515</port>
      <authorization_pass_path>etc/authd.pass</authorization_pass_path>
    </enrollment>
  </client>

  <client_buffer>
    <!-- Agent buffer options -->
    <disabled>no</disabled>
    <queue_size>5000</queue_size>
    <events_per_second>500</events_per_second>
  </client_buffer>

  <!-- Policy monitoring -->
  <rootcheck>
    <disabled>no</disabled>
    <check_files>yes</check_files>
    <check_trojans>yes</check_trojans>
    <check_dev>yes</check_dev>
    <check_sys>yes</check_sys>
    <check_pids>yes</check_pids>
    <check_ports>yes</check_ports>
    <check_if>yes</check_if>

    <!-- Frequency that rootcheck is executed - every 12 hours -->
    <frequency>900</frequency>

    <rootkit_files>etc/shared/rootkit_files.txt</rootkit_files>
    <rootkit_trojans>etc/shared/rootkit_trojans.txt</rootkit_trojans>

    <skip_nfs>no</skip_nfs>

    <ignore>/var/lib/containerd</ignore>
    <ignore>/var/lib/docker/overlay2</ignore>
  </rootcheck>

  <wodle name="cis-cat">
    <disabled>no</disabled>
    <timeout>1800</timeout>
    <interval>10m</interval>
    <scan-on-start>yes</scan-on-start>

    <java_path>wodles/java</java_path>
    <ciscat_path>wodles/ciscat</ciscat_path>
  </wodle>

  <!-- Osquery integration -->
  <wodle name="osquery">
    <disabled>yes</disabled>
    <run_daemon>yes</run_daemon>
    <log_path>/var/log/osquery/osqueryd.results.log</log_path>
    <config_path>/etc/osquery/osquery.conf</config_path>
    <add_labels>yes</add_labels>
  </wodle>

  <!-- System inventory -->
  <wodle name="syscollector">
    <disabled>no</disabled>
    <interval>10m</interval>
    <scan_on_start>yes</scan_on_start>
    <hardware>yes</hardware>
    <os>yes</os>
    <network>yes</network>
    <packages>yes</packages>
    <ports all="yes">yes</ports>
    <processes>yes</processes>

    <!-- Database synchronization settings -->
    <synchronization>
      <max_eps>10</max_eps>
    </synchronization>
  </wodle>

  <sca>
    <enabled>yes</enabled>
    <scan_on_start>yes</scan_on_start>
    <interval>10m</interval>
    <skip_nfs>no</skip_nfs>
  </sca>

  <!-- File integrity monitoring -->
  <syscheck>
    <disabled>no</disabled>

    <!-- Frequency that syscheck is executed default every 12 hours -->
    <frequency>900</frequency>

    <scan_on_start>yes</scan_on_start>

    <!-- Directories to check  (perform all possible verifications) -->
    <directories>/etc,/usr/bin,/usr/sbin</directories>
    <directories>/bin,/sbin,/boot</directories>

    <!-- Files/directories to ignore -->
    <ignore>/etc/mtab</ignore>
    <ignore>/etc/hosts.deny</ignore>
    <ignore>/etc/mail/statistics</ignore>
    <ignore>/etc/random-seed</ignore>
    <ignore>/etc/random.seed</ignore>
    <ignore>/etc/adjtime</ignore>
    <ignore>/etc/httpd/logs</ignore>
    <ignore>/etc/utmpx</ignore>
    <ignore>/etc/wtmpx</ignore>
    <ignore>/etc/cups/certs</ignore>
    <ignore>/etc/dumpdates</ignore>
    <ignore>/etc/svc/volatile</ignore>

    <!-- File types to ignore -->
    <ignore type="sregex">.log$|.swp$</ignore>

    <!-- Check the file, but never compute the diff -->
    <nodiff>/etc/ssl/private.key</nodiff>

    <skip_nfs>no</skip_nfs>
    <skip_dev>no</skip_dev>
    <skip_proc>no</skip_proc>
    <skip_sys>no</skip_sys>

    <!-- Nice value for Syscheck process -->
    <process_priority>10</process_priority>

    <!-- Maximum output throughput -->
    <max_eps>50</max_eps>

    <!-- Database synchronization settings -->
    <synchronization>
      <enabled>yes</enabled>
      <interval>5m</interval>
      <max_eps>10</max_eps>
    </synchronization>

    <directories check_all="yes" whodata="yes" realtime="yes">/Users</directories>
    <directories check_all="yes" whodata="yes" realtime="yes">/home</directories>
  </syscheck>

  <!-- Log analysis -->
  <localfile>
    <log_format>command</log_format>
    <command>df -P</command>
    <frequency>360</frequency>
  </localfile>

  <localfile>
    <log_format>full_command</log_format>
    <command>netstat -tulpn | sed 's/\([[:alnum:]]\+\)\ \+[[:digit:]]\+\ \+[[:digit:]]\+\ \+\(.*\):\([[:digit:]]*\)\ \+\([0-9\.\:\*]\+\).\+\ \([[:digit:]]*\/[[:alnum:]\-]*\).*/\1 \2 == \3 == \4 \5/' | sort -k 4 -g | sed 's/ == \(.*\) ==/:\1/' | sed 1,2d</command>
    <alias>netstat listening ports</alias>
    <frequency>360</frequency>
  </localfile>

  <localfile>
    <log_format>full_command</log_format>
    <command>last -n 20</command>
    <frequency>360</frequency>
  </localfile>

  <!-- Active response -->
  <active-response>
    <disabled>no</disabled>
    <ca_store>etc/wpk_root.pem</ca_store>
    <ca_verification>yes</ca_verification>
  </active-response>

  <!-- Choose between "plain", "json", or "plain,json" for the format of internal logs -->
  <logging>
    <log_format>plain</log_format>
  </logging>

</ossec_config>

<ossec_config>
  <localfile>
    <log_format>syslog</log_format>
    <location>/var/ossec/logs/active-responses.log</location>
  </localfile>

  <localfile>
    <log_format>syslog</log_format>
    <location>/var/log/dpkg.log</location>
  </localfile>

</ossec_config>
EOF

else
    echo "Wazuh agent is already installed. Skipping installation."
fi

# Start Wazuh agent
echo "Starting Wazuh Agent..."
JOIN_MANAGER_API_PORT="55000" WAZUH_MANAGER="wazuh-workers.wazuh.svc.cluster.local" WAZUH_MANAGER_PORT="1514" WAZUH_REGISTRATION_SERVER="wazuh.wazuh.svc.cluster.local" WAZUH_REGISTRATION_PORT="1515" WAZUH_REGISTRATION_PASSWORD="password" /var/ossec/bin/wazuh-control start
# su -s /bin/bash -c "/var/ossec/bin/wazuh-control start" wazuh

# Keep container running and show logs
tail -f /var/ossec/logs/ossec.log
