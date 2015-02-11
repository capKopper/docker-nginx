FROM nginx:latest

# Install tools
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get install runit -y

ADD files/init.sh /init.sh
RUN chmod u+x /init.sh

EXPOSE 8080
ENTRYPOINT ["/init.sh"]
CMD []
