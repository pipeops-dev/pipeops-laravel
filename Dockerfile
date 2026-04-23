FROM node:18-alpine AS frontend
WORKDIR /app
# Copy package.json and install dependencies
COPY package.json package-lock.json* ./
RUN npm install

# Copy application files for asset compilation
COPY . .
ENV CI=true
RUN npm run prod

# Stage 2: PHP Application
FROM php:8.2-apache

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

# Enable Apache mod_rewrite
RUN a2enmod rewrite

# Configure Apache DocumentRoot
ENV APACHE_DOCUMENT_ROOT /var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Set working directory
WORKDIR /var/www/html

# Copy composer from official image
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy application files
COPY . .

# Copy compiled frontend assets from the frontend stage
COPY --from=frontend /app/public /var/www/html/public

# Install Composer dependencies (optimizing for production)
RUN composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

# Set permissions for Laravel and configure Apache for non-root
RUN sed -i 's/80/8080/g' /etc/apache2/sites-available/*.conf /etc/apache2/ports.conf \
    && mkdir -p /var/run/apache2 /var/lock/apache2 /var/log/apache2 \
    && chown -R www-data:www-data /var/run/apache2 /var/lock/apache2 /var/log/apache2 /var/www/html \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

USER www-data

# Expose port 8080
EXPOSE 8080

# Start Apache in the foreground
CMD ["apache2-foreground"]
