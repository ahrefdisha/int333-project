terraform {
  required_version = ">= 1.3.0"
}

resource "local_file" "enforced_nginx_config" {
  filename = "${path.module}/../config/nginx.conf"
  content  = <<-EOT
    events {}
    http {
        server {
            listen 80;
            server_name localhost;

            location / {
                return 200 "INT333 Service Healthy - Configuration Enforced\n";
                add_header Content-Type text/plain;
            }

            location /health {
                return 200 '{"status":"UP","config":"ENFORCED"}';
                add_header Content-Type application/json;
            }
        }
    }
  EOT
}
