#!/bin/bash

read -p 'port: ' LPORT
apt update
apt install squid -qqy

if [ "$DEBUG" == "1" ]; then
	set -x
fi
TMP_DIR=$(mktemp -d -t jpillora-installer-XXXXXXXXXX)
function cleanup {
	echo rm -rf $TMP_DIR > /dev/null
}
function fail {
	cleanup
	msg=$1
	echo "============"
	echo "Error: $msg" 1>&2
	exit 1
}
function install {
	#settings
	USER="jpillora"
	PROG="chisel"
	MOVE="true"
	RELEASE="v1.7.7"
	INSECURE="false"
	OUT_DIR="/usr/local/bin"
	GH="https://github.com"
	#bash check
	[ ! "$BASH_VERSION" ] && fail "Please use bash instead"
	[ ! -d $OUT_DIR ] && fail "output directory missing: $OUT_DIR"
	#dependency check, assume we are a standard POISX machine
	which find > /dev/null || fail "find not installed"
	which xargs > /dev/null || fail "xargs not installed"
	which sort > /dev/null || fail "sort not installed"
	which tail > /dev/null || fail "tail not installed"
	which cut > /dev/null || fail "cut not installed"
	which du > /dev/null || fail "du not installed"
	GET=""
	if which curl > /dev/null; then
		GET="curl"
		if [[ $INSECURE = "true" ]]; then GET="$GET --insecure"; fi
		GET="$GET --fail -# -L"
	elif which wget > /dev/null; then
		GET="wget"
		if [[ $INSECURE = "true" ]]; then GET="$GET --no-check-certificate"; fi
		GET="$GET -qO-"
	else
		fail "neither wget/curl are installed"
	fi
	#find OS #TODO BSDs and other posixs
	case `uname -s` in
	Darwin) OS="darwin";;
	Linux) OS="linux";;
	*) fail "unknown os: $(uname -s)";;
	esac
	#find ARCH
	if uname -m | grep arm64 > /dev/null; then
		# this case only included if arm64 assets are present
		# to allow fallback to amd64 (m1 rosetta TODO darwin check)
		ARCH="arm64"
	elif uname -m | grep 64 > /dev/null; then
		ARCH="amd64"
	elif uname -m | grep arm > /dev/null; then
		ARCH="arm" #TODO armv6/v7
	elif uname -m | grep 386 > /dev/null; then
		ARCH="386"
	else
		fail "unknown arch: $(uname -m)"
	fi
	#choose from asset list
	URL=""
	FTYPE=""
	case "${OS}_${ARCH}" in
	"darwin_amd64")
		URL="https://github.com/jpillora/chisel/releases/download/v1.7.7/chisel_1.7.7_darwin_amd64.gz"
		FTYPE=".gz"
		;;
	"darwin_arm64")
		URL="https://github.com/jpillora/chisel/releases/download/v1.7.7/chisel_1.7.7_darwin_arm64.gz"
		FTYPE=".gz"
		;;
	"linux_386")
		URL="https://github.com/jpillora/chisel/releases/download/v1.7.7/chisel_1.7.7_linux_386.gz"
		FTYPE=".gz"
		;;
	"linux_amd64")
		URL="https://github.com/jpillora/chisel/releases/download/v1.7.7/chisel_1.7.7_linux_amd64.gz"
		FTYPE=".gz"
		;;
	"linux_arm64")
		URL="https://github.com/jpillora/chisel/releases/download/v1.7.7/chisel_1.7.7_linux_arm64.gz"
		FTYPE=".gz"
		;;
	"linux_arm")
		URL="https://github.com/jpillora/chisel/releases/download/v1.7.7/chisel_1.7.7_linux_armv6.gz"
		FTYPE=".gz"
		;;
	*) fail "No asset for platform ${OS}-${ARCH}";;
	esac
	#got URL! download it...
	echo -n "Installing"
	echo -n " $USER/$PROG"
	if [ ! -z "$RELEASE" ]; then
		echo -n " $RELEASE"
	fi
	echo -n " (${OS}/${ARCH})"
	
	echo "....."
	
	#enter tempdir
	mkdir -p $TMP_DIR
	cd $TMP_DIR
	if [[ $FTYPE = ".gz" ]]; then
		which gzip > /dev/null || fail "gzip is not installed"
		#gzipped binary
		NAME="${PROG}_${OS}_${ARCH}.gz"
		GZURL="$GH/releases/download/$RELEASE/$NAME"
		#gz download!
		bash -c "$GET $URL" | gzip -d - > $PROG || fail "download failed"
	elif [[ $FTYPE = ".tar.bz" ]] || [[ $FTYPE = ".tar.bz2" ]]; then
		which tar > /dev/null || fail "tar is not installed"
		which bzip2 > /dev/null || fail "bzip2 is not installed"
		bash -c "$GET $URL" | tar jxf - || fail "download failed"
	elif [[ $FTYPE = ".tar.gz" ]] || [[ $FTYPE = ".tgz" ]]; then
		which tar > /dev/null || fail "tar is not installed"
		which gzip > /dev/null || fail "gzip is not installed"
		bash -c "$GET $URL" | tar zxf - || fail "download failed"
	elif [[ $FTYPE = ".zip" ]]; then
		which unzip > /dev/null || fail "unzip is not installed"
		bash -c "$GET $URL" > tmp.zip || fail "download failed"
		unzip -o -qq tmp.zip || fail "unzip failed"
		rm tmp.zip || fail "cleanup failed"
	elif [[ $FTYPE = "" ]]; then
		bash -c "$GET $URL" > "chisel_${OS}_${ARCH}" || fail "download failed"
	else
		fail "unknown file type: $FTYPE"
	fi
	#search subtree largest file (bin)
	TMP_BIN=$(find . -type f | xargs du | sort -n | tail -n 1 | cut -f 2)
	if [ ! -f "$TMP_BIN" ]; then
		fail "could not find find binary (largest file)"
	fi
	#ensure its larger than 1MB
	#TODO linux=elf/darwin=macho file detection?
	if [[ $(du -m $TMP_BIN | cut -f1) -lt 1 ]]; then
		fail "no binary found ($TMP_BIN is not larger than 1MB)"
	fi
	#move into PATH or cwd
	chmod +x $TMP_BIN || fail "chmod +x failed"
	#move without sudo
	OUT=$(mv $TMP_BIN $OUT_DIR/$PROG 2>&1)
	STATUS=$?
	# failed and string contains "Permission denied"
	if [ $STATUS -ne 0 ]; then
		if [[ $OUT =~ "Permission denied" ]]; then
			echo "mv with sudo..."
			sudo mv $TMP_BIN $OUT_DIR/$PROG || fail "sudo mv failed" 
		else
			fail "mv failed ($OUT)"
		fi
	fi
	echo "Installed at $OUT_DIR/$PROG"
	#done
	cleanup
}
install
cat <<EOT > /etc/squid/squid.conf
acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http
cache deny all
max_filedesc 4096
http_access allow localhost
include /etc/squid/conf.d/*.conf
http_access allow localhost
http_access deny all
http_port 3128
access_log none
coredump_dir /var/spool/squid
refresh_pattern ^ftp:		1440	20%	10080
refresh_pattern ^gopher:	1440	0%	1440
refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
refresh_pattern \/(Packages|Sources)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern \/Release(|\.gpg)$ 0 0% 0 refresh-ims
refresh_pattern \/InRelease$ 0 0% 0 refresh-ims
refresh_pattern \/(Translation-.*)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern .		0	20%	4320
EOT

systemctl enable squid
systemctl restart squid
cat <<EOT > /etc/sysctl.conf
fs.file-max = 65535
EOT
sysctl -p
cat <<EOT > /etc/systemd/system/chisel.service
[Unit]
After=network.service

[Service]
ExecStart=/usr/local/bin/chisel.sh

[Install]
WantedBy=default.target
EOT

systemctl daemon-reload

echo <<EOT > /usr/local/bin/chisel.sh
#!/bin/bash
chisel server --key U1az6MwSkoPt6DxS5t+t5CBdF4yO6YWkwZFqlVqXZHC= -p $LPORT
EOT

chmod +x /usr/local/bin/chisel.sh
systemctl enable chisel
systemctl restart chisel

systemctl status chisel
