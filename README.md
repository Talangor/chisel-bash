# chisel-bash

- just a shell script to install chisel and set it to create a tunnel to the remote servers (VPN)
- chisel is not my code you can find it at https://github.com/jpillora/chisel
- my bash script works with ubuntu and Debian
- was a hastily written code and I'm planning to write an ansible playbook later on

# instructons

## remote:
- run chisel-remote.sh in remote country VPS it asks for a port for listening to, i suggest 443, it also installs squid for proxying traffic
- creates a service named chisel you can see its status by running systemctl status chisel 
- copy **FINGERPRINT** for later use

## local: 
- run chisel-local.sh in the local host and asks for the remote port , remote IP address, and fingerprint you just copied from the remote host
- this bash script installs danted which will listen on port 443 
- creates a service for establishing a tunnel with the remote server
- port 3128 and 53 will be tunneled through chisel 
- it also disables systemd-resolved because we need port 53 to be available
- sets ufw firewall to deny by default and allows 443/tcp and 22/tcp
**note:** if your machine is listening on another port for ssh change **ufw allow 22/tcp**

## user creation
- useradd -M UserName
- passwd UserName
- to connect you could use any **socks5** client and set local server and its port supplied with user and password


**Special thanks to jpillora**

