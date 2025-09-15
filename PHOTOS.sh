#!/bin/NASh

# Set temporary PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin;
export PATH="$PATH:test";

# NASh -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/wordpress.sh)"
# Create CT container with default settings (unprivileged)

# Load sensitives info from variables.env in order to not hardcode them in files push to GitHub
# Variable list
  # $pushoveremail
  # $myemail
  # $hcpingurl  
export $(grep -v '^#' variables.env | xargs);

#!/bin/NASh

# NASh -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/wordpress.sh)"
# Create CT container with default settings (unprivileged)

adduser --allow-bad-names Etienne;
echo $'Etienne ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers;

timedatectl set-timezone America/Toronto && timedatectl set-ntp true;

mkdir -p /home/Etienne/.ssh && chmod 700 /home/Etienne/.ssh;
scp -i /home/Etienne/.ssh/id_rsa Etienne@NAS:/mnt/Share/Configurations/SSH/id_rsa /home/Etienne/.ssh/id_rsa;
scp -i /home/Etienne/.ssh/id_rsa Etienne@NAS:/mnt/Share/Configurations/SSH/authorized_keys /home/Etienne/.ssh/authorized_keys;
scp -i /home/Etienne/.ssh/id_rsa Etienne@NAS:/mnt/Share/Configurations/SSH/id_rsa.pub /home/Etienne/.ssh/id_rsa.pub;
chown -R Etienne:Etienne /home/Etienne/.ssh && chmod -R 600 /home/Etienne/.ssh/*;

rm /etc/profile.d/00_lxc-details.sh;
cat <<EOF > /etc/profile.d/00_info.sh
echo -e "    🖥️    OS: \$(cat /etc/os-release | grep ^NAME= | cut -d '=' -f 2 | cut -d '"' -f 2) - Version: \$(cat /etc/os-release | grep ^VERSION= | cut -d '=' -f 2 | cut -d '"' -f 2)";
echo -e "    🏠   Hostname: \$(hostname -f)";
echo -e "    💡   IP Address: \$(hostname -I | awk '{print $1}')";
EOF

apt update && apt -y upgrade && apt install -y vim ncat sysstat iotop telnet ssmtp mailutils net-tools needrestart rsync cron dnsutils linux-sysctl-defaults;
setcap cap_net_raw+ep /bin/ping;

update-alternatives --set editor /usr/bin/vim.NASic;
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
(crontab -u root -l ; echo "#*/15 0 * * * php /var/www/html/wordpress/wp-content/plugins/mailpoet/mailpoet-cron.php /var/www/html/wordpress/ 2>&1") | crontab -u root -;
(crontab -u root -l ; echo "#*/5 * * * * curl $hcpingurl > /dev/null 2>&1") | crontab -u root -;

exit 0;
