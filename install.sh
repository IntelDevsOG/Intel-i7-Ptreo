#!/bin/bash

# Variables for default settings and shared IP
PANEL_DIR="/var/www/pterodactyl"
PANEL_DB="panel"
PANEL_USER="paneluser"
PANEL_PASS="intel-i7"
DEFAULT_EMAIL="intel-i7@gmail.com"
WINGS_VERSION="1.8.0" # Example, use the latest version

# Ask if the user is tunneling
echo "Are you tunneling the Pterodactyl Panel (e.g., using an external IP or reverse proxy)? (yes/no)"
read TUNNELING

# Install required packages
echo "Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y curl sudo lsb-release apt-transport-https ca-certificates gnupg2 software-properties-common nginx mysql-server php8.1 php8.1-fpm php8.1-cli php8.1-mysql php8.1-xml php8.1-mbstring php8.1-curl php8.1-zip php8.1-bcmath git unzip npm

# Install Composer (PHP dependency manager)
echo "Installing Composer..."
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Download Pterodactyl Panel
echo "Cloning Pterodactyl Panel repository..."
cd /var/www
git clone https://github.com/pterodactyl/panel.git pterodactyl
cd pterodactyl

# Set correct permissions for Panel directory
echo "Setting permissions for Panel directory..."
chown -R www-data:www-data /var/www/pterodactyl
chmod -R 755 /var/www/pterodactyl

# Install Panel dependencies using Composer
echo "Installing Panel dependencies..."
composer install --no-dev --optimize-autoloader

# Install Node.js dependencies
echo "Installing Node.js dependencies..."
npm install --legacy-peer-deps

# Set up environment file
echo "Setting up environment file..."
cp .env.example .env

# Update database settings in .env file
sed -i "s/DB_HOST=127.0.0.1/DB_HOST=localhost/" .env
sed -i "s/DB_DATABASE=pterodactyl/DB_DATABASE=$PANEL_DB/" .env
sed -i "s/DB_USERNAME=pterodactyl/DB_USERNAME=$PANEL_USER/" .env
sed -i "s/DB_PASSWORD=null/DB_PASSWORD=$PANEL_PASS/" .env

# Create the database and user for Pterodactyl if they don't already exist
echo "Creating MySQL database and user..."
mysql -e "CREATE DATABASE IF NOT EXISTS $PANEL_DB;"
mysql -e "CREATE USER IF NOT EXISTS '$PANEL_USER'@'localhost' IDENTIFIED BY '$PANEL_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON $PANEL_DB.* TO '$PANEL_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Generate application key
echo "Generating application key..."
php artisan key:generate

# Set up default Pterodactyl admin account
echo "Setting up default Pterodactyl admin user..."
php artisan p:user:make --email=$DEFAULT_EMAIL --password=$PANEL_PASS --username="admin" --admin=1

# Ask for server domain or IP address if tunneling
if [ "$TUNNELING" == "yes" ]; then
  echo "Please enter your external domain or IP address (e.g., panel.yourdomain.com or your.external.ip):"
  read SERVER_DOMAIN
else
  SERVER_DOMAIN="localhost"
fi

# Configure Nginx for the specified domain/IP
echo "Configuring Nginx for $SERVER_DOMAIN..."
cat > /etc/nginx/sites-available/pterodactyl <<EOL
server {
    listen 80;
    server_name $SERVER_DOMAIN;

    root /var/www/pterodactyl/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

ln -s /etc/nginx/sites-available/pterodactyl /etc/nginx/sites-enabled/

# Test and restart Nginx
echo "Testing Nginx configuration..."
nginx -t
systemctl restart nginx

# Set up SSL with Let's Encrypt (optional, for production environments)
if [ "$TUNNELING" == "yes" ]; then
  echo "Setting up SSL with Let's Encrypt (optional)..."
  apt install -y certbot python3-certbot-nginx
  certbot --nginx -d $SERVER_DOMAIN --non-interactive --agree-tos -m $DEFAULT_EMAIL
else
  echo "Skipping SSL setup as you are not tunneling."
fi

# Install Wings
echo "Installing Wings..."
cd /opt
curl -sSL "https://github.com/pterodactyl/wings/releases/download/v$WINGS_VERSION/wings-linux-amd64" -o wings
chmod +x wings
mv wings /usr/local/bin/wings

# Create the Wings configuration directory
echo "Setting up Wings configuration..."
mkdir -p /etc/pterodactyl
wings --help # This will ensure Wings is working and show any additional setup prompts

# Finish Setup
echo "Pterodactyl Panel and Wings installation complete!"
echo "Visit http://$SERVER_DOMAIN to complete the setup via the web interface."
echo "Default Admin Credentials:"
echo "Email: $DEFAULT_EMAIL"
echo "Password: $PANEL_PASS"
