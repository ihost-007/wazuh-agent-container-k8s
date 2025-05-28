# Use the slim image of Node.js version 16
FROM ubuntu:latest
RUN apt update && \
    apt install -y gcc curl gpg

RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee -a /etc/apt/sources.list.d/wazuh.list \
    && apt-get update
    # WAZUH_MANAGER="wazuh-workers.wazuh.svc.cluster.local" WAZUH_MANAGER_PORT="1514" WAZUH_REGISTRATION_SERVER="wazuh.wazuh.svc.cluster.local" WAZUH_REGISTRATION_PORT="1515" WAZUH_REGISTRATION_PASSWORD="password" apt install -y wazuh-agent=4.10.1-1

    # apt-cache madison wazuh-agent
   
# Set up the working directory
WORKDIR /var/ossec

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Use the entrypoint script to install Wazuh at runtime
ENTRYPOINT ["/entrypoint.sh"]
