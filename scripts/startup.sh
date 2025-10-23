#!/bin/bash

set -e

echo "🚀 Starting ERPNext Local Development Environment..."

# Initialize log file
LOG_FILE="/app/frappe-bench/startup.log"
echo "📝 Logging to $LOG_FILE and terminal"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Timestamp: $(date)"

# Path to modules configuration
MODULES_CONFIG="/app/modules.json"

# Function to read modules configuration
read_modules_config() {
    if [ ! -f "$MODULES_CONFIG" ]; then
        echo "❌ modules.json not found at $MODULES_CONFIG"
        exit 1
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        echo "📦 Installing jq for JSON parsing..."
        apt-get update && apt-get install -y jq
    fi
    
    echo "📋 Reading modules configuration from $MODULES_CONFIG"
}

# Function to wait for database
wait_for_db() {
    echo "⏳ Waiting for MariaDB to be ready..."
    max_attempts=30
    attempt=0
    while ! nc -z mariadb 3306 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -gt $max_attempts ]; then
            echo "❌ MariaDB not available after $max_attempts attempts"
            exit 1
        fi
        echo "   MariaDB not ready yet, waiting 2s... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    echo "✅ MariaDB is ready!"
    
    echo "⏳ Waiting for Redis to be ready..."
    attempt=0
    while ! nc -z redis 6379 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ $attempt -gt $max_attempts ]; then
            echo "❌ Redis not available after $max_attempts attempts"
            exit 1
        fi
        echo "   Redis not ready yet, waiting 2s... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    echo "✅ Redis is ready!"
}

# Function to check frappe-bench workspace
check_bench_workspace() {
    echo "🔧 Checking frappe-bench workspace..."
    if [ -d "/app/frappe-bench/apps/frappe" ]; then
        echo "✅ frappe-bench with Frappe framework already exists"
        cd /app/frappe-bench
    elif [ -d "/app/frappe-bench" ]; then
        echo "⚠️ frappe-bench exists but Frappe framework is missing"
    else
        echo "📦 frappe-bench workspace will be created during module installation"
    fi
}

# Function to setup site configuration
setup_site_config() {
    echo "⚙️ Setting up site configuration..."
    
    cd /app/frappe-bench
    
    if ! id frappe >/dev/null 2>&1; then
        useradd -m -s /bin/bash frappe
    fi
    
    chown -R frappe:frappe /app/frappe-bench
    
    if [ -f /app/.env ]; then
        echo "📝 Updating configuration from .env..."
        cd /app && make install-jq && make config
        cd /app/frappe-bench
    fi
    if [ -f /app/sites/common_site_config.json ]; then
        cp /app/sites/common_site_config.json sites/common_site_config.json
        echo "✅ Site config copied"
    fi
}

