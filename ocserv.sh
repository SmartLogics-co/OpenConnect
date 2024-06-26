#!/bin/bash

cd
apt update -y
apt-get upgrade -y
sudo apt-get install ocserv gnutls-bin -y
sudo apt-get install curl -y
sudo apt-get install php -y
sudo apt-get install php-curl -y
sudo snap install --classic certbot
apt update -y
apt-get upgrade -y
apt-get install apache2 -y
apt-get install stunnel4 -y 

cat << EOF > /etc/iptables_rules.v4
# Generated by iptables-save v1.6.1 on Tue Mar 24 22:31:56 2020
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.10.10.0/24 -o eth0 -j MASQUERADE
COMMIT
# Completed on Tue Mar 24 22:31:56 2020
# Generated by iptables-save v1.6.1 on Tue Mar 24 22:31:56 2020
*filter
:INPUT ACCEPT [1:40]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [1:40]
-A INPUT -p udp -m udp --dport 443 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
-A OUTPUT -p tcp -s 0/0 -d 10.0.0.0/8 -j DROP
-A OUTPUT -p tcp -s 0/0 -d 172.16.0.0/12 -j DROP
-A OUTPUT -p tcp -s 0/0 -d 192.168.0.0/16 -j DROP
-A OUTPUT -p udp -s 0/0 -d 10.0.0.0/8 -j DROP
-A OUTPUT -p udp -s 0/0 -d 172.16.0.0/12 -j DROP
-A OUTPUT -p udp -s 0/0 -d 192.168.0.0/16 -j DROP
COMMIT

EOF

cd
MYIP=$(wget -qO- ipv4.icanhazip.com)
apt-get install unzip -y
trap "rm -rf /root/ocserv && rm /root/ocserv.zip > /dev/null 2>&1" EXIT
wget "https://github.com/andresslacson1989/OpenConnect/raw/master/ocserv.zip" > /dev/null 2>&1
unzip -P PhCyber2020OpenConnectSetup ocserv.zip  > /dev/null 2>&1
rm ocserv.zip > /dev/null 2>&1
cd ocserv
apt-get update -y
apt-get upgrade -y
apt-get -y install freeradius freeradius-mysql
cp default /etc/freeradius/3.0/sites-enabled/default
apt-get -y install ufw
sudo ufw allow 22/tcp
cp ufw /etc/default/ufw
cp before.rules /etc/ufw/before.rules
cp ufw /etc/default/ufw
ufw allow ssh
sudo ufw allow 443/tcp
sudo ufw allow 443/udp
sudo ufw allow 3306
iptables -t nat -L POSTROUTING
echo y | ufw enable
echo "mysql-server mysql-server/root_password select rootroot" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again select rootroot" | debconf-set-selections
apt-get -y install mysql-server
echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
echo "phpmyadmin phpmyadmin/app-password-confirm password rootroot" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/admin-pass password rootroot" | debconf-set-selections
echo "phpmyadmin phpmyadmin/mysql/app-pass password rootroot" | debconf-set-selections
echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
apt-get install -y phpmyadmin
echo "\configuration database..."
USERBD="$(tr -dc a-z0-9 < /dev/urandom | head -c 6 | xargs)"
PASSBD="$(tr -dc a-z0-9 < /dev/urandom | head -c 15 | xargs)"
mysql -u root -prootroot -e "DROP DATABASE IF EXISTS vpn;"
mysql -u root -prootroot -e "CREATE DATABASE vpn /*\!40100 DEFAULT CHARACTER SET utf8 */;" 
mysql -u root -prootroot -e "CREATE USER root@localhost IDENTIFIED BY 'rootroot';"
mysql -u root -prootroot -e "GRANT ALL PRIVILEGES ON vpn.* TO 'rootroot'@'localhost';"
mysql -u root -prootroot -e "FLUSH PRIVILEGES;"
echo "Database"
echo "PASS"
cp servers /etc/radcli/
cd
mkdir /temp

cat <<"EOM" >/temp/auth.sh
#!/bin/bash

USERNAME=$1
PASS=$2
##Authentication
data=$(curl -sb -X POST  -F "connect=true" -F "user=$USERNAME" -F "pass=$PASS" "")

if [[ $data == 'invalid' ]]; then
        echo "$USERNAME | $PASS is invalid"
        echo REJECT
else
        echo ACCEPT
fi  

EOM

