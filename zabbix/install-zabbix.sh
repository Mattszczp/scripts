#!/bin/bash
read -sp "New MariaDB Root Password: " mariadb_root_pass
read -sp 'Zabbix DB User Passowrd: ' zabbix_db_user_pass

wget https://repo.zabbix.com/zabbix/5.0/debian/pool/main/z/zabbix-release/zabbix-release_5.0-1+buster_all.deb
sudo dpkg -i zabbix-release_5.0-1+buster_all.deb
sudo apt update && sudo apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-agent mariadb-server -y

sudo mysqladmin password $mariadb_root_pass

echo 'Deleting Anonymous Users from MariaDB'
echo "DELETE FROM mysql.user WHERE User='';" | sudo mysql -uroot -p$mariadb_root_pass

echo 'Deleting remote root access to MariaDB'
echo "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" | sudo mysql -uroot -p$mariadb_root_pass

echo 'Flushing privaleges'
echo "FLUSH PRIVILEGES;" | sudo mysql -uroot -p$mariadb_root_pass

echo 'Creating Zabbix Database'
echo "create database zabbix character set utf8 collate utf8_bin; create user zabbix@localhost identified by '${zabbix_db_user_pass}'; grant all privileges on zabbix.* to zabbix@localhost;FLUSH PRIVILEGES;" | sudo mysql -uroot -p$mariadb_root_pass

echo 'Importing Zabbix Database'
sudo zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | sudo mysql -uzabbix -p$zabbix_db_user_pass zabbix

echo 'Editing Configuration files'
sudo sed -i "s/Riga/Warsaw/g" /etc/zabbix/apache.conf #Change Europe/Riga to Europe/Warsaw
sudo sed -i "20 s/# *//" /etc/zabbix/apache.conf #Uncomment line 20 (php_value date.timezone)
sudo sed -i "30 s/# *//" /etc/zabbix/apache.conf #Same as above, but for line 30
sudo sed -i '/DBPassword=/s/^#//g' /etc/zabbix/zabbix_server.conf
sudo sed -i "s/DBPassword=/DBPassword=${zabbix_db_user_pass}/g" /etc/zabbix/zabbix_server.conf

sudo systemctl restart zabbix-server zabbix-agent apache2
sudo systemctl enable zabbix-server zabbix-agent apache2