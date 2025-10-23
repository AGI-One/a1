#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="deploy.lock"

main() {
  echo "[INFO] Waiting for deploy lock..."

  (
    flock 9
    echo "[INFO] Lock acquired. Starting deploy..."

    git pull
    export PATH=$PATH:/usr/local/python/bin

    # Install Python dependencies
    pip install --upgrade pip setuptools wheel
    pip install -r requirements.txt -q

    # Install Node dependencies
    if [ -f package-lock.json ]; then
      npm ci --prefer-offline
    elif [ -f package.json ]; then
      npm install
    fi

    echo "[INFO] Building ERPNext..."
    npm run build || true

    echo "[INFO] Restarting service..."
    pm2 delete erpnext || true
    . bin/local-env.sh
    pm2 start "bench start" --name erpnext

    echo "[INFO] ✅ Deploy finished."
  ) 9>"$LOCK_FILE"
}

main