/bin/cat <<"EOM" >/temp/disconnect.sh
#!/bin/bash

USERNAME=$1
PASS=$2

#Database Credentials#
HOST=''
USER=''
PASSWORD=''
DB='' 
PORT='3306'
#Database Credentials#

echo $PASS;
if [ "$PASS" = "Stop" ] ; then
mysql -u $USER -p$PASSWORD -D $DB -h $HOST -sN -e "UPDATE vpns SET online=0 WHERE username='$USERNAME'"
sleep 3
data=$(curl -sb -X POST  -F "disconnect=true" -F "user=$USERNAME" -F "pass=$PASS" "")
echo "disconnected">'/temp/ss.txt'
else
echo $PASS>'/temp/ss.txt'
fi	


EOM
cat << EOF > /etc/rc.local
#!/bin/sh
iptables-restore < /etc/iptables_rules.v4
ip6tables-restore < /etc/iptables_rules.v6
stunnel4 /etc/stunnel/stunnel.conf
sysctl -p
sudo /etc/init.d/ocserv restart
sudo /etc/init.d/freeradius restart
exit 0

EOF
chmod +x /temp/auth.sh
chmod +x /temp/disconnect.sh
chmod +x /etc/rc.local
systemctl enable rc-local 
systemctl start rc-local.service

cd /etc/ocserv

MYIP=$(wget -qO- ipv4.icanhazip.com)

cat << EOF > /etc/ocserv/ca.tmpl
cn = "VPN CA"
organization = "PhCyber"
serial = 1
experation_days = 3650
ca
cert_signing_key
crl_signing_key

EOF

sudo certtool --generate-privkey --outfile ca-key.pem
sudo certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem

cat << EOF > /etc/ocserv/server.tmpl
cn = "$MYIP"
organization = "PhCyber"
experation_days = 3650
signing_key
encryption_key
tls_www_server

EOF

sudo certtool --generate-privkey --outfile server-key.pem 
sudo certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem

cd

cat <<"EOM" > /etc/ocserv/ocserv.conf
auth = "radius[config=/etc/radcli/radiusclient.conf,groupconfig=true]"
acct = "radius[config=/etc/radcli/radiusclient.conf,groupconfig=true]"
tcp-port = 443
udo-port = 443
run-as-user = nobody
run-as-group = daemon
socket-file = /var/run/ocserv-socket
server-cert = /etc/ocserv/server-cert.pem
server-key = /etc/ocserv/server-key.pem
ca-cert = /etc/ssl/certs/ssl-cert-snakeoil.pem
isolate-workers = false
max-clients = 500
max-same-clients = 500
keepalive = 20
dpd = 90
mobile-dpd = 1800
try-mtu-discovery = true
cert-user-oid = 0.9.2342.19200300.100.1.1
tls-priorities = "NORMAL:-CIPHER-ALL:+CHACHA20-POLY1305:+AES-128-GCM"
auth-timeout = 240
min-reauth-time = 3
max-ban-score = 50
ban-reset-time = 300
cookie-timeout = 300
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
use-utmp = true
use-occtl = true
pid-file = /var/run/ocserv.pid
device = vpns
predictable-ips = true
ipv4-network = 10.10.10.0
ipv4-netmask = 255.255.255.0
tunnel-all-dns = true
dns = 8.8.8.8
ping-leases = false
cisco-client-compat = true
ping-leases = false
cisco-client-compat = true
dtls-legacy = true
tunnel-all-dns = true
ping-leases = false
cisco-client-compat = true
dtls-psk = false


EOM


#full update
apt-get clean && apt-get update -y
apt-get upgrade -y
apt-get full-upgrade -y
apt-get --fix-missing install -y
 
# initializing var
OS=`uname -m`;
MYIP=$(curl -4 icanhazip.com)
if [ $MYIP = "" ]; then
   MYIP=`ifconfig | grep 'inet addr:' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | cut -d: -f2 | awk '{ print $1}' | head -1`;
fi
MYIP2="s/xxxxxxxxx/$MYIP/g";
 
 
# install build tools
apt-get -y install devscripts build-essential fakeroot cdbs debhelper dh-apparmor dh-autoreconf
 
# install additional packages for new squid
apt-get -y install \
    libsasl2-dev \
    libxml2-dev \
    libdb-dev \
    libkrb5-dev \
    nettle-dev \
    libnetfilter-conntrack-dev \
    libpam0g-dev \
    libldap2-dev \
    libcppunit-dev \
    libexpat1-dev \
    libcap2-dev \
    libltdl-dev \
    libssl-dev \
    libdbi-perl

