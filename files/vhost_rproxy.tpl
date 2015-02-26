upstream {{ HOSTNAME }}_backend {
  server {{ RPROXY_UPSTREAM_SERVER }};
}

server {
  listen 8080;

  server_name {{ HOSTNAME }} {{ HOSTNAME_ALIASES }};

  access_log /var/log/nginx/{{ HOSTNAME }}-access.log main;
  error_log /var/log/nginx/{{ HOSTNAME }}-error.log;

  # disable "Location:" and "Refresh:" headers to by rewrite on proxied server response
  proxy_redirect off;
  # add some HTTP headers
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto $scheme;
  # informations about the backend server
  add_header X-Backend-Server $upstream_addr;

  location / {
    proxy_pass http://{{ HOSTNAME }}_backend;
  }

}
