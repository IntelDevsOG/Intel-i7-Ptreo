# Intel-i7-Ptreo Installation Script

This script automates the installation of **Pterodactyl Panel** and **Wings** on a fresh Ubuntu server. It also configures Nginx, sets up a MySQL database, and provides an option for SSL setup via Let's Encrypt.

## Prerequisites

Before running this script, ensure your system meets the following requirements:
- A fresh installation of Ubuntu 20.04 or later.
- Access to a server with at least 2 GB of RAM and 1 CPU core.
- A domain name (if using SSL with Let's Encrypt).
- Root or `sudo` privileges.

## Usage

### Step 1: Clone the Repository

Clone the repository to your server:

```bash
git clone https://github.com/IntelDevsOG/Intel-i7-Ptreo.git
cd Intel-i7-Ptreo

chmod +x install_pterodactyl.sh

./install_pterodactyl.sh