# Function to install modules based on configuration
install_modules_if_needed() {
    echo "📦 Installing modules based on configuration..."
    
    # Process each module first (especially frappe to initialize bench)
    jq -c '.modules[]' "$MODULES_CONFIG" | while IFS= read -r module; do
        local name=$(echo "$module" | jq -r '.name')
        local type=$(echo "$module" | jq -r '.type')
        local required=$(echo "$module" | jq -r '.required')
        local description=$(echo "$module" | jq -r '.description')
        
        echo "🔍 Processing module: $name ($description)"
        
        # Special handling for frappe framework
        if [ "$name" = "frappe" ]; then
            if [ -d "/app/frappe-bench/apps/frappe" ]; then
                echo "   ✅ Frappe framework already installed"
                continue
            fi
            
            echo "   🚀 Installing Frappe framework and initializing bench..."
            local repository=$(echo "$module" | jq -r '.repository')
            local branch=$(echo "$module" | jq -r '.branch')
            
            # If frappe-bench exists but apps/frappe doesn't, we need to remove and recreate
            if [ -d "/app/frappe-bench" ] && [ ! -d "/app/frappe-bench/apps/frappe" ]; then
                echo "   🗑️ Removing incomplete frappe-bench directory..."
                rm -rf /app/frappe-bench
            fi
            
            cd /app
            if bench init --frappe-branch "$branch" frappe-bench --skip-redis-config-generation; then
                echo "   ✅ Frappe framework installed and bench initialized"
                cd /app/frappe-bench/apps/frappe
                pip install -e .
                bench setup requirements
                cd /app/frappe-bench
            else
                echo "   ❌ Failed to initialize frappe-bench with frappe framework"
                exit 1
            fi
            continue
        fi
        
        # Check if module already exists
        if [ -d "/app/frappe-bench/apps/$name" ]; then
            echo "   ✅ Module '$name' already installed"
            continue
        fi
        
        # Install based on type
        case "$type" in
            "git")
                local repository=$(echo "$module" | jq -r '.repository')
                local branch=$(echo "$module" | jq -r '.branch')
                
                echo "   📥 Installing git module: $name from $repository (branch: $branch)"
                cd /app/frappe-bench
                if bench get-app "$repository" --branch "$branch"; then
                    echo "   ✅ Successfully installed $name"
                else
                    if [ "$required" = "true" ]; then
                        echo "   ❌ Failed to install required module: $name"
                        exit 1
                    else
                        echo "   ⚠️ Failed to install optional module: $name, continuing..."
                    fi
                fi
                ;;
                
            "local")
                local local_path=$(echo "$module" | jq -r '.path')
                local source_path="/app/$local_path"
                local apps_path="/app/frappe-bench/apps/$name"
                
                echo "   📁 Installing local module: $name from $local_path"
                
                # Check if source path exists (should be volume-mapped)
                if [ ! -d "$source_path" ]; then
                    if [ "$required" = "true" ]; then
                        echo "   ❌ Required local module path not found: $source_path"
                        exit 1
                    else
                        echo "   ⚠️ Optional local module path not found: $source_path, skipping..."
                        continue
                    fi
                fi
                
                # Validate local module structure
                if [ ! -f "$source_path/pyproject.toml" ] && [ ! -f "$source_path/setup.py" ]; then
                    echo "   ⚠️ Local module $name missing setup files, skipping..."
                    continue
                fi
                
                # Ensure frappe-bench/apps directory exists
                mkdir -p /app/frappe-bench/apps
                
                # Remove existing if it's not a symlink (could be a directory from previous runs)
                if [ -d "$apps_path" ] && [ ! -L "$apps_path" ]; then
                    echo "   �️ Removing existing directory: $apps_path"
                    rm -rf "$apps_path"
                fi
                
                # Create symlink for live development (changes in host will reflect immediately)
                if [ ! -L "$apps_path" ]; then
                    echo "   � Creating symlink for live development: $apps_path -> $source_path"
                    ln -sf "$source_path" "$apps_path"
                else
                    echo "   ✅ Symlink already exists: $apps_path"
                fi
                
                # Install module dependencies if frappe-bench is ready
                if [ -d "/app/frappe-bench/apps/frappe" ]; then
                    cd /app/frappe-bench
                    if pip install -e "$apps_path"; then
                        echo "   ✅ Successfully installed local module: $name"
                    else
                        echo "   ⚠️ Failed to install local module dependencies: $name"
                        if [ "$required" = "true" ]; then
                            exit 1
                        fi
                    fi
                else
                    echo "   ⏳ Will install dependencies after frappe framework is ready"
                fi
                ;;
                
            *)
                echo "   ⚠️ Unknown module type: $type for module $name"
                ;;
        esac
    done
    
    # Install dependencies for local modules that were processed before frappe was ready
    if [ -d "/app/frappe-bench/apps/frappe" ]; then
        echo "🔧 Installing dependencies for local modules..."
        cd /app/frappe-bench
        jq -c '.modules[] | select(.type == "local")' "$MODULES_CONFIG" | while IFS= read -r module; do
            local name=$(echo "$module" | jq -r '.name')
            local apps_path="/app/frappe-bench/apps/$name"
            
            if [ -L "$apps_path" ] || [ -d "$apps_path" ]; then
                echo "   📦 Installing dependencies for: $name"
                if pip install -e "$apps_path" 2>/dev/null; then
                    echo "   ✅ Dependencies installed for: $name"
                else
                    echo "   ⚠️ Failed to install dependencies for: $name"
                fi
            fi
        done
    fi
    
    # Create apps.txt after all modules are installed
    if [ -d "/app/frappe-bench" ]; then
        echo "📝 Creating apps.txt from configuration..."
        mkdir -p /app/frappe-bench/sites
        local apps_order=$(jq -r '.config.apps_txt_order[]' "$MODULES_CONFIG" 2>/dev/null || echo "frappe")
        echo "$apps_order" > /app/frappe-bench/sites/apps.txt
        echo "✅ apps.txt created from configuration"
    fi
    
    echo "✅ Module installation completed"
}

