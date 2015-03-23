server {
  listen 8080;

  server_name _ default_server;

  access_log /var/log/nginx/default-access.log;
  error_log /var/log/nginx/default-error.log;

  location / {
    rewrite ^ {{ REDIRECT_URL }} permanent;
  }
}
