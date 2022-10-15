#!/bin/bash
ETH=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
read -p 'remote IP Address: ' IPADDR
read -p 'remote port: ' RPORT
read -p 'remote finger print: ' FP
apt update
apt install dante-server python3 git -qqy
git clone https://github.com/Talangor/chisel-bash.git
mv chisel-bash/chisel /usr/local/bin
chmod +x /usr/chisel/bin/chisel

cat <<EOT > /usr/local/bin/proxy.py
import urllib.request
import socket
import urllib.error
import os
import datetime
def is_bad_proxy(pip):
    try:
        proxy_handler = urllib.request.ProxyHandler({'https': pip})
        opener = urllib.request.build_opener(proxy_handler)
        opener.addheaders = [('User-agent', 'Mozilla/5.0')]
        urllib.request.install_opener(opener)
        req=urllib.request.Request('https://www.youtube.com')  # change the URL to test here
        sock=urllib.request.urlopen(req)
    except urllib.error.HTTPError as e:
        print('Error code: ', e.code)
        return e.code
    except Exception as detail:
        print("ERROR:", detail)
        return True
    return False

def main():
    socket.setdefaulttimeout(120)
    now = datetime.datetime.now()
    # two sample proxy IPs
    proxyList = ['127.0.0.1:3128']

    for currentProxy in proxyList:
        if is_bad_proxy(currentProxy):
            print(now, "Bad Proxy %s" % (currentProxy))
            os.system("systemctl restart chisel")
        else:
            print(now, "%s is working" % (currentProxy))

if __name__ == '__main__':
    main()
EOT

cat <<EOT > /usr/local/bin/chisel.sh
#!/bin/bash
chisel client --fingerprint $FP $IPADDR:$RPORT  localhost:3128 1.1.1.1:53/udp
EOT

cat <<EOT > /usr/local/bin/chisel-cron.sh
#!/bin/bash
python3 /usr/local/bin/proxy.py

EOT

touch /var/log/chisel.log
cat <<EOT >> /etc/crontab
*/2 * * * * root /usr/local/bin/chisel-cron.sh >> /var/log/chisel.log
EOT
cat <<EOT > /etc/systemd/system/chisel.service
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/chisel.sh

[Install]
WantedBy=default.target
EOT
systemctl daemon-reload

chmod +x /usr/local/bin/chisel.sh
systemctl enable chisel
systemctl restart chisel

#touch /var/log/sockd.log
cat <<EOT > /etc/danted.conf
errorlog: syslog
#logoutput: /var/log/sockd.log
internal: $ETH port = 443
external: $ETH
socksmethod: username #rfc931 none
user.privileged: root
user.unprivileged: nobody
client pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        log: error connect disconnect
        socksmethod: username
}
socks pass {
        from: 0.0.0.0/0 to: 0.0.0.0/0
        command: connect bind bindreply udpreply
        log: error connect disconnect
        socksmethod: username
}
route {
        from: 0.0.0.0/0 to: 0.0.0.0/0 via: 127.0.0.1 port = 3128
        proxyprotocol: http_v1.0
        command: connect
}
EOT

systemctl mask systemd-resolved
systemctl stop systemd-resolved
cat 'nameserver 127.0.0.1' > /etc/resolv.conf
systemctl status chisel

