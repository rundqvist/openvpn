#!/bin/sh

provider=$(var VPN_PROVIDER)
COUNTRY=$1
TUN=$dev
IP=$ifconfig_local

log -v "on-up.sh country: $COUNTRY, tun: $TUN, ip: $IP"

#
# Do we have an IP?
#
if [ -z "$IP" ]
then
    log -e "No IP. Forcing reconnect..."
    exit 1;
else
    log -i "Connected. Assigned IP is: $IP."
fi

#
# Remove killswitch (if any)
#
if [ "$(var VPN_KILLSWITCH)" = "true" ]
then
    log -d "Removing killswitch config."

    iptables -P OUTPUT ACCEPT
    iptables -D OUTPUT -p udp -m udp --dport $(var VPN_PORT) -j ACCEPT
    iptables -D INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -D OUTPUT -o tun0 -j ACCEPT
    NS=$(cat /etc/resolv.conf | grep "nameserver" | sed 's/nameserver \(.*\)/\1/g')

    for s in $NS
    do
        iptables -D OUTPUT -d $s -j ACCEPT
    done
fi

host=$(/app/openvpn/provider/$provider.sh -e host -c $COUNTRY)

log -i "Vpn ($COUNTRY) is up. Connected remote: $host."

#
# Find all on-openvpn-up.sh files
#
EVENTS=$(find /app/*/ -type f -name on-openvpn-up.sh)

for filepath in $EVENTS
do
    #
    # Ensure execution rights and execute file
    #
    log -v "Executing $filepath $COUNTRY $TUN $IP."
    chmod +x $filepath    
    $filepath $COUNTRY $TUN $IP

    #
    # Check outcome
    #
    if [ $? -eq 1 ]
    then
        log -d "$filepath $COUNTRY $TUN $IP failed.";
        exit 1;
    fi
done

exit 0;