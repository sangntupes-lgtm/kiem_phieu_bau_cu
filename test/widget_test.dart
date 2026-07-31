import 'package:flutter_test/flutter_test.dart';
import 'package:kiem_dem_phieu_bau_mobile_pro/app.dart';

void main() {
  testWidgets('Ứng dụng khởi động', (tester) async {
    await tester.pumpWidget(const BallotApp());
    expect(find.textContaining('KIỂM ĐẾM PHIẾU BẦU'), findsOneWidget);
  });
}
