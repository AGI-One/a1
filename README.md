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
  "name": "erpnext",
  "type": "git",
  "repository": "https://github.com/frappe/erpnext.git",
  "branch": "version-15",
  "required": true,
  "description": "ERPNext application"
}
```

### 2. Local Modules  
Modules từ thư mục local trong `modules/`:

```json
{
  "name": "custom_module",
  "type": "local", 
  "path": "modules/custom_module",
  "required": false,
  "description": "Custom module"
}
```

## Cấu trúc thư mục Local Modules

Mỗi local module cần có cấu trúc sau trong thư mục `modules/`:

```
modules/
├── custom_module_example/
│   ├── pyproject.toml              # Cấu hình Python package
│   ├── README.md                   # Tài liệu
│   └── custom_module_example/      # Package chính
│       ├── __init__.py            # File khởi tạo
│       ├── hooks.py               # Frappe hooks
│       └── modules.txt            # Danh sách modules
```

## Cách thêm module mới

### 1. Thêm Git Module
Chỉnh sửa `modules.json`:

```json
{
  "name": "new_module",
  "type": "git",
  "repository": "https://github.com/user/new_module.git", 
  "branch": "main",
  "required": false,
  "description": "Module mới"
}
```

### 2. Thêm Local Module

1. Tạo thư mục module:
```bash
mkdir modules/my_custom_module
```

2. Tạo cấu trúc files cần thiết (xem ví dụ trong `modules/custom_module_example/`)

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

1. **Host**: Bạn edit code trong `./modules/custom_module_example/`
2. **Container**: Script tạo symlink `/app/frappe-bench/apps/custom_module_example -> /app/modules/custom_module_example`
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

Xem file `modules.json` và thư mục `modules/custom_module_example/` để tham khảo cách cấu hình và tạo local module.