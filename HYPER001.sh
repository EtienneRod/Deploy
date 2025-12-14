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

apt update && apt -y upgrade && apt install -y sudo vim ffmpeg duperemove;
curl -O https://github.com/rclone/rclone/releases/download/v1.72.0/rclone-v1.72.0-linux-amd64.deb && sudo apt install ./rclone-v1.72.0-linux-amd64.deb.deb;

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

ln -s /usr/bin/rclone /sbin/mount.rclone;

mkdir -p /mnt/Share/History/BUREAU-ETIENNE && chown Etienne:Etienne /mnt/Share/History/BUREAU-ETIENNE;
mkdir -p /mnt/Proxmox-Backup && chown Etienne:Etienne /mnt/Proxmox-Backup;
mkdir -p /mnt/Share && chown Etienne:Etienne /mnt/Share;

echo $'\n# Share\nUUID=47fbd8fb-5a8e-40c2-89b5-2ad5972acaaf /mnt/Share btrfs space_cache=v2,noatime,nodiratime,autodefrag 0 0' >> /etc/fstab;
echo $'\n# S3 Proxmox Etienne Backup\nProxmox:proxmox /mnt/Proxmox-Backup rclone rw,noauto,nofail,_netdev,x-systemd.automount,args2env,vfs_cache_mode=writes,config=/home/Etienne/HK/RClone/rclone.conf,cache_dir=/var/cache/rclone,allow-other 0 0' >> /etc/fstab;
echo $'\n# S3 Desktop Etienne Backup\nDesktop-Etienne:desktop-etienne /mnt/Share/History/BUREAU-ETIENNE rclone uid=1000,gid=1000,rw,noauto,nofail,_netdev,x-systemd.automount,args2env,vfs_cache_mode=writes,config=/home/Etienne/HK/RClone/rclone.conf,cache_dir=/var/cache/rclone,allow_non_empty 0 0' >> /etc/fstab;

systemctl daemon-reload && mount -a;

mkdir -p /home/Etienne/.ssh && chmod 700 /home/Etienne/.ssh;
cp /mnt/Share/Configurations/SSH/authorized_keys /home/Etienne/.ssh/authorized_keys;
cp /mnt/Share/Configurations/SSH/id_rsa.pub /home/Etienne/.ssh/id_rsa.pub;
cp /mnt/Share/Configurations/SSH/id_rsa /home/Etienne/.ssh/id_rsa;
chown -R Etienne:Etienne /home/Etienne/.ssh && chmod -R 600 /home/Etienne/.ssh/*;

cp -rp /mnt/Share/Configurations/HYPER/HYPER001/smb.conf /etc/samba/smb.conf;
chown root:root /etc/samba/smb.conf;
systemctl enable --now smb nmb && systemctl restart --now smb nmb;
echo -e "{password}\n{password}" | smbpasswd -s -a Etienne;

sed -i 's/relayhost =/relayhost = smtp.home.famillerg.com/g' /etc/postfix/main.cf && systemctl restart postfix;

curl -sL https://get.beszel.dev -o /tmp/install-agent.sh && chmod +x /tmp/install-agent.sh && /tmp/install-agent.sh -k \
"{beszelapi}" -t 84b7-6c9838bc6-4810-523747d38 --auto-update;
mkdir -p /etc/systemd/system/beszel-agent.service.d;
cat << EOF > /etc/systemd/system/beszel-agent.service.d/override.conf
[Service]
Environment="EXTRA_FILESYSTEMS=/VM,/mnt/Share__SHARE"
EOF
systemctl daemon-reload && systemctl restart beszel-agent.service;


(crontab -u root -l ; echo "MAILTO={pushoveremail}") | crontab -u root -;
(crontab -u root -l ; echo "{myemail}") | crontab -u root -;
(crontab -u root -l ; echo "#0 0 * * * /home/Etienne/HK/Update.sh > /home/Etienne/HK/Update.log 2>&1") | crontab -u root -;
(crontab -u root -l ; echo "#0 2 * * * /home/Etienne/HK/Backup.sh > /home/Etienne/HK/Backup.log 2>&1") | crontab -u root -;
(crontab -u root -l ; echo "#0 5 1 * * /home/Etienne/HK/BTRFS.sh > /home/Etienne/HK/BTRFS.log 2>&1") | crontab -u root -;
(crontab -u root -l ; echo "#*/5 * * * * curl https://hc-ping.com/{hcpingurl} > /dev/null 2>&1") | crontab -u root -;
crontab -e;
