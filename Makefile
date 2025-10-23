.PHONY: help install setup build run test clean dbup dbdown rsdb dev up logs terminal format install-jq config config-show config-restart

# Default target
help:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║         ERPNext Development Environment Setup          ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🚀 Main Commands:"
	@echo "  make up              - Start development environment (docker-compose)"
	@echo "  make dev             - Start with auto-reload (requires watchdog)"
	@echo "  make down            - Stop all containers"
	@echo ""
	@echo "🗄️  Database Commands:"
	@echo "  make dbup            - Start database containers (MariaDB + Redis)"
	@echo "  make dbdown          - Stop database containers"
	@echo "  make rsdb            - Reset databases (⚠️  deletes all data)"
	@echo ""
	@echo "📦 Setup Commands:"
	@echo "  make install         - Install Python & Node dependencies"
	@echo "  make setup           - Initial setup (install + migrate)"
	@echo "  make build           - Build frontend assets"
	@echo ""
	@echo "🔍 Development:"
	@echo "  make format          - Format Python code"
	@echo "  make test            - Run tests"
	@echo "  make logs            - View container logs"
	@echo "  make dev-logs        - View development logs with watchexec info"
	@echo "  make terminal        - Access container terminal"
	@echo ""
	@echo "⚙️  Configuration:"
	@echo "  make config          - Update site config from .env"
	@echo "  make config-show     - Update and show current config"
	@echo "  make install-jq      - Install jq tool (required for config)"
	@echo ""
	@echo "🧹 Cleanup:"
	@echo "  make clean           - Remove build artifacts"
	@echo "  make clean-frappe    - Remove frappe-bench directory"
	@echo "  make clean-all       - Remove containers, volumes, and data"
	@echo ""

# ============================================================================
# MAIN COMMANDS
# ============================================================================

up:
	@echo "🚀 Starting ERPNext in local development mode..."
	@echo "   Ensuring database configuration exists..."
	@mkdir -p database/mariadb/data database/redis/data
	@if [ ! -f database/.env ]; then cp database/.env.example database/.env; echo "   Created database/.env from example"; fi
	bash bin/up.sh local

up-build:
	@echo "🚀 Starting ERPNext with rebuild..."
	@echo "   Ensuring database configuration exists..."
	@mkdir -p database/mariadb/data database/redis/data
	@if [ ! -f database/.env ]; then cp database/.env.example database/.env; echo "   Created database/.env from example"; fi
	bash bin/up.sh localbuild

up-prod:
	@echo "🚀 Starting ERPNext in production mode..."
	bash bin/up.sh prod

down:
	@echo "🛑 Stopping all containers..."
	docker compose -f docker-compose.local.yml down
	cd database && docker compose down && cd ..

dev:
	@echo "👀 Starting with auto-reload..."
	bash bin/local-env.sh
	watchmedo auto-restart -d . -p '*.py;*.js' -i .git --recursive -- bench start

logs:
	@echo "📋 Showing container logs..."
	docker compose logs -f

dev-logs:
	@echo "📋 Showing development logs with watchexec info..."
	bash bin/dev-logs.sh

terminal:
	@echo "🖥️  Opening container terminal..."
	docker exec -it $(shell docker ps -q -f "name=erpnext" | head -1) /bin/zsh || \
	docker run -it --rm -v $(PWD):/app -w /app frappe/erpnext:latest /bin/zsh

# ============================================================================
# DATABASE COMMANDS
# ============================================================================

dbup:
	@echo "🗄️  Starting database containers..."
	cd database && env -i PATH="$$PATH" HOME="$$HOME" docker compose up -d && cd ..
	@echo "✅ Databases started!"
	@echo "   MariaDB:  localhost:3306"
	@echo "   Redis:    localhost:6379"

dbdown:
	@echo "🛑 Stopping database containers..."
	cd database && env -i PATH="$$PATH" HOME="$$HOME" docker compose down && cd ..

