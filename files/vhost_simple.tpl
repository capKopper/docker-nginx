server {
  listen 8080;

  server_name {{ HOSTNAME }};

  access_log /var/log/nginx/{{ HOSTNAME }}-access.log main;
  error_log /var/log/nginx/{{ HOSTNAME }}-error.log;

  root {{ ROOT }};
}
