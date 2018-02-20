#!/bin/bash -e

##############################################
# Snipe-IT install script July 1st 2015      #
#   Script created by Mike Tucker            #
#     mtucker6784@gmail.com                  #
# No Relation to the author, just wanted     #
# to give an alternative (& maybe easier)    #
# method to install Snipe-IT on Ubuntu 14.04 #
#                                            #
# Feel free to modify, but please give       #
# credit where it's due. Thanks!             #
##############################################

#Get your FQDN, generate random characters for mysql root/snipeit users and 32bit key for later on.
echo "[FQDN] What is the FQDN of your server? (example: www.yourserver.com)"
read fqdn
mysqlrootpw="$(echo `< /dev/urandom tr -dc _a-z-0-9 | head -c6`)"
mysqluserpw="$(echo `< /dev/urandom tr -dc _a-z-0-9 | head -c6`)"
random32="$(echo `< /dev/urandom tr -dc _A-Za-z-0-9 | head -c32`)"
hostname="$(hostname)"
dir=/var/www/snipe-it
apachefile=/etc/apache2/sites-available/$fqdn.conf
hosts=/etc/hosts

#createstuff.sql will be injected to the database during install. mysqlpasswords.txt is a file that will contain the root and snipeit user passwords.
#You should probably jot these down and then blow away the file. This is at your discretion.
createstufffile=/root/createstuff.sql
passwordfile=/root/mysqlpasswords.txt

echo >> $createstufffile "CREATE DATABASE snipeit;"
echo >> $createstufffile "GRANT ALL PRIVILEGES ON snipeit.* TO snipeit@localhost IDENTIFIED BY '$mysqluserpw';"

echo "MySQL ROOT password: $mysqlrootpw"
echo "MySQL USER (snipeit) password: $mysqluserpw"
echo "32 bit random string: $random32"
echo "These passwords have been exported to /root/mysqlpasswords.txt...I recommend You delete this file for security purposes"
echo >> $passwordfile "MySQL Passwords..."
echo >> $passwordfile "Root: $mysqlrootpw"
echo >> $passwordfile "User (snipeit): $mysqluserpw"
echo >> $passwordfile "32 bit random string: $random32"

sleep 1
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get install -y git
sleep 1

sudo git clone https://github.com/snipe/snipe-it.git $dir
sleep 2

#We already have a random root password for SQL. Carry forth.
export DEBIAN_FRONTEND=noninteractive
apt-get install -y lamp-server^
apt-get install -y php5 php5-mcrypt php5-curl php5-mysql
php5enmod mcrypt
a2enmod rewrite
ls -al /etc/apache2/mods-enabled/rewrite.load
echo "using root password: $mysqlrootpw"
echo "sending you to the mysql root account. Create the database and the user..."
sleep 1
sudo mysqladmin -u root password $mysqlrootpw
sudo mysql -u root -p$mysqlrootpw < /root/createstuff.sql
echo "If no errors, then we're continuing on."
sleep 1

replace "'www.yourserver.com'" "'$hostname'" -- $dir/bootstrap/start.php
cp $dir/app/config/production/database.example.php $dir/app/config/production/database.php
replace "'snipeit_laravel'," "'snipeit'," -- $dir/app/config/production/database.php
replace "'travis'," "'snipeit'," -- $dir/app/config/production/database.php
replace "            'password'  => ''," "            'password'  => '$mysqluserpw'," -- $dir/app/config/production/database.php
replace "'http://production.yourserver.com'," "'http://$fqdn'," -- $dir/app/config/production/database.php
cp $dir/app/config/production/app.example.php $dir/app/config/production/app.php
replace "'http://production.yourserver.com'," "'http://$fqdn'," -- $dir/app/config/production/app.php
replace "'Change_this_key_or_snipe_will_get_ya'," "'$random32'," -- $dir/app/config/production/app.php
cp $dir/app/config/production/mail.example.php $dir/app/config/production/mail.php
echo ""
echo "Finished copying and replacing text in files. I have no idea about your mail environment, so if you want email capability, open up the following..."
echo "nano -w $dir/app/config/production/mail.php"
echo "And edit the attributes appropriately."
echo ""
sleep 1

echo >> $apachefile ""
echo >> $apachefile ""
echo >> $apachefile "<VirtualHost *:80>"
echo >> $apachefile "ServerAdmin webmaster@localhost"
echo >> $apachefile "    <Directory $dir/public>"
echo >> $apachefile "        Require all granted"
echo >> $apachefile "        AllowOverride All"
echo >> $apachefile "   </Directory>"
echo >> $apachefile "    DocumentRoot $dir/public"
echo >> $apachefile "    ServerName $fqdn"
echo >> $apachefile "        ErrorLog "\${APACHE_LOG_DIR}"/error.log"
echo >> $apachefile "        CustomLog "\${APACHE_LOG_DIR}"/access.log combined"
echo >> $apachefile "</VirtualHost>"
echo >> $hosts "127.0.0.1 $hostname $fqdn"
a2ensite $fqdn.conf

sudo chmod -R 755 $dir/app/storage
sudo chmod -R 755 $dir/app/private_uploads
sudo chmod -R 755 $dir/public/uploads
sudo chown -R www-data:www-data /var/www/
echo "Finished permission changes."
sudo curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
cd $dir/
sudo composer install --no-dev --prefer-source
php artisan app:install --env=production

service apache2 restart
echo "Ok, open up http://$fqdn in a web browser, hope this worked for you."
echo "Remember! If you want mail capabilities, open $dir/app/config/production/mail.php and fill out the attributes, then restart apache just for grins"
sleep 1
