ARG BASE_IMAGE=alpine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.authors="Ernesto Serrano <info@ernesto.es>" \
      org.opencontainers.image.description="Lightweight container optimized for Moodle with Nginx & PHP-FPM based on Alpine Linux."

# Set pipefail to catch errors in piped commands
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Install Moodle-required packages
RUN apk --no-cache add \
        php83 \
        php83-ctype \
        php83-curl \
        php83-dom \
        php83-exif \
        php83-fileinfo \
        php83-fpm \
        php83-gd \
        php83-iconv \
        php83-intl \
        php83-ldap \
        php83-mbstring \
        php83-mysqli \
        php83-opcache \
        php83-openssl \
        php83-pecl-apcu \
        php83-pecl-redis \
        php83-pecl-igbinary \
        php83-pdo \
        php83-pdo_mysql \
        php83-pgsql \
        php83-phar \
        php83-posix \
        php83-session \
        php83-simplexml \
        php83-soap \
        php83-sodium \
        php83-sqlite3 \
        php83-tokenizer \
        php83-xml \
        php83-xmlreader \
        php83-xmlwriter \
        php83-xsl \
        php83-zip \
        php83-zlib \
        nginx \
        runit \
        curl \
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
# Note: /var/moodledata should be a persistent volume, but we ensure its base exists here
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
    clear_env=no \
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
    opcache_max_accelerated_files=60000 \
    opcache_validate_timestamps=1 \
    opcache_revalidate_freq=60 \
    opcache_save_comments=1 \
    opcache_enable_file_override=1 \
    opcache_jit=tracing \
    opcache_jit_buffer_size=128M \
    opcache_preload="" \
    realpath_cache_size=4096K \
    realpath_cache_ttl=600
