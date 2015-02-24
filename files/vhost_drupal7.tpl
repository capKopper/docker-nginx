server {
  listen 8080;

  server_name {{ HOSTNAME }};

  access_log /var/log/nginx/{{ HOSTNAME }}-access.log;
  error_log /var/log/nginx/{{ HOSTNAME }}-error.log;

  client_max_body_size 24M;

  root {{ ROOT }};
  index index.php index.html;

  # Customer specific rules
  include /home/{{ CUSTOMER }}/config/nginx/{{ HOSTNAME }}/*.active;

  location = /favicon.ico {
    log_not_found off;
    access_log off;
  }

  location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
  }

  location = /backup {
    deny all;
  }

  # Very rarely should these ever be accessed outside of your lan
  location ~* \.(txt|log)$ {
    allow 127.0.0.1;
    deny all;
  }

  location / {
    # This is cool because no php is touched for static content
    try_files $uri @cache;
    expires max;
  }

  # XML Sitemap support.
  location = /sitemap.xml {
    try_files $uri @drupal;
  }

  location @drupal {
    index index.php;

    # Some modules enforce no slash (/) at the end of the URL
    # Else this rewrite block wouldn''t be needed (GlobalRedirect)
    rewrite ^/(.*)$ /index.php?q=$1 last;
  }

  # Allow only a few php files to improve security
  # For "cron" or "update" tasks use drush instead
  location ~* ^/(index|xmlrpc)\.php$ {
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_pass {{ PHP_BACKEND }};
    fastcgi_split_path_info ^(.+\.php)(.*)$;
    include fastcgi_params;
  }

  location ~* ^.+\.php$ {
    return 404;
  }

  location ~ ^/sites/.*/files/styles/ {
    access_log off;
    try_files $uri @drupal;
  }

  # This will try to see if we have a boost file in place. no harm done if this is not used
  location @cache {
    # Boost compresses can the pages so we check it. Comment it out
    # if you don't have it enabled in Boost.
    gzip_static on;

    # Error page handler for the case where $no_cache is 1. POST
    # request or authenticated.
    error_page 418 = @drupal;

    if ($http_cookie ~ "DRUPAL_UID" ) {
            return 418;
    }

    if ($request_method !~ ^(GET|HEAD)$ ) {
            return 418;
    }

    # Boost doesn't set a charset.
    charset utf-8;

    # Drupal uses 1978, use another expiration date...
    add_header Expires "Tue, 30 Dec 1979 06:30:00 GMT";
    add_header Cache-Control "must-revalidate, post-check=0, pre-check=0";
    try_files /cache/normal/$host/${uri}_${args}.html /cache/perm/$host/${uri}_.css /cache/perm/$host/${uri}_.js /cache/$host/0$uri.html /cache/$host/0${uri}/index.html @drupal;
  }

  # All static files will be served directly.
  location ~* ^.+\.(?:css|cur|js|jpe?g|gif|htc|ico|png|html|xml|otf|ttf|eot|woff|svg)$ {
    access_log off;
    expires 30d;
    # No need to bleed constant updates. Send the all shebang in one
    # fell swoop.
    tcp_nodelay off;
    # Set the OS file cache.
    open_file_cache max=3000 inactive=120s;
    open_file_cache_valid 45s;
    open_file_cache_min_uses 2;
    open_file_cache_errors off;
  }
}
