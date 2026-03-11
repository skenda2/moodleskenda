FROM php:8.2-fpm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        unzip \
        libicu-dev \
        libxml2-dev \
        libzip-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libonig-dev \
        libxslt1-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        intl \
        mysqli \
        soap \
        zip \
        gd \
        opcache \
        exif \
        xsl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pecl install igbinary redis \
    && docker-php-ext-enable igbinary redis

RUN { \
    echo "memory_limit=512M"; \
    echo "upload_max_filesize=256M"; \
    echo "post_max_size=256M"; \
    echo "max_execution_time=300"; \
    echo "max_input_vars=10000"; \
    echo "realpath_cache_size=4096K"; \
    echo "realpath_cache_ttl=600"; \
    echo "opcache.enable=1"; \
    echo "opcache.enable_cli=1"; \
    echo "opcache.memory_consumption=256"; \
    echo "opcache.interned_strings_buffer=32"; \
    echo "opcache.max_accelerated_files=50000"; \
    echo "opcache.validate_timestamps=1"; \
    echo "opcache.revalidate_freq=120"; \
    echo "opcache.save_comments=1"; \
    echo "opcache.jit=off"; \
    } > /usr/local/etc/php/conf.d/moodle.ini

COPY docker/php/entrypoint.sh /usr/local/bin/moodleskenda-entrypoint
RUN chmod +x /usr/local/bin/moodleskenda-entrypoint

WORKDIR /var/www/html

ENTRYPOINT ["moodleskenda-entrypoint"]
CMD ["php-fpm"]
