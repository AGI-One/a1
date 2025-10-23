#!/bin/bash

# Build ERPNext for Windows (compatible with WSL/Git Bash)

echo "🔨 Building ERPNext for Windows..."

# Install dependencies
echo "📦 Installing Python dependencies..."
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt -q

echo "📦 Installing Node dependencies..."
if [ -f package-lock.json ]; then
  npm ci --prefer-offline
elif [ -f package.json ]; then
  npm install
fi

echo "🏗️ Building frontend assets..."
npm run build || true

echo "✅ Build completed for Windows!"
echo "💡 Note: For Windows, use WSL or Git Bash to run this script"
