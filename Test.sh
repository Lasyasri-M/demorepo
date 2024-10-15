#!/bin/bash

# SCP Server details
SCP_SERVER_IP="10.90.105.74"
SCP_PATH="/home/tpx-admin/linux-client-bundle-7-6-1-6481"
TMP_PATH="/tmp/linux-client-bundle-7-6-1-6481"
INSTALLER_NAME="install.sh"

# Prompt for username, password, and target IPs
read -p "Enter username: " uname
read -s -p "Enter password: " pword
echo
read -p "Enter server IPs (separated by commas): " ips

# Convert IPs to an array
IFS=',' read -r -a ip_array <<< "$ips"

# Log directory
log_dir="/home/tpx-admin/Linux_Tanium_Client_Logs"
mkdir -p "$log_dir"

for ip in "${ip_array[@]}"; do
    echo "Processing server $ip..." | tee -a "$log_dir/install_$ip.log"

    # Check if Tanium client service is installed
    echo "Checking if Tanium client is installed..." | tee -a "$log_dir/install_$ip.log"
    service_check=$(sshpass -p "$pword" ssh -o StrictHostKeyChecking=no "$uname@$ip" "systemctl list-units --type=service | grep taniumclient")

    if [[ -z "$service_check" ]]; then
        echo "Tanium client is not installed on $ip. Proceeding with installation..." | tee -a "$log_dir/install_$ip.log"

        # Clean up old files
        echo "Cleaning up old files..." | tee -a "$log_dir/install_$ip.log"
        sshpass -p "$pword" ssh -o StrictHostKeyChecking=no "$uname@$ip" "echo $pword | sudo -S rm -rf /home/tpx-admin/Tanium/TaniumClient" 2>&1 | tee -a "$log_dir/install_$ip.log"

        # Transfer Tanium bundle and fixed pattern files from SCP server
        echo "Copying Tanium installer from SCP server..." | tee -a "$log_dir/install_$ip.log"
        sshpass -p "$pword" scp -o StrictHostKeyChecking=no -r "$uname@$SCP_SERVER_IP:$SCP_PATH" "$uname@$ip:/tmp" 2>&1 | tee -a "$log_dir/install_$ip.log"

        # Ensure target directories exist
        echo "Ensuring target directories exist..." | tee -a "$log_dir/install_$ip.log"
        sshpass -p "$pword" ssh -o StrictHostKeyChecking=no "$uname@$ip" "echo $pword | sudo -S mkdir -p /home/tpx-admin/Tanium/TaniumClient && sudo chmod 775 /home/tpx-admin/Tanium/TaniumClient" 2>&1 | tee -a "$log_dir/install_$ip.log"

        # Copy fixed pattern files
        echo "Copying fixed pattern files..." | tee -a "$log_dir/install_$ip.log"
        sshpass -p "$pword" scp -o StrictHostKeyChecking=no "$uname@$SCP_SERVER_IP:/home/tpx-admin/linux-client-bundle-7-6-1-6481/tanium-init.dat" "$uname@$ip:/home/tpx-admin/Tanium/TaniumClient/" 2>&1 | tee -a "$log_dir/install_$ip.log"

        # Install Tanium client
        echo "Running install.sh..." | tee -a "$log_dir/install_$ip.log"
        sshpass -p "$pword" ssh -o StrictHostKeyChecking=no "$uname@$ip" "cd /tmp/linux-client-bundle-7-6-1-6481 && echo $pword | sudo -S chmod 775 install.sh && sudo -S ./install.sh" 2>&1 | tee -a "$log_dir/install_$ip.log"

        # Copy tanium-init.dat and enable the service
        echo "Enabling taniumclient service..." | tee -a "$log_dir/install_$ip.log"
        sshpass -p "$pword" ssh -o StrictHostKeyChecking=no "$uname@$ip" "echo $pword | sudo -S cp /home/tpx-admin/Tanium/TaniumClient/tanium-init.dat /opt/Tanium/TaniumClient/" 2>&1 | tee -a "$log_dir/install_$ip.log"
        sshpass -p "$pword" ssh -o StrictHostKeyChecking=no "$uname@$ip" "echo $pword | sudo -S systemctl enable taniumclient.service" 2>&1 | tee -a "$log_dir/install_$ip.log"
    else
        echo "Tanium client is already installed on $ip." | tee -a "$log_dir/install_$ip.log"
    fi

    # Check the status of the taniumclient service
    echo "Checking taniumclient service status..." | tee -a "$log_dir/install_$ip.log"
    service_status=$(sshpass -p "$pword" ssh -o StrictHostKeyChecking=no "$uname@$ip" "systemctl is-active taniumclient")

    if [[ "$service_status" == "active" ]]; then
        echo -e "Status of taniumclient service on $ip: \e[32mActive (running)\e[0m" | tee -a "$log_dir/install_$ip.log"
    else
        echo -e "Status of taniumclient service on $ip: \e[31mNot running\e[0m" | tee -a "$log_dir/install_$ip.log"
    fi

    # Display DNS IPs
    echo "DNS IPs from /etc/resolv.conf:" | tee -a "$log_dir/install_$ip.log"
    sshpass -p "$pword" ssh -o StrictHostKeyChecking=no "$uname@$ip" "cat /etc/resolv.conf" | tee -a "$log_dir/install_$ip.log"

    echo "Script execution finished for $ip. Logs are stored in $log_dir/install_$ip.log"
done
