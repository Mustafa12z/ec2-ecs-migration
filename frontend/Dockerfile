# Build context: the frontend/ directory.
FROM nginx:alpine

# Patch OS packages at build time: the nginx:alpine base image tag lags
# behind Alpine security advisories (e.g. libexpat CVE-2026-56131/56407/56408).
RUN apk update && apk upgrade --no-cache && rm -rf /var/cache/apk/*

# Replace the stock server block with our SPA + reverse-proxy config.
RUN rm -f /etc/nginx/conf.d/default.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# Static assets served by nginx at /var/www/flask-frontend (see default.conf).
COPY index.html styles.css app.js config.js /var/www/flask-frontend/

EXPOSE 80
