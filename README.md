# KIỂM ĐẾM PHIẾU BẦU MOBILE PRO

Dự án Flutter Android dùng để thiết lập cuộc bầu cử, nhập phiếu, quản lý phiếu đã sửa, thống kê xếp hạng, xuất PDF và chia sẻ dữ liệu.

## Cấu trúc

- `android/`: dự án Android dùng để build APK.
- `lib/database/`: SQLite và lưu dữ liệu.
- `lib/pages/`: giao diện chính và nhập phiếu.
- `lib/models/`: mô hình dữ liệu.
- `lib/services/`: quy tắc kiểm tra phiếu.
- `lib/widgets/`: widget dùng chung.
- `lib/utils/`: thông tin ứng dụng.
- `codemagic.yaml`: build APK online bằng Codemagic.
- `.github/workflows/build-apk.yml`: build dự phòng bằng GitHub Actions.

## Build trên Codemagic

1. Upload toàn bộ nội dung dự án lên repository GitHub.
2. Trong Codemagic, chọn repository và loại dự án Flutter.
3. Chọn nhánh `main`.
4. Bấm **Check for configuration files**.
5. Chọn workflow **KIEM DEM PHIEU BAU - APK RELEASE**.
6. Bấm **Start new build**.
7. Tải `app-release.apk` trong mục Artifacts.


## Cấu hình máy build

Dự án dùng `instance_type: linux` để tương thích với tài khoản Codemagic miễn phí.
