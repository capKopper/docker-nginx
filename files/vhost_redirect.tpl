server {
  listen 8080;

  server_name {{ HOSTNAME }};
  return 301 {{ REDIRECT_SCHEME }}://{{ REDIRECT_HOSTNAME }}$request_uri;
}
