FROM debian:12
RUN apt-get update && apt-get install nginx openssl -y && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /etc/nginx/ssl
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/nginx.key -out /etc/nginx/ssl/nginx.crt -subj "/CN=inception"
COPY conf/nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 443
ENTRYPOINT ["nginx", "-g", "daemon off;"]