rsdb:
	@echo "⚠️  Resetting databases (deleting all data)..."
	make dbdown
	@echo "🗑️  Removing database volumes..."
	sudo rm -rf database/mariadb/data database/redis/data
	@echo "✅ Database data cleared."
	make dbup
	@echo "✅ Databases reset and restarted!"

# ============================================================================
# SETUP & INSTALLATION COMMANDS
# ============================================================================

install:
	@echo "📦 Installing dependencies..."
	@echo "   Installing Python packages..."
	pip install --upgrade pip setuptools wheel
	pip install -r requirements.txt -q
	@echo "   Installing Node packages..."
	npm ci --prefer-offline || npm install
	@echo "✅ Dependencies installed!"

setup: install
	@echo "🔧 Setting up ERPNext..."
	@echo "   Creating .env from template (if not exists)..."
	@if [ ! -f .env ]; then cp .env.example .env; fi
	@if [ ! -f database/.env ]; then cp database/.env.example database/.env; fi
	@echo "   Starting databases..."
	@make dbup
	@echo "⏳ Waiting for databases to be ready..."
	@sleep 10
	@echo "   Running migrations..."
	bench migrate -q || true
	@echo "   Building frontend assets..."
	npm run build || true
	@echo "✅ Setup completed!"

build:
	@echo "🏗️  Building frontend assets..."
	npm run build
	@echo "✅ Build completed!"

# ============================================================================
# DEVELOPMENT COMMANDS
# ============================================================================

format:
	@echo "🎨 Formatting code..."
	black . --quiet || true
	isort . --quiet || true
	@echo "✅ Code formatted!"

test:
	@echo "🧪 Running tests..."
	bench test
	@echo "✅ Tests completed!"

# ============================================================================
# CONFIGURATION COMMANDS
# ============================================================================

install-jq:
	@echo "🔧 Installing jq (JSON processor)..."
	@bash bin/install_jq.sh
	@echo "✅ jq installation completed!"

config:
	@echo "⚙️  Updating site configuration from .env..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Creating from example..."; \
		cp .env.example .env; \
		echo "📝 Please edit .env file with your configuration and run 'make config' again"; \
		exit 1; \
	fi
	@bash bin/update_config.sh
	@echo "✅ Configuration updated!"

config-show:
	@echo "⚙️  Updating site configuration and showing result..."
	@if [ ! -f .env ]; then \
		echo "❌ .env file not found. Creating from example..."; \
		cp .env.example .env; \
		echo "📝 Please edit .env file with your configuration and run 'make config-show' again"; \
		exit 1; \
	fi
	@SHOW_CONFIG=true bash bin/update_config.sh

config-restart: config
	@echo "🔄 Restarting ERPNext after configuration update..."
	@cd frappe-bench && bench restart || echo "⚠️  Could not restart automatically. Please restart manually."

# ============================================================================
# CLEANUP COMMANDS
# ============================================================================

clean:
	@echo "🧹 Cleaning build artifacts..."
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name ".DS_Store" -delete
	rm -rf build dist .eggs *.egg-info
	@echo "✅ Cleanup completed!"

clean-frappe:
	@echo "🗑️  Removing frappe-bench directory..."
	@rm -rf frappe-bench
	@echo "✅ frappe-bench directory removed!"

clean-all: down clean rsdb
	@echo "🗑️  Removing all containers and volumes..."
	docker compose down -v
	@echo "✅ Complete cleanup done!"

# ============================================================================
# HELPER COMMANDS
# ============================================================================

.PHONY: status
status:
	@echo "📊 System Status:"
	@echo "   Docker containers:"
	@docker ps -a --filter "label!=com.example.exclude" --format "table {{.Names}}\t{{.Status}}" || echo "   No containers found"
	@echo ""
	@echo "   Port usage:"
	@netstat -tuln 2>/dev/null | grep -E "(8080|3306|6379)" || echo "   Key ports are available"

