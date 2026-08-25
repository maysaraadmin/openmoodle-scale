FROM php:8.2-fpm-bookworm

LABEL org.opencontainers.image.title="OpenMoodleScale Moodle"
ARG MOODLE_BRANCH=MOODLE_404_STABLE
ENV MOODLE_BRANCH=${MOODLE_BRANCH}

RUN apt-get update && apt-get install -y --no-install-recommends \
    libfreetype6-dev libjpeg62-turbo-dev libpng-dev libzip-dev libicu-dev \
    libxml2-dev libxslt1-dev libpq-dev git unzip curl cron locales \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" gd intl mysqli pdo pdo_mysql pdo_pgsql opcache soap exif xsl zip mbstring bcmath \
    && pecl install redis-6.0.2 igbinary-3.2.15 \
    && docker-php-ext-enable redis igbinary \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html
RUN git clone --branch "${MOODLE_BRANCH}" --single-branch --depth 1 https://github.com/moodle/moodle.git . \
    && rm -rf .git \
    && chown -R www-data:www-data /var/www/html

COPY php.ini /usr/local/etc/php/php.ini
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

USER www-data
EXPOSE 9000
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]