# Function to create site and install apps
create_site_if_needed() {
    echo "🏗️ Checking site 'localhost'..."
    if [ -d "/app/frappe-bench/sites/localhost/" ]; then
        echo "⚠️ Site 'localhost' exists, recreating with --force..."
        bench new-site localhost --force --admin-password admin
        bench --site localhost set-admin-password admin
        install_apps_to_site
        return
    fi
    
    echo "🏗️ Creating new site 'localhost'..."
    max_retries=3
    retry_count=0
    while [ $retry_count -lt $max_retries ]; do
        if bench new-site localhost --admin-password admin; then
            echo "✅ Site 'localhost' created successfully!"
            bench --site localhost set-admin-password admin
            install_apps_to_site
            bench update --reset
            bench --site localhost migrate --admin-password admin
            break
        else
            retry_count=$((retry_count + 1))
            echo "❌ Failed to create site (attempt $retry_count/$max_retries)"
            if [ $retry_count -eq $max_retries ]; then
                echo "❌ Max retries reached. Check database configuration (mariadb host, user, password)."
                exit 1
            fi
            sleep 2
        fi
    done
}

# Function to install apps to site based on configuration
install_apps_to_site() {
    echo "📱 Installing apps to site based on configuration..."
    
    # Install apps in the order specified in apps.txt
    while IFS= read -r app_name; do
        if [ -d "/app/frappe-bench/apps/$app_name" ] && [ -n "$app_name" ]; then
            echo "   📱 Installing app: $app_name"
            if bench --site localhost install-app "$app_name"; then
                echo "   ✅ Successfully installed app: $app_name"
            else
                echo "   ⚠️ Failed to install app: $app_name, continuing..."
            fi
        fi
    done < /app/frappe-bench/sites/apps.txt
    
    echo "✅ App installation to site completed"
}

# Function to start development server
start_server() {
    echo "🔥 Starting development server..."
    echo "   ERPNext will be available at: http://localhost:8080"
    echo "   Default credentials: Administrator / admin"
    cd /app/frappe-bench
    
    # Check environment variable to determine which command to run
    if [ "$ENVIRONMENT" = "production" ] || [ "$ENV" = "production" ] || [ "$NODE_ENV" = "production" ]; then
        echo "🚀 Starting in production mode..."
        sudo su -
        bench setup sudoers frappe
        su - frappe
        exec sudo bench setup production frappe
    else
        echo "🔥 Starting in development mode with auto-reload..."
        # if command -v watchexec >/dev/null 2>&1; then
        #     echo "👀 Starting with auto-reload (watchexec)..."
        #     exec watchexec \
        #         --restart \
        #         --exts py,js,html,json,css \
        #         --ignore '.git/*' '*.pyc' '__pycache__/*' '.pytest_cache/*' 'node_modules/*' 'build/*' 'dist/*' 'logs/*' '*.log' '.vscode/*' \
        #         -- bench start
        # else
        #     echo "⚠️ watchexec not found, falling back to normal bench start..."
        exec bench start
        # fi
    fi
}

# Main execution
main() {
    read_modules_config
    wait_for_db
    check_bench_workspace
    install_modules_if_needed
    setup_site_config
    create_site_if_needed
    start_server
}

trap 'echo "🛑 Shutting down..."; exit 0' SIGTERM SIGINT
main "$@"