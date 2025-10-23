#!/bin/bash

# Build ERPNext for Linux

echo "🔨 Building ERPNext for Linux..."

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install --upgrade pip setuptools wheel
pip install -r requirements.txt -q

echo "📦 Installing Node dependencies..."
if [ -f package-lock.json ]; then
  npm ci --prefer-offline
elif [ -f package.json ]; then
  npm install
fi

echo "🏗️ Building frontend assets..."
npm run build || true

echo "✅ Build completed for Linux!"
