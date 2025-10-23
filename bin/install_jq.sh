#!/bin/bash

# Helper script to install jq if not available
# jq is required for JSON manipulation in update_config.sh

print_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Check if jq is installed
if command -v jq &> /dev/null; then
    print_info "jq is already installed: $(jq --version)"
    exit 0
fi

print_info "jq is not installed. Installing..."

# Detect OS and install jq
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null; then
        brew install jq
        print_info "jq installed successfully via Homebrew"
    else
        print_error "Homebrew not found. Please install Homebrew first or install jq manually"
        print_info "Visit: https://brew.sh/"
        exit 1
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
        print_info "jq installed successfully via apt-get"
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
        print_info "jq installed successfully via yum"
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y jq
        print_info "jq installed successfully via dnf"
    else
        print_error "Package manager not found. Please install jq manually"
        exit 1
    fi
else
    print_error "Unsupported OS: $OSTYPE"
    print_info "Please install jq manually from: https://jqlang.github.io/jq/"
    exit 1
fi

# Verify installation
if command -v jq &> /dev/null; then
    print_info "jq installation verified: $(jq --version)"
else
    print_error "jq installation failed"
    exit 1
fi