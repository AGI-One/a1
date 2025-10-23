# Modules System User Guide

## Overview

This system allows you to manage Frappe modules/apps through a JSON configuration file, supporting both Git repository modules and local modules. Local modules are volume-mapped to leverage live reload during development.

## `modules.json` File Structure

```json
{
  "modules": [
    {
      "name": "module_name",
      "type": "git|local", 
      "repository": "https://github.com/user/repo.git", // For type: git only
      "branch": "main",                                  // For type: git only
      "path": "modules/custom_module",                   // For type: local only
      "required": true|false,
      "description": "Module description"
    }
  ],
  "config": {
    "frappe_version": "version-15",
    "python_version": "3.11", 
    "node_version": "18",
    "apps_txt_order": ["frappe", "erpnext", "hrms", "crm", "lms"]
  }
}
```

## Module Types

### 1. Git Modules
Modules downloaded from Git repositories:

```json
{
  "name": "hrms",
  "type": "git",
  "repository": "https://github.com/frappe/hrms.git",
  "branch": "version-15",
  "required": false,
  "description": "Human Resource Management System"
}
```

### 2. Local Modules  
Modules from local directories in `modules/`:

```json
{
  "name": "erpnext",
  "type": "local", 
  "path": "modules/erpnext",
  "required": false,
  "description": "ERPNext application from local source"
}
```

**Note**: ERPNext in this project is configured as a local module to support development and customization.

## Local Modules Directory Structure

Each local module needs the following structure in the `modules/` directory:

```
modules/
├── erpnext/                        # ERPNext local module
│   ├── pyproject.toml              # Python package configuration
│   ├── README.md                   # Documentation
│   └── erpnext/                    # Main package
│       ├── __init__.py            # Initialization file
│       ├── hooks.py               # Frappe hooks
│       └── modules.txt            # Module list
```

**Real Example**: See the `modules/erpnext/` directory for a complete structure reference of a local module.

## Adding New Modules

### 1. Adding Git Module
Edit `modules.json`:

```json
{
  "name": "custom_app",
  "type": "git",
  "repository": "https://github.com/user/custom_app.git", 
  "branch": "main",
  "required": false,
  "description": "Custom application"
}
```

Then rebuild the container to apply changes:
```bash
docker-compose down
docker-compose up -d
```

### 2. Adding Local Module

1. Create module directory:
```bash
mkdir -p modules/my_custom_module
```

2. Create necessary file structure (refer to `modules/erpnext/` for detailed structure)

3. Add to `modules.json`:
```json
{
  "name": "my_custom_module",
  "type": "local",
  "path": "modules/my_custom_module", 
  "required": false,
  "description": "My custom module"
}
```

4. Update `apps_txt_order` in config if necessary.

## Volume Mapping for Development

Docker Compose is configured to support live development:

```yaml
volumes:
  - agi-next:/app                    # Named volume to persist frappe-bench data
  - ./modules:/app/modules           # Mount local modules for development
```

### Live Reload Workflow:

1. **Host**: You edit code in `./modules/erpnext/` or other local modules
2. **Container**: Script creates symlink `/app/frappe-bench/apps/erpnext -> /app/modules/erpnext`
3. **Result**: Code changes on host are immediately reflected in container

### Benefits:
- ✅ **Live reload**: Edit code on host, see changes immediately in container
- ✅ **No rebuild**: No need to rebuild image when changing local modules  
- ✅ **Persistent data**: frappe-bench data saved in named volume
- ✅ **Git friendly**: Local modules can be committed/pushed as usual

## Workflow Process

1. `startup.sh` reads the `modules.json` file
2. Creates workspace directory `/app/frappe-bench`
3. Installs each module according to configuration:
   - **Frappe framework**: Initialize bench using `bench init` (special handling)
   - **Git modules**: Use `bench get-app`
   - **Local modules**: Create symlinks from volume-mapped modules (avoid copying, support live reload)
4. Create `apps.txt` in order specified in `apps_txt_order`
5. Setup site configuration and permissions
6. Create site and install apps in order specified in `apps.txt`

## Important Notes

- **Frappe module**: Special module that initializes bench workspace using `bench init`
- Modules with `required: true` will stop the process if installation fails
- Modules with `required: false` will be skipped if installation fails  
- Local modules need `pyproject.toml` or `setup.py` file
- Order in `apps_txt_order` determines the installation order of apps into site
- Local modules are symlinked instead of copied to support live reload
- Volume mapping allows editing code in local modules without rebuilding container

## Testing & Debugging

Use test script to check configuration:

```bash
./test-modules-config.sh
```

The script will check:
- `modules.json` syntax
- Existence of local modules
- Required file structure
- Volume mapping configuration

## Complete Example

