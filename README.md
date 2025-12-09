# IDM Activator

Một công cụ kích hoạt Internet Download Manager (IDM) đơn giản và mạnh mẽ.

## Cách sử dụng

### Phương pháp 1: One-liner PowerShell (Khuyến nghị - Chỉ cần copy & paste)
```powershell
# Kích hoạt IDM (Freeze Trial)
iwr -useb https://ti014.github.io/IDM-Activator/IDMA.ps1 | iex

# Reset IDM
iwr -useb https://ti014.github.io/IDM-Activator/IDMA.ps1 | iex -Reset

# Activate với serial giả
iwr -useb https://ti014.github.io/IDM-Activator/IDMA.ps1 | iex -Activate
```

### Phương pháp 2: Download và chạy trực tiếp
```bash
# Download file
wget https://ti014.github.io/IDM-Activator/IDMA.ps1 -O IDMA.ps1

# Chạy với PowerShell
powershell -ExecutionPolicy Bypass -File IDMA.ps1                    # Freeze Trial (mặc định)
powershell -ExecutionPolicy Bypass -File IDMA.ps1 -Freeze           # Freeze Trial
powershell -ExecutionPolicy Bypass -File IDMA.ps1 -Activate         # Activate với serial giả
powershell -ExecutionPolicy Bypass -File IDMA.ps1 -Reset            # Reset IDM
```

### Phương pháp 3: Batch Script (Dễ sử dụng nhất cho người mới)
```batch
# Download file CMD và chạy bằng chuột phải → "Run as administrator"
# File sẽ tự động phát hiện và thực hiện kích hoạt
```

**Hướng dẫn chi tiết:**
1. Download file `IDMA.cmd` từ repository
2. Chuột phải vào file → Chọn **"Run as administrator"**
3. Script sẽ tự động thực hiện kích hoạt IDM

## Tính năng

- ✅ **One-liner execution**: Chỉ cần paste 1 dòng lệnh
- ✅ **Freeze Trial**: Đóng băng trial 30 ngày vĩnh viễn
- ✅ **Activate**: Kích hoạt với serial giả ngẫu nhiên
- ✅ **Reset**: Reset hoàn toàn IDM về trạng thái ban đầu
- ✅ **Auto-backup**: Tự động backup registry trước khi thay đổi
- ✅ **Smart detection**: Tự động phát hiện kiến trúc hệ thống
- ✅ **Error handling**: Xử lý lỗi và thông báo chi tiết

## Yêu cầu

- Windows 7/8/8.1/10/11
- Internet Download Manager đã được cài đặt
- PowerShell (có sẵn trên Windows)
- Quyền Administrator

## Cách hoạt động

1. **Kiểm tra hệ thống**: Phát hiện IDM và quyền admin
2. **Backup registry**: Tạo backup tự động trước khi thay đổi
3. **Thay đổi registry**: Cập nhật các khóa cần thiết
4. **Trigger downloads**: Tải file để tạo registry keys
5. **Lock CLSID keys**: Khóa các key để ngăn IDM tự sửa

## Xử lý sự cố

Nếu gặp vấn đề:
1. Chạy với quyền Administrator
2. Đảm bảo IDM đã được cài đặt
3. Kiểm tra kết nối internet
4. Thử reset trước: `.\IDMA.ps1 -Reset`

## Lưu ý

- Script sẽ tự động tạo backup trong `%SystemRoot%\Temp`
- Không ảnh hưởng đến file cài đặt IDM
- Hoàn toàn reversible bằng tùy chọn `-Reset`
- Script tương thích với tất cả phiên bản IDM gần đây
