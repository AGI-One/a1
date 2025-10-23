#!/bin/bash

# Script to update frappe-bench/sites/common_site_config.json with environment variables
# Author: Generated script for ERPNext configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Define paths
ENV_FILE="./.env"
CONFIG_FILE="./frappe-bench/sites/common_site_config.json"

print_info "Starting ERPNext configuration update..."

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    print_error ".env file not found at $ENV_FILE"
    print_info "Please create .env file based on database/.env.example"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    print_error "Configuration file not found at $CONFIG_FILE"
    print_info "Please ensure frappe-bench is properly initialized"
    exit 1
fi

print_info "Loading environment variables from $ENV_FILE"

# Source the .env file
set -a  # automatically export all variables
source "$ENV_FILE"
set +a

# Create backup of current config
BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$BACKUP_FILE"
print_info "Backup created: $BACKUP_FILE"

# Function to update JSON field using jq
update_json_field() {
    local key="$1"
    local value="$2"
    local temp_file=$(mktemp)
    
    if [ -n "$value" ]; then
        jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
        print_info "Updated $key = $value"
    else
        print_warning "Skipping $key (empty value)"
    fi
}

# Function to update JSON field with numeric value
update_json_numeric_field() {
    local key="$1"
    local value="$2"
    local temp_file=$(mktemp)
    
    if [ -n "$value" ]; then
        jq --arg key "$key" --argjson value "$value" '.[$key] = $value' "$CONFIG_FILE" > "$temp_file"
        mv "$temp_file" "$CONFIG_FILE"
        print_info "Updated $key = $value (numeric)"
    else
        print_warning "Skipping $key (empty value)"
    fi
}

# Function to build Redis URL
build_redis_url() {
    local purpose="$1"  # cache, queue, socketio
    local host="${REDIS_HOST:-localhost}"
    local port="6379"
    # local db=""
    local password="${REDIS_PASSWORD}"
    
    # Set different ports for different purposes
    # case "$purpose" in
    #     "cache")
    #         db="${REDIS_CACHE_DB:-'/1'}"
    #         ;;
    #     "queue")
    #         db="${REDIS_QUEUE_DB:-'/2'}"
    #         ;;
    #     "socketio")
    #         db="${REDIS_SOCKETIO_DB:-'/3'}"
    #         ;;
    #     *)
    #         db="${REDIS_PORT:-''}"
    #         ;;
    # esac
    
    if [ -n "$password" ]; then
        echo "redis://:${password}@${host}:${port}"
    else
        echo "redis://${host}:${port}${db}"
    fi
}

print_info "Updating configuration fields..."

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is required but not installed. Please install jq first:"
    print_info "  macOS: brew install jq"
    print_info "  Ubuntu/Debian: sudo apt-get install jq"
    print_info "  CentOS/RHEL: sudo yum install jq"
    exit 1
fi

# Update database configuration
update_json_field "db_host" "${DB_HOST:-localhost}"
update_json_field "db_name" "${MARIADB_DATABASE:-erpnext}"
update_json_field "db_user" "${MARIADB_USER:-erpnext}"
update_json_field "db_password" "${MARIADB_PASSWORD}"
update_json_field "db_type" "${DB_TYPE:-mariadb}"
update_json_field "root_password" "${MARIADB_ROOT_PASSWORD}"
update_json_numeric_field "maintenance_mode" "${MAINTENANCE_MODE:-0}"

# Update Redis configuration
if [ -n "$REDIS_HOST" ] || [ -n "$REDIS_PASSWORD" ]; then
    print_info "Updating Redis configuration..."
    
    redis_cache_url=$(build_redis_url "cache")
    redis_queue_url=$(build_redis_url "queue")
    redis_socketio_url=$(build_redis_url "socketio")
    
    update_json_field "redis_cache" "$redis_cache_url"
    update_json_field "redis_queue" "$redis_queue_url"
    update_json_field "redis_socketio" "$redis_socketio_url"
else
    print_warning "Redis configuration not found in environment variables"
fi

# Validate JSON syntax
if jq empty "$CONFIG_FILE" 2>/dev/null; then
    print_info "Configuration file updated successfully!"
    print_info "Updated file: $CONFIG_FILE"
else
    print_error "Invalid JSON generated. Restoring backup..."
    mv "$BACKUP_FILE" "$CONFIG_FILE"
    exit 1
fi

# Display the updated configuration (optional)
if [ "${SHOW_CONFIG:-false}" = "true" ]; then
    print_info "Current configuration:"
    jq . "$CONFIG_FILE"
fi

print_info "Configuration update completed successfully!"
print_info "Backup available at: $BACKUP_FILE"

# Optional: Restart services if requested
if [ "${RESTART_SERVICES:-false}" = "true" ]; then
    print_info "Restarting Frappe services..."
    cd frappe-bench
    ./env/bin/python -m frappe --site all migrate
    bench restart
fi