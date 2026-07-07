import 'package:flutter_test/flutter_test.dart';
import 'package:tap_drop_arena/main.dart';

void main() {
  testWidgets('opens the auth screen when signed out', (tester) async {
    await tester.pumpWidget(const TapDropArenaApp(firebaseReady: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Hoop Keys'), findsOneWidget);
    expect(find.text('Giris Yap'), findsOneWidget);
    expect(find.text('Sifremi unuttum'), findsOneWidget);
  });
}