See `modules.json` file for current project configuration reference, including:
- **frappe**: Core framework (Git module, required)
- **erpnext**: ERP application (Local module for development)
- **hrms**: Human Resource Management (Git module)
- **crm**: Customer Relationship Management (Git module)
- **lms**: Learning Management System (Git module)

The `modules/erpnext/` directory contains a complete example of local module structure.

## Current Modules in Project

```json
{
  "modules": [
    {
      "name": "frappe",
      "type": "git",
      "repository": "https://github.com/frappe/frappe.git",
      "branch": "version-15",
      "required": true,
      "description": "Core Frappe framework"
    },
    {
      "name": "erpnext",
      "type": "local",
      "path": "modules/erpnext",
      "required": false,
      "description": "ERPNext application from local source"
    },
    {
      "name": "hrms",
      "type": "git",
      "repository": "https://github.com/frappe/hrms.git",
      "branch": "version-15",
      "required": false,
      "description": "Human Resource Management System"
    },
    {
      "name": "crm",
      "type": "git",
      "repository": "https://github.com/frappe/crm.git",
      "branch": "main",
      "required": false,
      "description": "Customer Relationship Management"
    },
    {
      "name": "lms",
      "type": "git",
      "repository": "https://github.com/frappe/lms.git",
      "branch": "main",
      "required": false,
      "description": "Learning Management System"
    }
  ],
  "config": {
    "frappe_version": "version-15",
    "python_version": "3.11",
    "node_version": "18",
    "apps_txt_order": ["frappe", "erpnext", "hrms", "crm", "lms"]
  }
}
```

## Development vs Production Mode

### Development Mode (Local)
Uses `docker-compose.local.yml` and `Dockerfile.local`:
- **Script**: `scripts/startup.sh`
- **Command**: `bench start`
- **Port**: 8080 (direct to bench)
- **Live reload**: Supports real-time code changes
- **Volume mapping**: Local modules mounted for development

```bash
# Run development mode
docker-compose -f docker-compose.local.yml up -d
```

### Production Mode
Uses `docker-compose.yml` and `Dockerfile.prod`:
- **Script**: `scripts/startup-prod.sh`
- **Command**: `sudo bench setup production frappe`
- **Ports**: 80 (nginx), 8000 (backend)
- **Services**: Supervisor + Nginx
- **Data persistence**: Named volume `erpnext-production-data`

```bash
# Run production mode
docker-compose up -d

# Check status
docker-compose exec erpnext-app sudo supervisorctl status
docker-compose exec erpnext-app sudo service nginx status
```

### Detailed Comparison

| Feature | Development | Production |
|---------|------------|------------|
| Dockerfile | `Dockerfile.local` | `Dockerfile.prod` |
| Startup Script | `startup.sh` | `startup-prod.sh` |
| Bench Mode | Development (`bench start`) | Production (`bench setup production`) |
| Web Server | Flask Dev Server | Nginx + Gunicorn |
| Process Manager | None | Supervisor |
| Port Mapping | 8080:8000 | 8080:80, 8000:8000 |
| Auto-reload | Yes (can add watchexec) | No |
| Volumes | Module mount for live coding | Named volume for persistence |
| Privileges | Normal | Privileged (for supervisor/nginx) |

## Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd a1
   ```

2. **Configure modules** (optional)
   ```bash
   cp modules.example.json modules.json
   # Edit modules.json as needed
   ```

3. **Start development environment**
   ```bash
   # Development mode
   docker-compose -f docker-compose.local.yml up -d
   
   # Or production mode
   docker-compose up -d
   ```

4. **Access the application**
   - Development: http://localhost:8080
   - Production: http://localhost:8080

5. **Check logs**
   ```bash
   # Development logs
   ./bin/dev-logs.sh
   
   # Production logs
   docker-compose logs -f
   ```

## Useful Commands

```bash
# Build and run containers
make up

# Check development setup
./check-dev-setup.sh

# View logs
./bin/dev-logs.sh  # Development
docker-compose logs -f  # Production

# Execute commands in container
docker-compose exec erpnext-app bash

# Run bench commands
docker-compose exec erpnext-app bench --help
```

## Troubleshooting

### Common Issues

1. **Module not found**: Check if module path exists and `modules.json` syntax is correct
2. **Permission errors**: Ensure proper file permissions for local modules
3. **Build failures**: Check if all required dependencies are specified in module configuration
4. **Site access issues**: Verify port mapping and firewall settings

### Debugging Steps

1. Check container logs:
   ```bash
   docker-compose logs erpnext-app
   ```

2. Access container shell:
   ```bash
   docker-compose exec erpnext-app bash
   ```

3. Verify bench status:
   ```bash
   docker-compose exec erpnext-app bench --version
   ```

4. Check site status:
   ```bash
   docker-compose exec erpnext-app bench --site all list-apps
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test your changes thoroughly
5. Submit a pull request

## License

This project follows the same license as the Frappe framework and ERPNext application.