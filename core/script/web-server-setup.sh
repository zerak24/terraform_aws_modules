#! /bin/bash

apt install apache2

echo '<html><body><h1>Hello World!</h1></body></html>' | sudo tee /var/www/html/index.html

systemctl enable apache2