FROM nginx:latest

# Install tools
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install runit wget -y
# jq (json parsing tool)
RUN wget http://stedolan.github.io/jq/download/linux64/jq -O /usr/local/bin/jq && \
    chmod u+x /usr/local/bin/jq

# Override default nginx.conf (installed with the package)
ADD files/nginx.conf /etc/nginx/nginx.conf
RUN mkdir /etc/nginx/sites-enabled
# Add nginx templates vhosts
ADD files/vhost_default.tpl /tmp/nginx-tpl/
ADD files/vhost_default-redirect.tpl /tmp/nginx-tpl/
ADD files/vhost_drupal7.tpl /tmp/nginx-tpl/
ADD files/vhost_drupal6.tpl /tmp/nginx-tpl/
ADD files/vhost_redirect.tpl /tmp/nginx-tpl/
ADD files/vhost_rproxy.tpl /tmp/nginx-tpl/
ADD files/vhost_simple.tpl /tmp/nginx-tpl/

# Add init script
ADD files/init.sh /init.sh
RUN chmod u+x /init.sh

EXPOSE 8080
ENTRYPOINT ["/init.sh"]
CMD []
