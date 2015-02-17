FROM nginx:latest

# Install tools
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install runit wget -y
# Override default nginx.conf (installed with the package)
ADD files/nginx.conf /etc/nginx/nginx.conf
RUN mkdir /etc/nginx/sites-enabled

# Add init script
ADD files/init.sh /init.sh
RUN chmod u+x /init.sh

EXPOSE 8080
ENTRYPOINT ["/init.sh"]
CMD []
