#!/bin/bash

# ERPNext Docker Compose Startup Script
# Usage:
# bash bin/up.sh local       - Start in local development mode
# bash bin/up.sh localbuild  - Start local with rebuild
# bash bin/up.sh prod        - Start in production mode

env=$1

case "$env" in
  local)
    echo "🚀 Starting ERPNext in local development mode..."
    echo "   Starting database first (from database/ folder)..."
    # Create database directories and start database services
    make dbup
    echo "   Starting ERPNext app..."
    env -i PATH="$PATH" HOME="$HOME" docker compose -f docker-compose.yml -f docker-compose.local.yml up
    ;;
  localbuild)
    echo "🚀 Starting ERPNext in local development mode with rebuild..."
    echo "   Starting database first (from database/ folder)..."
    # Create database directories and start database services
    make dbup
    echo "   Building and starting ERPNext app..."
    env -i PATH="$PATH" HOME="$HOME" docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
    ;;
  prod)
    echo "🚀 Starting ERPNext in production mode..."
    env -i PATH="$PATH" HOME="$HOME" docker compose -f docker-compose.yml up --build -d
    ;;
  *)
    echo "❌ Environment not found! Please choose one of: [local, localbuild, prod]"
    exit 1
esac
