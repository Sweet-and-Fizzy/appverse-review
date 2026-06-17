#!/bin/bash
cat > "$TMPDIR/nginx.conf" <<NGINX
worker_processes 1;
events { worker_connections 128; }
http {
    server {
        listen $NGINX_PORT;

        location / {
            if (\$cookie_TB_AUTH_TOKEN != "$NGINX_COOKIE") {
                return 403;
            }
            proxy_pass http://unix:$TMPDIR/mlflow.sock;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
        }
    }
}
NGINX
