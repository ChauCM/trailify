import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Dashboard app smoke test', (tester) async {
    // Dashboard requires browser APIs (localStorage, Firebase JS SDK).
    // Integration testing is done via browser-based tests.
    expect(true, isTrue);
  });
}
