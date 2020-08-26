#!/bin/sh

DATE_CURRENT=$(date +%d)
DATE_UPDATED=$(cat /cache/openvpn/ipvanish/date_updated 2>/dev/null)

if [ "$DATE_CURRENT" != "$DATE_UPDATED" ]; then

    log -i "Updating ipvanish config"

    mkdir -p /cache/openvpn/ipvanish
    rm -f /cache/openvpn/ipvanish/configs.zip

    wget -q https://www.ipvanish.com/software/configs/configs.zip -P /cache/openvpn/ipvanish/ 2>/dev/null
    RC=$?
    if [ $RC -eq 1 ]; then
        log -w "Failed to download new config"
    else

        log -i "Unzipping"
        unzip -q -o /cache/openvpn/ipvanish/configs.zip -d /cache/openvpn/ipvanish/

        echo $DATE_CURRENT > /cache/openvpn/ipvanish/date_updated
    fi
    #
    # Restart vpn
    #
    #echo "Restarting"  >> /var/log/healthcheck.log
    #killall -s HUP openvpn
fi


cp -f /cache/openvpn/ipvanish/ca.ipvanish.com.crt /app/openvpn/

VPN_COUNTRY=$VPN_COUNTRY
if [ "$VPN_COUNTRY" = "GB" ] ; then
    VPN_COUNTRY="UK";

    log -i "Translating country to 'UK' since IPVanish differs from ISO 3166-1 alpha-2"
fi

if [ -z "$(find /cache/openvpn/ipvanish/ -name "*-${VPN_COUNTRY}-*")" ] ; then
    log -e "No config files found for country '$VPN_COUNTRY'. See https://hub.docker.com/r/rundqvist/openvpn for configuration."
    exit 1;
fi

#
# Copy one config file as template
#
find /cache/openvpn/ipvanish/ -name "*-${VPN_COUNTRY}-*" -print | head -1 | xargs -I '{}' cp {} /app/openvpn/config.ovpn

#
# Remove remote and verify-x509-name
#
sed -i '/remote /d' /app/openvpn/config.ovpn
sed -i '/verify-x509-name /d' /app/openvpn/config.ovpn

sed -i 's/^ca \(.*\)/ca \/app\/openvpn\/\1/g' /app/openvpn/config.ovpn
sed -i 's/^auth-user-pass/auth-user-pass \/app\/openvpn\/auth.conf/g' /app/openvpn/config.ovpn
echo 'tls-verify "/app/openvpn/tls-verify.sh /app/openvpn/allowed.remotes"' >> /app/openvpn/config.ovpn
echo "mute-replay-warnings" >> /app/openvpn/config.ovpn

#
# Create list of allowed remotes
#
find /cache/openvpn/ipvanish/ -name "*${VPN_COUNTRY}*" -exec sed -n -e 's/^remote \(.*\) \(.*\)/\1/p' {} \; | sort > /app/openvpn/allowed.remotes

if [ "$VPN_INCLUDED_REMOTES" != "" ]; then

    for s in $VPN_INCLUDED_REMOTES ; do
        echo $s
    done | sort > /app/openvpn/included.remotes

    comm /app/openvpn/allowed.remotes /app/openvpn/included.remotes -12 > /app/openvpn/tmp.remotes  
    rm -f /app/openvpn/included.remotes
    mv -f /app/openvpn/tmp.remotes /app/openvpn/allowed.remotes
    
fi

if [ "$VPN_EXCLUDED_REMOTES" != "" ]; then

    for s in $VPN_EXCLUDED_REMOTES ; do
        echo $s
    done | sort > /app/openvpn/excluded.remotes

    comm /app/openvpn/allowed.remotes /app/openvpn/excluded.remotes -23 > /app/openvpn/tmp.remotes  
    rm -f /app/openvpn/excluded.remotes
    mv -f /app/openvpn/tmp.remotes /app/openvpn/allowed.remotes
    
fi

#
#  Make sure list is not too long
#
echo "$(tail -n 32 /app/openvpn/allowed.remotes)" > /app/openvpn/allowed.remotes

#
# Add allowed remotes as remotes
#
find /app/openvpn/ -name "allowed.remotes" -exec sed -n -e 's/^\(.*\)/remote \1 443/p' {} \; >> /app/openvpn/config.ovpn

#
# Random remote
#
if [ "$VPN_RANDOM_REMOTE" = "true" ]; then
	echo 'remote-random' >> /app/openvpn/config.ovpn
fi

exit 0;
