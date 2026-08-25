FROM nginx:1.25-alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY moodle.conf /etc/nginx/conf.d/moodle.conf
EXPOSE 8080