# ============================================================================
# WINDOWS POWERSHELL COMMANDS
# ============================================================================
# Use these commands when running on Windows with PowerShell
# Example: make win-help, make win-up, make win-down, etc.

win-help:
	@echo "╔════════════════════════════════════════════════════════╗"
	@echo "║      ERPNext Development Environment - Windows         ║"
	@echo "╚════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🚀 Main Commands (Windows):"
	@echo "  make win-up              - Start development environment"
	@echo "  make win-dev             - Start with auto-reload"
	@echo "  make win-down            - Stop all containers"
	@echo ""
	@echo "🗄️  Database Commands (Windows):"
	@echo "  make win-dbup            - Start database containers"
	@echo "  make win-dbdown          - Stop database containers"
	@echo "  make win-rsdb            - Reset databases (⚠️  deletes all data)"
	@echo ""
	@echo "📦 Setup Commands (Windows):"
	@echo "  make win-install         - Install Python & Node dependencies"
	@echo "  make win-setup           - Initial setup (install + migrate)"
	@echo "  make win-build           - Build frontend assets"
	@echo ""
	@echo "🔍 Development (Windows):"
	@echo "  make win-format          - Format Python code"
	@echo "  make win-test            - Run tests"
	@echo "  make win-logs            - View container logs"
	@echo "  make win-dev-logs        - View development logs with watchexec info"
	@echo "  make win-terminal        - Access container terminal"
	@echo ""
	@echo "⚙️  Configuration (Windows):"
	@echo "  make win-config          - Update site config from .env"
	@echo "  make win-config-show     - Update and show current config"
	@echo "  make win-install-jq      - Install jq tool (required for config)"
	@echo ""
	@echo "🏗️  Build & Deploy (Windows):"
	@echo "  make win-build-local     - Build for local development"
	@echo "  make win-build-prod      - Build for production"
	@echo "  make win-deploy          - Deploy to production"
	@echo ""
	@echo "🧹 Cleanup (Windows):"
	@echo "  make win-clean           - Remove build artifacts"
	@echo "  make win-clean-frappe    - Remove frappe-bench directory"
	@echo "  make win-clean-all       - Remove containers, volumes, and data"
	@echo ""

# ============================================================================
# WINDOWS MAIN COMMANDS
# ============================================================================

win-up:
	@echo "🚀 Starting ERPNext in local development mode (Windows)..."
	@echo "   Ensuring database configuration exists..."
	@if not exist "database\\mariadb\\data" mkdir "database\\mariadb\\data"
	@if not exist "database\\redis\\data" mkdir "database\\redis\\data"
	@if not exist "database\\.env" copy "database\\.env.example" "database\\.env"
	@bin\\up.bat local

win-up-build:
	@echo "🚀 Starting ERPNext with rebuild (Windows)..."
	@echo "   Ensuring database configuration exists..."
	@if not exist "database\\mariadb\\data" mkdir "database\\mariadb\\data"
	@if not exist "database\\redis\\data" mkdir "database\\redis\\data"
	@if not exist "database\\.env" copy "database\\.env.example" "database\\.env"
	@bin\\up.bat localbuild

win-up-prod:
	@echo "🚀 Starting ERPNext in production mode (Windows)..."
	@bin\\up.bat prod

win-down:
	@echo "🛑 Stopping all containers (Windows)..."
	@docker compose -f docker-compose.local.yml down
	@powershell -Command "& { Set-Location database; docker compose down; Set-Location .. }"

win-dev:
	@echo "👀 Starting with auto-reload (Windows)..."
	@bin\\local-env.bat
	@powershell -Command "& { if (Get-Command watchmedo -ErrorAction SilentlyContinue) { watchmedo auto-restart -d . -p '*.py;*.js' -i .git --recursive -- bench start } else { Write-Host 'Error: watchmedo not installed. Please install watchdog: pip install watchdog' } }"

win-logs:
	@echo "📋 Showing container logs (Windows)..."
	@docker compose logs -f

