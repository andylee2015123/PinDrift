import 'package:fake_gps_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows map and settings tabs', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FakeGpsApp());
    await tester.pumpAndSettle();

    expect(find.text('PinDrift'), findsOneWidget);
    expect(find.text('모의 위치 앱 설정 필요'), findsOneWidget);

    await tester.tap(find.text('설정'));
    await tester.pumpAndSettle();

    expect(find.text('네이버 지도 설정'), findsOneWidget);
    expect(find.text('Naver Maps ncpKeyId'), findsOneWidget);

    await tester.tap(find.text('도움말'));
    await tester.pumpAndSettle();

    expect(find.text('네이버 지도 ncpKeyId 받기'), findsOneWidget);
  });
}
