FROM debian:12
RUN apt-get update && apt-get install -y mariadb-server
RUN rm -rf /var/lib/mysql/*
COPY tools/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
EXPOSE 3306
