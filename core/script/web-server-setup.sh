#! /bin/bash

yum install -y httpd
service httpd start
chkconfig http on
chown -R ubuntu /var/www/html
echo "Hello World!" >> /var/www/html/index.html