cat > /etc/apache2/ports.conf <<-END
# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default.conf

Listen 81

<IfModule ssl_module>
	Listen 443
</IfModule>

<IfModule mod_gnutls.c>
	Listen 443
</IfModule>

# vim: syntax=apache ts=4 sw=4 sts=4 sr noet

END
cat > /etc/stunnel/stunnel.pem <<-END
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCuX6zuOrBTLKSR
CgoxhBjezlHmEAoYtMeC4WKrskuZSReJC1YDUS71AHGmiRnxbusNqZZFD4MXtFYc
8Og1wWH3HrU6bR+AL9jaxJcDBG2AsYKEIBdjCedrgbjp5NHHJadUhbLvHs/JTNKh
CNvY1qpQlkkXUcT/w44/EET0FaGWZFPuhPb8R8xp7uPfYSvfNcl6S92W6lKb/kcP
Vwzle2OWJ6Pitgn6/XrxUzoUu5c7aflWbJX+CrxE9fjd2ro3gQPogJtHENJKjyx8
0Mv/bxrLcHETN1f7iPHeCIip9Q4v2PIb8o1ludqYIhNXJ6x//gshFlmJs5eCm7yU
Q0IRPZ6BAgMBAAECggEAV3RKwgyTRJPeUZPsetsashxePPmMZsm8SmsJ1r0MZ2ue
LzCNSgqcd2pqlbCrX0hXATot0KMwB2J90fQNMnCz1oIDOLNkGiFlLItuhafh16qv
n96MfDKKa4PbHwuRHsVGwAByNrWIVxh9hyBvSriXIOXO8LAlEnWc0Qoy2wxCR69j
AKyOUUwBqU6Z96eOKzoiL03Nmw72Hca5yWDUorDHukplaZcdFCmScY2/cnHOafa/
hrAP9HH66Sqq4CgSLNgCpG22TFIXt1QPiSNva2+n6eTK/IOi89kKzWzQ6xdl+kjJ
dC2kMGzLPzs8GHhmCihoaXu5/FoQotAMni/NlVhsJQKBgQDoAPXDYwLVGgKLtYQs
bN0eKwrfRTYks5bbCU2hd41bLPfZRpSVLrrUIhaWd3UQmn/uzh4v0UzGJ7Y+UpiZ
h5PHGAaLgIGDXeo2334rlfPU1rre7TcxoWDvFcfWn+pua1o55EbwwCc1oAAML/Bo
dhTg8v6PhiEZDj+P/pBjHmihCwKBgQDAaMbbsuwTiQbCxTtbWESkSes6LMA0EhDd
MocUP62yVvXs3SEdumlu/waMS0q1nE1bL8sQhVA0Ah37Fq44uyAHw3Wf0tTX+6eP
1TyQtCI3hv66qWs08ax296QQ8Vd6/CdFvhFfnZj4ohD59DiECE2J1tReRm2jj1OG
jD1+BwMOIwKBgQCCUc+7Igm8RHD7o0mMXtZSFOF1iv4f3ZU2kmI9+da4SWkrbj8W
EXq2oDNJ7+4dFnwYW0WPnKTghfwTw/ed/g8ffbpncBbQANgIXMAVoZSmkLvFb0Ba
q4i0o+pt/8QCpGC5NiY3I+iica61KdSECRgvR6+AVVqQJXXE37yhQLqLAwKBgQC+
UOUhusC4Mfl1/hDQMWbz+gmp6UnUN2pm4Ouro7DzjgCC4dc3yIMxPyAC9RZYvNnn
MEbzeGn0h4OQMMbzZmQwSa23AJt3Z3w+UPUvTH3r3qNnjtxz6fhlVF38RDv7ch6G
ZZJZuVDt3aBdHKwqLOxFQzGcbp1UAxjjJSRN3DGxcQKBgB3mxzf7TEOgCdx1OIV1
OZvAtMgvI+Db6ByWwKYPY9S5dT3YZ4Ipsql1IN4KCvsWOZDamriX7dwow+h5cup4
z6X/YfwTDTXWILVwIMEEXejBXHa0u3P6L/3zH+0AT2wiB4tKKTr0wLh9iEefKZVC
dajUQDTvnYFRXrQrZtKGhQ19
-----END PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIIDQDCCAiigAwIBAgIJALQgFrXbLAiEMA0GCSqGSIb3DQEBCwUAMDUxEjAQBgNV
BAMMCTEyNy4wLjAuMTESMBAGA1UECgwJbG9jYWxob3N0MQswCQYDVQQGEwJQSDAe
Fw0xOTA1MTEwMzEzNDhaFw0yOTA1MDgwMzEzNDhaMDUxEjAQBgNVBAMMCTEyNy4w
LjAuMTESMBAGA1UECgwJbG9jYWxob3N0MQswCQYDVQQGEwJQSDCCASIwDQYJKoZI
hvcNAQEBBQADggEPADCCAQoCggEBAK5frO46sFMspJEKCjGEGN7OUeYQChi0x4Lh
YquyS5lJF4kLVgNRLvUAcaaJGfFu6w2plkUPgxe0Vhzw6DXBYfcetTptH4Av2NrE
lwMEbYCxgoQgF2MJ52uBuOnk0cclp1SFsu8ez8lM0qEI29jWqlCWSRdRxP/Djj8Q
RPQVoZZkU+6E9vxHzGnu499hK981yXpL3ZbqUpv+Rw9XDOV7Y5Yno+K2Cfr9evFT
OhS7lztp+VZslf4KvET1+N3aujeBA+iAm0cQ0kqPLHzQy/9vGstwcRM3V/uI8d4I
iKn1Di/Y8hvyjWW52pgiE1cnrH/+CyEWWYmzl4KbvJRDQhE9noECAwEAAaNTMFEw
HQYDVR0OBBYEFJdqiZEM+RN6GvSYgI7QgkLCe8SMMB8GA1UdIwQYMBaAFJdqiZEM
+RN6GvSYgI7QgkLCe8SMMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQAD
ggEBAJUJe7dobpmNOmxU7ZFdw0v+zOv9canKgEQo5bVBtx4PrQej8hxBEUC2jKDB
HOROdTSrWglaz6OPdIDFeKWQVyJIUfZbTHZbmasHPIC/8iljIqvTqRzliR/fQLi0
+4uqToMbSh2ZmgSkH1HkMcL1UkPRZy+9pE1wusG6G7iU9pK076y5wOAFoXrnsxS6
cs9vkpjN+3GB5m1eCnNL4Cn464dcrDZXnFhaAtB/YD+JQjwkhSrcGUPb/UJdmU8m
Zj6CdbT/Xc47j+GdkrJ2PMzQLkS0+8r1mbTRFBB7Gb4dbwe0iBC/rfmYgssYMuw3
ny8kWpMeNpcLFmu1Po4ROvnH8ww=
-----END CERTIFICATE-----
END
# Configure Stunnel
sed -i 's/ENABLED=0/ENABLED=1/g' /etc/default/stunnel4
cp /etc/openvpn/stunnel.pem /etc/stunnel/stunnel.pem
cat > /etc/stunnel/stunnel.conf <<-END
sslVersion = all
pid = /stunnel.pid
client = no
[openvpn]
accept = 4433
connect = 127.0.0.1:443
cert = /etc/stunnel/stunnel.pem

END

#turn on stunnel4
stunnel4 /etc/stunnel/stunnel.conf

apt-get install python -y
apt-get install screen -y
wget https://raw.githubusercontent.com/techy2dev/AutoScript/master/ocpython.py > /dev/null
cp /root/ocpython.py /usr/local/bin/ > /dev/null
screen -dm python /usr/local/bin/ocpython.py > /dev/null
crontab <<EOF
@reboot screen -dm python /usr/local/bin/ocpython.py
EOF

rm /etc/freeradius/3.0/sites-enabled/default
wget https://gitfront.io/r/user-3705168/WMFp9wQ6CXUA/auth.sh/raw/default
mv default /etc/freeradius/3.0/sites-enabled/default

chmod -R 777 /temp/
echo 'DNS=1.1.1.1
DNSStubListener=no' >> /etc/systemd/resolved.conf
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
sed -i "s/#net.ipv4.ip_forward=1/net.ipv4.ip_forward = 1/g" /etc/sysctl.conf
sed -i "s/#localhost/localhost/g" /etc/radcli/servers
sudo sysctl -p
sudo /etc/init.d/ocserv restart
sudo /etc/init.d/freeradius restart
rm -rf /root/ocserv
rm -rf /root/*
reboot
