# !/usr/bin/env bash


header_info() {
    clear
    cat <<"EOF"
       ________  _______   ________  ___  ________  ________           ________  ________  ________  _________  ___  ________   ________  _________  ________  ___       ___          
      |\   ___ \|\  ___ \ |\   __  \|\  \|\   __  \|\   ___  \        |\   __  \|\   __  \|\   ____\|\___   ___\\  \|\   ___  \|\   ____\|\___   ___\\   __  \|\  \     |\  \         
      \ \  \_|\ \ \   __/|\ \  \|\ /\ \  \ \  \|\  \ \  \\ \  \       \ \  \|\  \ \  \|\  \ \  \___|\|___ \  \_\ \  \ \  \\ \  \ \  \___|\|___ \  \_\ \  \|\  \ \  \    \ \  \        
       \ \  \ \\ \ \  \_|/_\ \   __  \ \  \ \   __  \ \  \\ \  \       \ \   ____\ \  \\\  \ \_____  \   \ \  \ \ \  \ \  \\ \  \ \_____  \   \ \  \ \ \   __  \ \  \    \ \  \       
        \ \  \_\\ \ \  \_|\ \ \  \|\  \ \  \ \  \ \  \ \  \\ \  \       \ \  \___|\ \  \\\  \|____|\  \   \ \  \ \ \  \ \  \\ \  \|____|\  \   \ \  \ \ \  \ \  \ \  \____\ \  \____  
         \ \_______\ \_______\ \_______\ \__\ \__\ \__\ \__\\ \__\       \ \__\    \ \_______\____\_\  \   \ \__\ \ \__\ \__\\ \__\____\_\  \   \ \__\ \ \__\ \__\ \_______\ \_______\
          \|_______|\|_______|\|_______|\|__|\|__|\|__|\|__| \|__|        \|__|     \|_______|\_________\   \|__|  \|__|\|__| \|__|\_________\   \|__|  \|__|\|__|\|_______|\|_______|
                                                                                              \|_________|                         \|_________|                                        
EOF
}

get_interfaces_info() {
    INTERFACES=()
    while IFS= read -r line; do
        # Extract interface name
        IFACE=$(echo "$line" | awk -F': ' '{print $2}' | awk '{print $1}')
        
        # Check if interface is up or down
        STATUS=$(echo "$line" | grep -o 'state [A-Z]*' | awk '{print $2}')
        [ -z "$STATUS" ] && STATUS="DOWN"

        # Get the IP address (both IPv4 and IPv6) associated with the interface
        IP_ADDR=$(ip addr show "$IFACE" | awk '/inet / {print $2}' | head -1)
        [ -z "$IP_ADDR" ] && IP_ADDR=$(ip addr show "$IFACE" | awk '/inet6 / {print $2}' | head -1)
        [ -z "$IP_ADDR" ] && IP_ADDR="No IP assigned"

        # Check if the interface is using DHCP or static IP
        if systemctl list-units --type=service | grep -q "dhclient@$IFACE.service"; then
            IP_TYPE="DHCP"
        else
            IP_TYPE="Static"
        fi

        # Prepare the menu entry
        MENU_ENTRY="$IFACE (Status: $STATUS, IP: $IP_ADDR, Type: $IP_TYPE)"
        INTERFACES+=("$IFACE" "$MENU_ENTRY")
    done < <(ip link show | grep -E '^[0-9]+: ')
}

configure_interfaces() {
    get_interfaces_info
    CHOICE=$(whiptail --backtitle "Debian Post Install Script" --title "Configure Interfaces" --menu "Select an interface below to configure it" 20 70 10 "${INTERFACES[@]}" 3>&1 1>&2 2>&3)
    
    # Check for cancellation (empty CHOICE)
    if [ -z "$CHOICE" ]; then
        echo "No interface selected or operation cancelled."
        exit 1
    fi

    edit_interface "$CHOICE"
}

start_script() {
    header_info
    sleep 1
    if (whiptail --backtitle "Debian Post Install Script" --title "Network Configuration" --yesno "Configure Network Interfaces?" 8 78
    ); then 
        configure_interfaces
    else
        echo "Network configuration skipped."
    fi

}


edit_interface() {
    IFACE=$1

    # DHCP or Static
    CHOICE=$(whiptail --title "Configure $IFACE" --menu "Choose IP configuration type:" 15 50 2 \
    "DHCP" "Automatic IP address" \
    "Static" "Manual IP address" 3>&1 1>&2 2>&3)

    # Check if the user selected an option or cancelled
    if [ $? -ne 0 ]; then
        echo "Configuration cancelled."
        exit 1
    fi

    if [ "$CHOICE" == "Static" ]; then
        # Get Static IP configuration
        IP_ADDR=$(whiptail --inputbox "Enter IP address for $IFACE:" 10 60 3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && exit 1

        NETMASK=$(whiptail --inputbox "Enter netmask for $IFACE:" 10 60 255.255.255.0 3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && exit 1

        GATEWAY=$(whiptail --inputbox "Enter default gateway for $IFACE:" 10 60 3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && exit 1

        DNS_SERVERS=$(whiptail --inputbox "Enter DNS servers (comma separated):" 10 60 8.8.8.8,8.8.4.4 3>&1 1>&2 2>&3)
        [ $? -ne 0 ] && exit 1

        echo "Static IP configuration for $IFACE:"
        echo "IP Address: $IP_ADDR"
        echo "Netmask: $NETMASK"
        echo "Gateway: $GATEWAY"
        echo "DNS Servers: $DNS_SERVERS"

        # Here you would apply the static configuration
        # apply_static_config "$IFACE" "$IP_ADDR" "$NETMASK" "$GATEWAY" "$DNS_SERVERS"

    else
        echo "DHCP configuration selected for $IFACE."
        # Here you would apply the DHCP configuration
        # apply_dhcp_config "$IFACE"
    fi
}



start_script