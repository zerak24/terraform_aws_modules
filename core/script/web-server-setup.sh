#! /bin/bash

apt update
apt install apache2 unzip

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

echo '<html><body><h1>Hello World!</h1></body></html>' | sudo tee /var/www/html/index.html

systemctl enable apache2