win-dev-logs:
	@echo "📋 Showing development logs with watchexec info (Windows)..."
	@bin\\dev-logs.bat

win-terminal:
	@echo "🖥️  Opening container terminal (Windows)..."
	@powershell -Command "& { $$containerId = (docker ps -q -f 'name=erpnext' | Select-Object -First 1); if ($$containerId) { docker exec -it $$containerId /bin/zsh } else { docker run -it --rm -v $$(Get-Location):/app -w /app frappe/erpnext:latest /bin/zsh } }"

# ============================================================================
# WINDOWS DATABASE COMMANDS
# ============================================================================

win-dbup:
	@echo "🗄️  Starting database containers (Windows)..."
	@powershell -Command "& { Set-Location database; docker compose up -d; Set-Location .. }"
	@echo "✅ Databases started!"
	@echo "   MariaDB:  localhost:3306"
	@echo "   Redis:    localhost:6379"

win-dbdown:
	@echo "🛑 Stopping database containers (Windows)..."
	@powershell -Command "& { Set-Location database; docker compose down; Set-Location .. }"

win-rsdb:
	@echo "⚠️  Resetting databases (deleting all data) - Windows..."
	@$(MAKE) win-dbdown
	@echo "🗑️  Removing database volumes..."
	@powershell -Command "& { if (Test-Path 'database\\mariadb\\data') { Remove-Item -Path 'database\\mariadb\\data' -Recurse -Force } }"
	@powershell -Command "& { if (Test-Path 'database\\redis\\data') { Remove-Item -Path 'database\\redis\\data' -Recurse -Force } }"
	@echo "✅ Database data cleared."
	@$(MAKE) win-dbup
	@echo "✅ Databases reset and restarted!"

# ============================================================================
# WINDOWS SETUP & INSTALLATION COMMANDS
# ============================================================================

win-install:
	@echo "📦 Installing dependencies (Windows)..."
	@echo "   Installing Python packages..."
	@pip install --upgrade pip setuptools wheel
	@pip install -r requirements.txt -q
	@echo "   Installing Node packages..."
	@powershell -Command "& { try { npm ci --prefer-offline } catch { npm install } }"
	@echo "✅ Dependencies installed!"

win-setup: win-install
	@echo "🔧 Setting up ERPNext (Windows)..."
	@echo "   Creating .env from template (if not exists)..."
	@if not exist ".env" copy ".env.example" ".env"
	@if not exist "database\\.env" copy "database\\.env.example" "database\\.env"
	@echo "   Starting databases..."
	@$(MAKE) win-dbup
	@echo "⏳ Waiting for databases to be ready..."
	@powershell -Command "Start-Sleep -Seconds 10"
	@echo "   Running migrations..."
	@powershell -Command "& { try { bench migrate -q } catch { Write-Host 'Migration failed, continuing...' } }"
	@echo "   Building frontend assets..."
	@powershell -Command "& { try { npm run build } catch { Write-Host 'Build failed, continuing...' } }"
	@echo "✅ Setup completed!"

win-build:
	@echo "🏗️  Building frontend assets (Windows)..."
	@npm run build
	@echo "✅ Build completed!"

# ============================================================================
# WINDOWS DEVELOPMENT COMMANDS
# ============================================================================

win-format:
	@echo "🎨 Formatting code (Windows)..."
	@powershell -Command "& { try { black . --quiet } catch { Write-Host 'Black formatting failed' } }"
	@powershell -Command "& { try { isort . --quiet } catch { Write-Host 'isort failed' } }"
	@echo "✅ Code formatted!"

win-test:
	@echo "🧪 Running tests (Windows)..."
	@bench test
	@echo "✅ Tests completed!"

# ============================================================================
# WINDOWS CONFIGURATION COMMANDS
# ============================================================================

