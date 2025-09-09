#!/bin/bash
yum update -y

# Install Nginx
yum install -y nginx

# Create Nginx configuration for reverse proxy
cat > /etc/nginx/nginx.conf << 'EOF'
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 8000;
        server_name _;

        location / {
            proxy_pass http://${lattice_service_dns};
            proxy_set_header Host ${lattice_service_dns};
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_http_version 1.1;
        }
    }
}
EOF

# Enable and start Nginx
systemctl enable nginx
systemctl start nginx

# Check Nginx status
systemctl status nginx
