server {
  listen 8080;

  server_name _;

  location / {
    root /usr/share/nginx/html;
    index index.html index.htm;
  }

  # redirect server error pages to the static page /50x.html
  error_page 500 502 503 504 /50x.html;
  location = /50x.html {
    root /usr/share/nginx/html;
  }
}
