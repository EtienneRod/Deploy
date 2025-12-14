#!/bin/bash

# Set temporary PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;
export PATH="$PATH:test";

# Load sensitives info from variables.env in order to not hardcode them in files push to GitHub
# Variable list
  # $password
  # $pushoveremail
  # $myemail
  # $hcpingurl
  # $beszelapi
export $(grep -v '^#' variables.env | xargs);

echo -e "$password\n$password" | passwd;

apt update && apt -y upgrade && apt install -y sudo vim;

cat <<EOF > /etc/profile.d/00_info.sh
echo -e "    🖥️    OS: \$(cat /etc/os-release | grep ^NAME= | cut -d '=' -f 2 | cut -d '"' -f 2) - Version: \$(cat /etc/os-release | grep ^VERSION= | cut -d '=' -f 2 | cut -d '"' -f 2)";
echo -e "    🏠   Hostname: \$(hostname -f)";
echo -e "    💡   IP Address: \$(hostname -I | awk '{print $1}')";
EOF

bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/misc/microcode.sh)";
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/misc/post-pve-install.sh)";
journalctl -k | grep -E "microcode" | head -n 1;

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

sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config;

cat >> /etc/ssh/sshd_config<< EOF
match user Etienne
PasswordAuthentication yes
EOF

systemctl restart ssh.service;

mkdir -p /mnt/Share;
chown Etienne:Etienne /mnt/Share;
echo $'\n# Share\n//nas.home.famillerg.com/Share /mnt/Share cifs rw,username=Etienne,password=$password,uid=1000,gid=1000 0 0' >> /etc/fstab;
systemctl daemon-reload && mount -a;

ln -s /usr/bin/rclone /sbin/mount.rclone;

mkdir -p /home/Etienne/HK/RClone;
cp -rp /mnt/Share/Configurations/HYPER/HYPER001/Etienne/HK/RClone/rclone.conf /home/Etienne/HK/RClone/rclone.conf;
chown -R Etienne:Etienne /home/Etienne/HK;
mkdir -p /mnt/Proxmox-Backup && chown Etienne:Etienne /mnt/Proxmox-Backup;
echo $'\n# S3 Proxmox Etienne Backup\nProxmox:proxmox /mnt/Proxmox-Backup rclone rw,noauto,nofail,_netdev,x-systemd.automount,args2env,vfs_cache_mode=writes,config=/home/Etienne/HK/RClone/rclone.conf,cache_dir=/var/cache/rclone,allow_non_empty 0 0' >> /etc/fstab;
systemctl daemon-reload && mount -a;

cp /mnt/Share/Configurations/HYPER/HVM/Includes/00_info.sh /etc/profile.d/00_info.sh;
chown -R root:root /etc/profile.d/00_info.sh;
echo "" > /etc/motd;

mkdir -p /home/Etienne/.ssh && chmod 700 /home/Etienne/.ssh;
scp Etienne@172.27.27.32:/mnt/Share/Configurations/SSH/authorized_keys /home/Etienne/.ssh/authorized_keys;
scp Etienne@172.27.27.32:/mnt/Share/Configurations/SSH/id_rsa.pub /home/Etienne/.ssh/id_rsa.pub;
scp Etienne@172.27.27.32:/mnt/Share/Configurations/SSH/id_rsa /home/Etienne/.ssh/id_rsa;
chown -R Etienne:Etienne /home/Etienne/.ssh && chmod -R 600 /home/Etienne/.ssh/*;

sed -i 's/relayhost =/relayhost = smtp.home.famillerg.com/g' /etc/postfix/main.cf && systemctl restart postfix;

curl -sL https://get.beszel.dev -o /tmp/install-agent.sh && chmod +x /tmp/install-agent.sh && /tmp/install-agent.sh -k \
f"{beszelapi}" -t a953-da4793d33-21df3-4cdb6549a --auto-update
mkdir -p /etc/systemd/system/beszel-agent.service.d;
cat << EOF > /etc/systemd/system/beszel-agent.service.d/override.conf
[Service]
Environment="EXTRA_FILESYSTEMS=/VM"
EOF
systemctl daemon-reload && systemctl restart beszel-agent.service;

(crontab -u root -l ; echo "MAILTO=$pushoveremail") | crontab -u root -;
(crontab -u root -l ; echo "MAILFROM=$myemail") | crontab -u root -;
(crontab -u root -l ; echo "#0 0 * * * /home/Etienne/HK/Update.sh > /home/Etienne/HK/Update.log 2>&1") | crontab -u root -;
(crontab -u root -l ; echo "#*/5 * * * * curl $hcpingurl > /dev/null 2>&1") | crontab -u root -;
crontab -e;

exit 0;
