# Use the official PHP image as the base image
FROM php:8.0-fpm

# Install necessary packages for Laravel, including cron and unzip
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install -y cron curl unzip libpq-dev \
    # Remove package lists for smaller image sizes
    && rm -rf /var/lib/apt/lists/* \
    && docker-php-ext-install pdo pdo_mysql \
    # Install Composer
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Set the working directory for the Laravel app
WORKDIR /var/www

RUN ls -la

# Copy composer files first to leverage Docker cache
COPY composer.json composer.lock ./

# Install the Laravel app dependencies
ENV COMPOSER_ALLOW_SUPERUSER=1
RUN composer install --no-scripts --no-autoloader

# Copy the rest of the Laravel app into the container
COPY . .

# Generate autoloader and run scripts
RUN composer dump-autoload --optimize && composer run-script post-install-cmd

# Set proper permissions for the storage and bootstrap/cache directories
RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 755 storage bootstrap/cache

# Copy the crontab file and entrypoint script into the container
COPY crontab /etc/cron.d/laravel-cron
COPY entrypoint.sh /entrypoint.sh

# Install the crontab and make the entrypoint script executable
RUN chmod 0644 /etc/cron.d/laravel-cron \
    && crontab /etc/cron.d/laravel-cron \
    && chmod +x /entrypoint.sh

# Run the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]

# https://manpages.ubuntu.com/manpages/trusty/man8/cron.8.html
# -f | Stay in foreground mode, don't daemonize.
# -L loglevel | Tell cron what to log about jobs (errors are logged regardless of this value) as the sum of the following values:
CMD ["cron", "-f", "-L", "2"]
