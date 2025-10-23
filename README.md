# Hướng dẫn sử dụng hệ thống Modules

## Tổng quan

Hệ thống này cho phép bạn quản lý các modules/apps Frappe thông qua file cấu hình JSON, hỗ trợ cả modules từ Git repository và modules local. Local modules được volume-mapped để tận dụng live reload trong development.

## Cấu trúc file `modules.json`

```json
{
  "modules": [
    {
      "name": "tên_module",
      "type": "git|local", 
      "repository": "https://github.com/user/repo.git", // Chỉ cho type: git
      "branch": "main",                                  // Chỉ cho type: git
      "path": "modules/custom_module",                   // Chỉ cho type: local
      "required": true|false,
      "description": "Mô tả module"
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

## Các loại modules

### 1. Git Modules
Modules được tải từ Git repository:

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
Modules từ thư mục local trong `modules/`:

```json
{
  "name": "erpnext",
  "type": "local", 
  "path": "modules/erpnext",
  "required": false,
  "description": "ERPNext application from local source"
}
```

**Lưu ý**: ERPNext trong dự án này được cấu hình như local module để hỗ trợ development và customization.

## Cấu trúc thư mục Local Modules

Mỗi local module cần có cấu trúc sau trong thư mục `modules/`:

```
modules/
├── erpnext/                        # ERPNext local module
│   ├── pyproject.toml              # Cấu hình Python package
│   ├── README.md                   # Tài liệu
│   └── erpnext/                    # Package chính
│       ├── __init__.py            # File khởi tạo
│       ├── hooks.py               # Frappe hooks
│       └── modules.txt            # Danh sách modules
```

**Ví dụ thực tế**: Xem thư mục `modules/erpnext/` để tham khảo cấu trúc hoàn chỉnh của một local module.

## Cách thêm module mới

### 1. Thêm Git Module
Chỉnh sửa `modules.json`:

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

Sau đó rebuild container để áp dụng thay đổi:
```bash
docker-compose down
docker-compose up -d
```

### 2. Thêm Local Module

1. Tạo thư mục module:
```bash
mkdir -p modules/my_custom_module
```

2. Tạo cấu trúc files cần thiết (tham khảo `modules/erpnext/` để xem cấu trúc chi tiết)

3. Thêm vào `modules.json`:
```json
{
  "name": "my_custom_module",
  "type": "local",
  "path": "modules/my_custom_module", 
  "required": false,
  "description": "Module tùy chỉnh của tôi"
}
```

4. Cập nhật `apps_txt_order` trong config nếu cần thiết.

## Volume Mapping cho Development

Docker Compose đã được cấu hình để hỗ trợ live development:

```yaml
volumes:
  - agi-next:/app                    # Named volume để persist frappe-bench data
  - ./modules:/app/modules           # Mount local modules để development
```

### Live Reload Workflow:

1. **Host**: Bạn edit code trong `./modules/erpnext/` hoặc local module khác
2. **Container**: Script tạo symlink `/app/frappe-bench/apps/erpnext -> /app/modules/erpnext`
3. **Result**: Thay đổi code trên host được reflect ngay lập tức trong container

### Lợi ích:
- ✅ **Live reload**: Edit code trên host, thấy ngay trong container
- ✅ **No rebuild**: Không cần rebuild image khi thay đổi local modules  
- ✅ **Persistent data**: frappe-bench data được lưu trong named volume
- ✅ **Git friendly**: Local modules có thể commit/push như bình thường

## Quy trình hoạt động

1. `startup.sh` đọc file `modules.json`
2. Tạo workspace directory `/app/frappe-bench`
3. Cài đặt từng module theo cấu hình:
   - **Frappe framework**: Khởi tạo bench bằng `bench init` (xử lý đặc biệt)
   - **Git modules**: Sử dụng `bench get-app`
   - **Local modules**: Tạo symlink từ volume-mapped modules (tránh copy, hỗ trợ live reload)
4. Tạo `apps.txt` theo thứ tự trong `apps_txt_order`
5. Setup site configuration và permissions
6. Tạo site và cài đặt các apps theo thứ tự trong `apps.txt`

## Lưu ý quan trọng

- **Module frappe**: Là module đặc biệt, sẽ khởi tạo bench workspace bằng `bench init`
- Modules có `required: true` sẽ dừng quá trình nếu cài đặt thất bại
- Modules có `required: false` sẽ được bỏ qua nếu cài đặt thất bại  
- Local modules cần có file `pyproject.toml` hoặc `setup.py`
- Thứ tự trong `apps_txt_order` quyết định thứ tự cài đặt apps vào site
- Local modules được symlink thay vì copy để hỗ trợ live reload
- Volume mapping cho phép chỉnh sửa code trong local modules mà không cần rebuild container

## Testing & Debugging

Sử dụng script test để kiểm tra cấu hình:

```bash
./test-modules-config.sh
```

Script sẽ kiểm tra:
- Syntax của `modules.json`
- Sự tồn tại của local modules
- Cấu trúc files cần thiết
- Volume mapping configuration

## Ví dụ hoàn chỉnh

Xem file `modules.json` để tham khảo cấu hình hiện tại của dự án, bao gồm:
- **frappe**: Core framework (Git module, required)
- **erpnext**: ERP application (Local module để development)
- **hrms**: Human Resource Management (Git module)
- **crm**: Customer Relationship Management (Git module)
- **lms**: Learning Management System (Git module)

Thư mục `modules/erpnext/` chứa ví dụ hoàn chỉnh về cấu trúc của một local module.

## Modules hiện tại trong dự án

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