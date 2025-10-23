#!/bin/bash

# Load environment variables from .env file

if [ ! -f .env ]; then
  echo "❌ File .env không tồn tại."
  exit 1
fi

echo "🔧 Đang load biến từ .env vào môi trường hiện tại..."

set -o allexport
source .env
set +o allexport

echo "✅ Biến môi trường đã được load."
