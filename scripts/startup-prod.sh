#!/bin/bash

set -e

echo "🚀 Starting ERPNext Production Environment..."

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
        sudo useradd -m -s /bin/bash frappe
    fi
    
    sudo chown -R frappe:frappe /app/frappe-bench
    
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
                    echo "   🗑️ Removing existing directory: $apps_path"
                    rm -rf "$apps_path"
                fi
                
                # Create symlink for live development (changes in host will reflect immediately)
                if [ ! -L "$apps_path" ]; then
                    echo "   🔗 Creating symlink for live development: $apps_path -> $source_path"
                    ln -sf "$source_path" "$apps_path"
                else
                    echo "   ✅ Symlink already exists: $apps_path"
                fi
                
                # Install module dependencies if frappe-bench is ready
                if [ -d "/app/frappe-bench/apps/frappe" ]; then
                    echo "   📦 Installing dependencies for local module: $name"
                    cd "$apps_path"
                    if pip install -e .; then
                        echo "   ✅ Successfully pip installed local module: $name"
                        # Setup requirements for the local module
                        echo "   🔧 Setting up requirements for: $name"
                        cd /app/frappe-bench
                        if bench setup requirements; then
                            echo "   ✅ Requirements setup completed for: $name"
                        else
                            echo "   ⚠️ Failed to setup requirements for: $name, continuing..."
                        fi
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
        echo "🔧 Installing dependencies for deferred local modules..."
        jq -c '.modules[] | select(.type == "local")' "$MODULES_CONFIG" | while IFS= read -r module; do
            local name=$(echo "$module" | jq -r '.name')
            local apps_path="/app/frappe-bench/apps/$name"
            
            # Check if this module was deferred (symlink exists but not installed yet)
            if [ -L "$apps_path" ] || [ -d "$apps_path" ]; then
                # Check if already installed by looking for .egg-info or __pycache__
                if [ ! -d "$apps_path"/*.egg-info ] && [ ! -d "$apps_path"/__pycache__ ]; then
                    echo "   📦 Installing deferred dependencies for: $name"
                    cd "$apps_path"
                    if pip install -e . 2>/dev/null; then
                        echo "   ✅ Dependencies installed for: $name"
                        # Setup requirements for each local module
                        echo "   🔧 Setting up requirements for: $name"
                        if bench setup requirements 2>/dev/null; then
                            echo "   ✅ Requirements setup completed for: $name"
                        else
                            echo "   ⚠️ Failed to setup requirements for: $name, continuing..."
                        fi
                    else
                        echo "   ⚠️ Failed to install dependencies for: $name"
                    fi
                else
                    echo "   ✅ Dependencies already installed for: $name"
                fi
            fi
        done
        
        # Run overall bench setup requirements to ensure all dependencies are resolved
        echo "🔧 Running overall bench setup requirements..."
        cd /app/frappe-bench
        if bench setup requirements 2>/dev/null; then
            echo "✅ Overall requirements setup completed"
        else
            echo "⚠️ Some requirements setup failed, but continuing..."
        fi
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
    
    # Check if site exists with actual data (not just empty directory)
    if [ -d "/app/frappe-bench/sites/localhost/" ] && [ -f "/app/frappe-bench/sites/localhost/site_config.json" ]; then
        echo "✅ Site 'localhost' already exists with data, preserving it..."
        echo "🔄 Running migrations to update schema..."
        cd /app/frappe-bench
        bench --site localhost migrate
        
        # Verify all apps are installed
        echo "📱 Checking installed apps..."
        INSTALLED_APPS=$(bench --site localhost list-apps 2>/dev/null || echo "")
        
        # Install any missing apps from apps.txt
        if [ -f "/app/frappe-bench/sites/apps.txt" ]; then
            while IFS= read -r app_name; do
                if [ -n "$app_name" ] && [ -d "/app/frappe-bench/apps/$app_name" ]; then
                    if ! echo "$INSTALLED_APPS" | grep -q "^$app_name$"; then
                        echo "   📱 Installing missing app: $app_name"
                        bench --site localhost install-app "$app_name" || echo "   ⚠️ Failed to install $app_name"
                    fi
                fi
            done < /app/frappe-bench/sites/apps.txt
        fi
        
        echo "✅ Site validation completed, data preserved!"
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
            bench --site localhost migrate
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

# Function to setup production environment
setup_production() {
    echo "🚀 Setting up production environment..."
    cd /app/frappe-bench
    
    # Setup sudoers for frappe user
    echo "👤 Setting up sudoers for frappe user..."
    sudo -E env "PATH=$PATH" bench setup sudoers frappe
    
    # Setup production with supervisor and nginx
    echo "🔧 Setting up production with supervisor and nginx..."
    sudo -E env "PATH=$PATH" bench setup production frappe --yes
    
    echo "✅ Production setup completed"
}

# Function to start production server
start_production_server() {
    echo "🚀 Starting production server..."
    echo "   ERPNext will be available at: http://localhost:8080"
    echo "   Default credentials: Administrator / admin"
    
    cd /app/frappe-bench
    
    # Start supervisord daemon first
    echo "📊 Starting supervisord daemon..."
    sudo service supervisor start || sudo supervisord -c /etc/supervisor/supervisord.conf
    
    # Wait a moment for supervisord to initialize
    sleep 2
    
    # Now manage supervisor processes
    echo "📊 Configuring supervisor processes..."
    sudo supervisorctl reread
    sudo supervisorctl update
    sudo supervisorctl start all
    
    # Ensure nginx is running
    echo "🌐 Ensuring nginx is running..."
    sudo service nginx start || sudo service nginx restart
    
    echo "✅ Production server started successfully!"
    echo "📊 Check supervisor status: sudo supervisorctl status"
    echo "🌐 Check nginx status: sudo service nginx status"
    
    # Show current status
    echo ""
    echo "📊 Current supervisor status:"
    sudo supervisorctl status
    
    # Keep container running by tailing logs
    echo ""
    echo "📝 Following application logs..."
    tail -f /app/frappe-bench/logs/*.log
}

# Main execution
main() {
    read_modules_config
    wait_for_db
    check_bench_workspace
    install_modules_if_needed
    setup_site_config
    create_site_if_needed
    setup_production
    start_production_server
}

trap 'echo "🛑 Shutting down..."; sudo supervisorctl stop all; sudo service nginx stop; exit 0' SIGTERM SIGINT
main "$@"
