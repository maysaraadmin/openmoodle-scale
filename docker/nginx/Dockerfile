FROM nginx:1.25-alpine
RUN rm /etc/nginx/conf.d/default.conf && \
    apk add --no-cache curl
COPY moodle.conf /etc/nginx/conf.d/moodle.conf
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -sf http://localhost:8080/health || exit 1
