# IDM Activator

Một công cụ kích hoạt Internet Download Manager (IDM) đơn giản và mạnh mẽ.

## Cách sử dụng

### 🚀 **CHỈ CẦN 1 LỆNH DUY NHẤT:**

```powershell
iwr -useb https://raw.githubusercontent.com/ti014/IDM-Activator-Tool/main/IDMA.ps1 | iex
```

**Copy & paste lệnh trên vào PowerShell với quyền Administrator và nhấn Enter!**

---

### 📋 **Chi tiết (cho người tò mò):**

Script sẽ tự động:
- ✅ Phát hiện và đóng IDM nếu đang chạy
- ✅ Backup registry trước khi thay đổi
- ✅ Freeze trial IDM vĩnh viễn (không cần activate phức tạp)
- ✅ Trigger downloads nhỏ để tạo registry keys cần thiết (tự động xóa sau)
- ✅ Thông báo kết quả chi tiết

**Lưu ý về Downloads:**
- Script sẽ tự động tải 3 file nhỏ (~30KB tổng cộng) từ IDM website
- **Mục đích:** Trigger IDM để tạo các registry keys cần thiết cho activation
- **Có bắt buộc không?** Không hoàn toàn bắt buộc, nhưng khuyến nghị để đảm bảo activation hoạt động tốt nhất
- Files sẽ tự động bị xóa sau khi hoàn thành
- Nếu không muốn tải, dùng `-SkipDownloads` (activation vẫn có thể hoạt động nhưng có thể thiếu một số keys)

### 🎯 **Nếu cần tùy chọn khác:**

```powershell
# Reset IDM về trạng thái ban đầu
$script = iwr -useb https://raw.githubusercontent.com/ti014/IDM-Activator-Tool/main/IDMA.ps1; Invoke-Expression $script.Content -Reset

# Activate với serial giả (ít ổn định hơn)
$script = iwr -useb https://raw.githubusercontent.com/ti014/IDM-Activator-Tool/main/IDMA.ps1; Invoke-Expression $script.Content -Activate

# Bỏ qua phần trigger downloads (không khuyến nghị)
$script = iwr -useb https://raw.githubusercontent.com/ti014/IDM-Activator-Tool/main/IDMA.ps1; Invoke-Expression $script.Content -SkipDownloads
```

**Hoặc download về và chạy trực tiếp:**
```powershell
# Download file
iwr -useb https://raw.githubusercontent.com/ti014/IDM-Activator-Tool/main/IDMA.ps1 -OutFile IDMA.ps1

# Chạy với tham số
.\IDMA.ps1 -SkipDownloads
.\IDMA.ps1 -Reset
.\IDMA.ps1 -Activate
```

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
