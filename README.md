# Multi-Organization Matrix Server Deployment Script

This repository contains an automated installation script to deploy **multiple Matrix homeservers on a single machine** using Docker and Nginx.

The script dynamically creates Matrix servers based on the number of domains provided during installation.

Each domain gets:

* A dedicated Matrix homeserver
* A dedicated admin interface
* Reverse proxy routing
* SSL certificates
* Private federation between all configured domains

The setup uses **Synapse** as the homeserver and **Synapse Admin** for management.

---

# Features

* Deploy multiple Matrix homeservers from a single script
* Automatic Docker container creation per domain
* Automatic Nginx reverse proxy configuration
* Federation enabled **only between configured domains**
* Automatic SSL certificate generation using **Certbot**
* Automatic SSL renewal via cron
* Domain based container naming
* Dynamic port assignment
* Admin interface per organization
* Automatic `.well-known` discovery configuration
* Works with any number of organizations

---

# Architecture

```
Internet
   │
   ▼
Nginx Reverse Proxy
   │
   ├── domain1.com → Synapse container
   ├── domain2.com → Synapse container
   ├── domain3.com → Synapse container
   │
   └── Federation via port 8448
```

Each domain runs its own isolated Matrix server but can communicate with other configured domains through federation.

---

# Requirements

Server Requirements

* Ubuntu 22.04 / 24.04
* Root or sudo access
* Public IP address
* Domains pointing to the server
* Ports open in firewall / security group:

```
22
80
443
8448
```

---

# Installation

Clone the repository

```
git clone <your_repo_url>
cd <repo_name>
```

Make the script executable

```
chmod +x matrix_chat.sh
```

Run the installer

```
sudo ./matrix_chat.sh
```

---

# Example Installation

```
How many organizations (domains)? 3

Domain 1: chat.alpha.com
Domain 2: chat.beta.com
Domain 3: chat.gamma.com
```

The script will automatically create:

```
synapse_chat_alpha_com
synapse_chat_beta_com
synapse_chat_gamma_com
```

Each domain receives its own admin interface.

---

# Accessing the Servers

Matrix homeserver:

```
https://your-domain.com
```

Admin interface:

```
https://your-domain.com/admin
```

Default admin credentials:

```
username: admin
password: admin@123
```

---

# Federation Behavior

All configured domains federate **only with each other**.

External public Matrix servers are blocked.

Example:

```
alpha.com ↔ beta.com ✔
alpha.com ↔ matrix.org ✘
beta.com ↔ element.io ✘
```

---

# Container Naming

Containers are generated automatically based on domain names.

Example domain:

```
chat.company.com
```

Container names:

```
synapse_chat_company_com
admin_chat_company_com
```

---

# Ports

The script assigns ports automatically.

Example:

```
Domain 1 → 8008
Domain 2 → 8009
Domain 3 → 8010
```

Admin interfaces:

```
8081
8082
8083
```

---

# SSL Certificates

Certificates are issued using Let's Encrypt.

Automatic renewal is configured using cron.

---

# Directory Structure

```
/opt/matrix
├── domain1_data
├── domain2_data
├── docker-compose.yml
└── certs
```

Each domain keeps its own Synapse configuration and data.

---

# Useful Commands

Check containers

```
docker ps
```

View logs

```
docker logs <container_name>
```

Restart Matrix services

```
cd /opt/matrix
docker-compose restart
```

Restart nginx

```
sudo systemctl restart nginx
```

---

# Notes

* Ensure all domains resolve to the server IP before running the script.
* Federation requires port **8448** to be accessible from the internet.
* Admin panels can be restricted via Nginx if needed.

---

# License

MIT License
