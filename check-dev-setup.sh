#!/bin/bash

echo "🔍 Checking development setup..."

echo "📂 Modules directory:"
ls -la modules/ 2>/dev/null || echo "  No modules directory found"

echo ""
echo "🔗 Expected symlinks in container (after startup):"
echo "  /app/frappe-bench/apps/custom_module_example -> /app/modules/custom_module_example"

echo ""
echo "📝 Local modules in modules.json:"
jq -r '.modules[] | select(.type == "local") | "  - \(.name): \(.path)"' modules.json 2>/dev/null || echo "  No local modules found"

echo ""
echo "🚀 To test:"
echo "  1. make up-build"
echo "  2. Edit files in ./modules/custom_module_example/"
echo "  3. Changes should reflect immediately in container"
echo ""
echo "💡 Benefits:"
echo "  ✅ Live reload: Edit local modules on host, see changes in container"
echo "  ✅ No rebuild needed: Symlinks provide direct access"
echo "  ✅ Persistent data: frappe-bench data survives container restart"