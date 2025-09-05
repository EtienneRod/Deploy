#!/bin/bash

# Set temporary PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;
export PATH="$PATH:test";

# From HYPER
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)"
# Container Type: Unprivileged
# Hostname: NETSERVICES
# Disk: 10G  Core: 4  RAM : 4096
# IPV4: 172.27.27.37/24  GW: 172.27.27.1  Domain: home.famillerg.com DNS: 172.27.27.1 

# Load sensitives info from variables.env in order to not hardcode them in files push to GitHub
# Variable list
  # $pushoveremail
  # $myemail
export $(grep -v '^#' variables.env | xargs);

adduser --allow-bad-names Etienne;
echo $'Etienne ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers;

mkdir -p /home/Etienne/.ssh && chmod 700 /home/Etienne/.ssh;
scp -i /home/Etienne/.ssh/id_rsa Etienne@172.27.27.32:/mnt/Share/Configurations/SSH/id_rsa /home/Etienne/.ssh/id_rsa;
scp -i /home/Etienne/.ssh/id_rsa Etienne@172.27.27.32:/mnt/Share/Configurations/SSH/authorized_keys /home/Etienne/.ssh/authorized_keys;
scp -i /home/Etienne/.ssh/id_rsa Etienne@172.27.27.32:/mnt/Share/Configurations/SSH/id_rsa.pub /home/Etienne/.ssh/id_rsa.pub;
chown -R Etienne:Etienne /home/Etienne/.ssh && chmod -R 600 /home/Etienne/.ssh/*;

cat <<EOF > /etc/profile.d/00_lxc-details.sh
echo -e "    🖥️    OS: \$(cat /etc/os-release | grep ^NAME= | cut -d '=' -f 2 | cut -d '"' -f 2) - Version: \$(cat /etc/os-release | grep ^VERSION= | cut -d '=' -f 2 | cut -d '"' -f 2)";
echo -e "    🏠   Hostname: \$(hostname -f)";
echo -e "    💡   IP Address: \$(hostname -I | awk '{print $1}')";
EOF

apt update && apt -y upgrade && apt install -y vim ncat sysstat iotop telnet ssmtp mailutils net-tools needrestart rsync cron dnsutils;

update-alternatives --set editor /usr/bin/vim.basic;
cat <<EOF > /etc/vim/vimrc.local
" This file loads the default vim options at the beginning and prevents
" that they are being loaded again later. All other options that will be set,
" are added, or overwrite the default settings. Add as many options as you
" whish at the end of this file.

" Load the defaults
source \$VIMRUNTIME/defaults.vim


" Prevent the defaults from being loaded again later, if the user doesn't
" have a local vimrc (~/.vimrc)
let skip_defaults_vim = 1


" Set more options (overwrites settings from /usr/share/vim/vim80/defaults.vim)
" Add as many options as you whish

" Set the mouse mode to 'r'
if has('mouse')
  set mouse=r
endif
EOF

sed -i 's/root=postmaster/root=$myemail/g' /etc/ssmtp/ssmtp.conf;
sed -i 's/mailhub=mail/mailhub=smtp.home.famillerg.com/g' /etc/ssmtp/ssmtp.conf;

(crontab -u root -l ; echo "MAILTO=$pushoveremail") | crontab -u root -;
(crontab -u root -l ; echo "MAILFROM=$myemail") | crontab -u root -;

usermod -aG docker Etienne && newgrp docker;

docker run -d \
-p 8000:8000 -p 9443:9443 \
--user "1000:1000" \
--name portainer \
--restart=unless-stopped \
 -v /var/run/docker.sock:/var/run/docker.sock\
 -v /home/Etienne/Portainer/Config:/data \
 docker.io/portainer/portainer-ce:lts;

docker run -d \
-p 9001:9001 \
--name portainer-agent \
--restart=unless-stopped \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /var/lib/docker/volumes:/var/lib/docker/volumes \
docker.io/portainer/agent:latest;

# Deploy Netservices Stack from Portainer

exit 0;
