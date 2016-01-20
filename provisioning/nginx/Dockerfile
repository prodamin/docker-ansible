#
# Nginx Dockerfile
#

# Pull base image.
FROM nginx:1.9.9

RUN apt-get update && \
    apt-get install -y git \
	&& rm -rf /var/lib/apt/lists/*
 

# nginx site conf
RUN rm -Rf /etc/nginx/conf.d/* && \
rm -Rf /etc/nginx/sites-available/default

RUN mkdir -p /etc/nginx/upstream

ADD ./site.conf /etc/nginx/conf.d/default.conf

RUN chown www-data:www-data -R /etc/nginx/upstream /etc/nginx/conf.d/default.conf

ADD ./run.sh /
RUN chmod +x /run.sh

CMD ["/run.sh"]

# Expose ports.
EXPOSE 80