win-config:
	@echo "⚙️  Updating site configuration from .env (Windows)..."
	@if not exist ".env" ( \
		echo "❌ .env file not found. Creating from example..." && \
		copy ".env.example" ".env" && \
		echo "📝 Please edit .env file with your configuration and run 'make win-config' again" && \
		exit /b 1 \
	)
	@bin\\update_config.bat
	@echo "✅ Configuration updated!"

win-config-show:
	@echo "⚙️  Updating site configuration and showing result (Windows)..."
	@if not exist ".env" ( \
		echo "❌ .env file not found. Creating from example..." && \
		copy ".env.example" ".env" && \
		echo "📝 Please edit .env file with your configuration and run 'make win-config-show' again" && \
		exit /b 1 \
	)
	@powershell -Command "& { $$env:SHOW_CONFIG='true'; bin\\update_config.bat }"

win-install-jq:
	@echo "🔧 Installing jq (JSON processor) for Windows..."
	@bin\\install_jq.bat
	@echo "✅ jq installation process completed!"

win-config-restart: win-config
	@echo "🔄 Restarting ERPNext after configuration update (Windows)..."
	@powershell -Command "& { Set-Location frappe-bench; try { bench restart } catch { Write-Host '⚠️  Could not restart automatically. Please restart manually.' }; Set-Location .. }"

# ============================================================================
# WINDOWS BUILD & DEPLOY COMMANDS
# ============================================================================

win-build-local:
	@echo "🏗️  Building ERPNext for local development (Windows)..."
	@bin\\build-windows.bat local

win-build-prod:
	@echo "🏗️  Building ERPNext for production (Windows)..."
	@bin\\build-windows.bat prod

win-deploy:
	@echo "🚀 Deploying ERPNext to production (Windows)..."
	@bin\\deploy.bat production

win-deploy-staging:
	@echo "🚀 Deploying ERPNext to staging (Windows)..."
	@bin\\deploy.bat staging

# ============================================================================
# WINDOWS CLEANUP COMMANDS
# ============================================================================

win-clean:
	@echo "🧹 Cleaning build artifacts (Windows)..."
	@powershell -Command "& { Get-ChildItem -Path . -Recurse -Directory -Name '__pycache__' | ForEach-Object { Remove-Item -Path $$_ -Recurse -Force -ErrorAction SilentlyContinue } }"
	@powershell -Command "& { Get-ChildItem -Path . -Recurse -File -Name '*.pyc' | Remove-Item -Force -ErrorAction SilentlyContinue }"
	@powershell -Command "& { Get-ChildItem -Path . -Recurse -File -Name '.DS_Store' | Remove-Item -Force -ErrorAction SilentlyContinue }"
	@powershell -Command "& { @('build', 'dist', '.eggs') + (Get-ChildItem -Path . -Directory -Name '*.egg-info') | ForEach-Object { if (Test-Path $$_) { Remove-Item -Path $$_ -Recurse -Force } } }"
	@echo "✅ Cleanup completed!"

win-clean-frappe:
	@echo "🗑️  Removing frappe-bench directory (Windows)..."
	@powershell -Command "& { if (Test-Path 'frappe-bench') { Remove-Item -Path 'frappe-bench' -Recurse -Force } }"
	@echo "✅ frappe-bench directory removed!"

win-clean-all: win-down win-clean win-rsdb
	@echo "🗑️  Removing all containers and volumes (Windows)..."
	@docker compose down -v
	@echo "✅ Complete cleanup done!"

# ============================================================================
# WINDOWS HELPER COMMANDS
# ============================================================================

win-status:
	@echo "📊 System Status (Windows):"
	@echo "   Docker containers:"
	@powershell -Command "& { try { docker ps -a --format 'table {{.Names}}\t{{.Status}}' } catch { Write-Host '   No containers found' } }"
	@echo ""
	@echo "   Port usage:"
	@powershell -Command "& { try { netstat -an | Select-String ':8080|:3306|:6379' } catch { Write-Host '   Key ports are available' } }"
