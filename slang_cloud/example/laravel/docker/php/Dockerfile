FROM php:8.4-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    locales \
    zip \
    jpegoptim optipng pngquant gifsicle \
    vim \
    unzip \
    git \
    curl \
    libzip-dev \
    libonig-dev \
    libxml2-dev

# Clear cache
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install pdo_mysql mbstring zip exif pcntl bcmath gd

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create system user for running Composer and Artisan Commands
RUN useradd -G www-data,root -u 1000 -d /home/slang slang
RUN mkdir -p /home/slang/.composer && \
    chown -R slang:slang /home/slang

# Set working directory
WORKDIR /var/www/html

# Copy existing application directory permissions
COPY --chown=slang:slang . /var/www/html

# Change current user to slang
USER slang

EXPOSE 9000
CMD ["php-fpm"]
