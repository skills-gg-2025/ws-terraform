#!/bin/bash
yum update -y
yum install -y nginx

cat > /etc/nginx/conf.d/proxy.conf << 'EOF'
server {
    listen 80;
    
    location / {
        proxy_pass http://${green_alb_dns};
        proxy_set_header Host $host;
    }
    location /health {
        proxy_pass http://${green_alb_dns};
        proxy_set_header Host $host;
    }
    location /green {
        proxy_pass http://${green_alb_dns};
        proxy_set_header Host $host;
    }
    
    location /red {
        proxy_pass http://${red_alb_dns};
        proxy_set_header Host $host;
    }
}
EOF

systemctl start nginx
systemctl enable nginx