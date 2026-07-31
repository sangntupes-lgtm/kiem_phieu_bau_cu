# KIỂM ĐẾM PHIẾU BẦU PRO V1.0

Bộ phần mềm gồm ứng dụng Flutter (Android/Web) và máy chủ Node.js realtime.

## Chức năng đã có
- Tạo cuộc bầu cử, sinh mã 6 ký tự và khóa chủ sở hữu.
- Nhiều người mở cùng mã để nhập phiếu.
- Thêm/xóa người được bầu trước khi nhập phiếu.
- Giới hạn số lựa chọn trên mỗi phiếu.
- Thống kê và xếp hạng trực tiếp.
- Khóa/mở nhập phiếu.
- Đồng bộ realtime bằng Socket.IO.
- Xuất/chia sẻ báo cáo PDF tiếng Việt.
- Mã QR hiển thị mã tham gia.
- Build APK và Web bằng Codemagic.

## Chạy máy chủ trên Windows
1. Cài Node.js 20.
2. Mở thư mục `server`.
3. Chạy `npm install`.
4. Chạy `npm start`.
5. Máy chủ mặc định: `http://localhost:3000`.

## Chạy Flutter
1. Cài Flutter.
2. Mở thư mục `flutter_app`.
3. Chạy `flutter pub get`.
4. Android emulator dùng máy chủ trên máy tính: `flutter run --dart-define=API_URL=http://10.0.2.2:3000`.
5. Web cục bộ: `flutter run -d chrome --dart-define=API_URL=http://localhost:3000`.

## Đưa online
- Triển khai thư mục `server` lên Render hoặc VPS.
- Sửa biến `API_URL` trong Codemagic thành địa chỉ máy chủ thật.
- Đẩy toàn bộ dự án lên GitHub và kết nối Codemagic.

## Lưu ý dữ liệu
Bản V1.0 dùng tệp JSON ở `server/data/db.json`, phù hợp triển khai nhỏ và dễ sao lưu. Khi dùng đông người lâu dài nên nâng cấp PostgreSQL.
