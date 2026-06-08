import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fliptap/main.dart';
import 'package:fliptap/repository/counter_repository.dart';

void main() {
  testWidgets('Counter App Smoke Test', (WidgetTester tester) async {
    // Set up mock SharedPreferences for test environment
    SharedPreferences.setMockInitialValues({});

    final repository = CounterRepository();
    await repository.init();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      CounterProvider(
        notifier: repository,
        child: const CounterApp(),
      ),
    );

    // Wait for the initialization futures to resolve and settle
    await tester.pumpAndSettle();

    // Verify that our counter starts at 0.
    expect(find.text('Primary Counter'), findsNWidgets(2));
    expect(find.text('0'), findsNWidgets(2));

    // Tap the count interaction zone
    await tester.tap(find.text('TAP CARD TO COUNT'));
    await tester.pumpAndSettle();

    // Verify that our counter has incremented.
    expect(find.text('1'), findsNWidgets(2));
  });
}
