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

RUN { \
    echo "memory_limit=512M"; \
    echo "upload_max_filesize=256M"; \
    echo "post_max_size=256M"; \
    echo "max_execution_time=300"; \
      echo "max_input_vars=5000"; \
      echo "opcache.enable=1"; \
      echo "opcache.memory_consumption=192"; \
      echo "opcache.interned_strings_buffer=16"; \
      echo "opcache.max_accelerated_files=10000"; \
      echo "opcache.revalidate_freq=60"; \
    } > /usr/local/etc/php/conf.d/moodle.ini

WORKDIR /var/www/html
