server {
  listen 8080;

  server_name {{ HOSTNAME }};
  return 301 http://{{ REDIRECT_HOSTNAME }}$request_uri;
}
