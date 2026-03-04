.PHONY: install up down restart shell migrate seed fresh logs test

# Default Laravel project name
PROJECT_NAME=laravel-slang-cloud

install:
	@echo "🚀 Installing Laravel..."
	@mkdir -p src
	@docker run --rm -v "$(PWD)/src:/app" composer create-project laravel/laravel /app --prefer-dist
	@cp -n src/.env.example src/.env 2>/dev/null || true
	@echo "✅ Laravel installed successfully!"

up:
	@docker-compose up -d
	@echo "✅ Services started!"
	@echo "🌐 API: http://localhost:8000"
	@echo "🎛️  Admin: http://localhost:8000/admin"

down:
	@docker-compose down

restart: down up

shell:
	@docker-compose exec app bash

# Laravel Artisan Commands
migrate:
	@docker-compose exec app php artisan migrate --force

seed:
	@docker-compose exec app php artisan db:seed --class=LanguageSeeder --force

fresh:
	@docker-compose exec app php artisan migrate:fresh --seed --force

optimize:
	@docker-compose exec app php artisan optimize

cache-clear:
	@docker-compose exec app php artisan cache:clear
	@docker-compose exec app php artisan config:clear
	@docker-compose exec app php artisan route:clear

# File permissions (run after installing Laravel)
permissions:
	@docker-compose exec app chown -R slang:www-data /var/www/html
	@docker-compose exec app chmod -R 775 /var/www/html/storage
	@docker-compose exec app chmod -R 775 /var/www/html/bootstrap/cache
	@docker-compose exec app chmod -R 775 /var/www/html/public/translations
	@echo "✅ Permissions set!"

# Generate app key
key-generate:
	@docker-compose exec app php artisan key:generate

# Full setup
setup: install up key-generate permissions migrate seed
	@echo "✅ Laravel Slang Cloud is ready!"
	@echo "🌐 API: http://localhost:8000"
	@echo "🎛️  Admin: http://localhost:8000/admin"

logs:
	@docker-compose logs -f

test:
	@docker-compose exec app php artisan test

# Create translations directory
init-translations:
	@mkdir -p src/public/translations
	@mkdir -p src/public/admin
	@echo "✅ Directories created!"
