#!/bin/bash

# ERPNext deployment script for production

set -euo pipefail

LOCK_FILE="deploy.lock"

main() {
  echo "[INFO] Starting ERPNext deployment..."

  (
    flock 9
    
    echo "[INFO] Lock acquired. Starting deployment process..."

    # Update repository
    echo "[INFO] Pulling latest changes from git..."
    git pull origin

    # Install dependencies
    echo "[INFO] Installing Python dependencies..."
    pip install --upgrade pip setuptools wheel
    pip install -r requirements.txt -q

    echo "[INFO] Installing Node dependencies..."
    if [ -f package-lock.json ]; then
      npm ci --prefer-offline
    elif [ -f package.json ]; then
      npm install
    fi

    # Build frontend
    echo "[INFO] Building frontend assets..."
    npm run build || true

    # Migration if needed
    echo "[INFO] Running database migrations..."
    bench migrate || true

    # Collect static files
    echo "[INFO] Collecting static files..."
    bench build || true

    echo "[INFO] 🔄 Restarting services..."
    
    # Stop existing service
    pm2 delete erpnext || true
    
    # Load environment variables
    . bin/local-env.sh
    
    # Start new service
    pm2 start "bench start" --name erpnext
    
    # Save PM2 configuration
    pm2 save

    echo "[INFO] ✅ Deployment completed successfully!"
    
  ) 9>"$LOCK_FILE"
}

# Handle errors
trap 'echo "[ERROR] Deployment failed!"; exit 1' ERR

main
