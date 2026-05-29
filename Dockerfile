ARG BASE_IMAGE=alpine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.authors="Ernesto Serrano <info@ernesto.es>" \
      org.opencontainers.image.description="Lightweight container optimized for Moodle with Nginx & PHP-FPM based on Alpine Linux."

# Set pipefail to catch errors in piped commands
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Install Moodle-required packages and essential system utilities (Updated for PHP 8.5)
RUN apk --no-cache add \
        php85 \
        php85-ctype \
        php85-curl \
        php85-dom \
        php85-exif \
        php85-fileinfo \
        php85-fpm \
        php85-gd \
        php85-iconv \
        php85-intl \
        php85-ldap \
        php85-mbstring \
        php85-mysqli \
        php85-openssl \
        php85-pecl-apcu \
        php85-pecl-redis \
        php85-pecl-igbinary \
        php85-pdo \
        php85-pdo_mysql \
        php85-pgsql \
        php85-phar \
        php85-posix \
        php85-session \
        php85-simplexml \
        php85-soap \
        php85-sodium \
        php85-sqlite3 \
        php85-tokenizer \
        php85-xml \
        php85-xmlreader \
        php85-xmlwriter \
        php85-xsl \
        php85-zip \
        php85-zlib \
        nginx \
        runit \
        curl \
        tar \
        gzip \
# Bring in gettext so we can get `envsubst`
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Remove default server definition
    && rm -f /etc/nginx/http.d/default.conf \
# Create crucial Moodle directories and give permissions to nobody
    && mkdir -p /run /var/lib/nginx /var/www/html /var/log/nginx /var/moodledata \
    && chown -R nobody:nobody /run /var/lib/nginx /var/www/html /var/log/nginx /var/moodledata

# Add configuration files
COPY --chown=nobody rootfs/ /

# Switch to use a non-root user
USER nobody

# Add application
WORKDIR /var/www/html

# Expose the port nginx is reachable on
EXPOSE 8080

# Let runit start nginx & php-fpm
ENTRYPOINT ["/bin/docker-entrypoint.sh"]

# Configure a healthcheck 
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl --silent --fail http://127.0.0.1:8080/fpm-ping || exit 1

# Production-tuned Moodle Configurations
ENV nginx_root_directory=/var/www/html \
    client_max_body_size=512M \
    allow_url_fopen=On \
    allow_url_include=Off \
    display_errors=Off \
    file_uploads=On \
    max_execution_time=600 \
    max_input_time=600 \
    max_input_vars=5000 \
    memory_limit=512M \
    post_max_size=512M \
    upload_max_filesize=512M \
    zlib_output_compression=Off \
    date_timezone=UTC \
    intl_default_locale=en_US \
    fastcgi_read_timeout=600s \
    fastcgi_send_timeout=600s \
    REAL_IP_HEADER=X-Forwarded-For \
    REAL_IP_RECURSIVE=off \
    REAL_IP_FROM="" \
    # Optimized OPcache Settings for Moodle Core
    opcache_enable=1 \
    opcache_enable_cli=1 \
    opcache_memory_consumption=512 \
    opcache_interned_strings_buffer=64 \
    opcache_max_accelerated_files=65407 \
    opcache_validate_timestamps=1 \
    opcache_revalidate_freq=60 \
    opcache_save_comments=1 \
    opcache_enable_file_override=1 \
    opcache_jit=tracing \
    opcache_jit_buffer_size=128M \
    opcache_preload="" \
    realpath_cache_size=4096K \
    realpath_cache_ttl=600
