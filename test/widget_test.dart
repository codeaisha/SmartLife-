import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/main.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    // Load the app with required parameters
    await tester.pumpWidget(
      MyApp(
        isDarkMode: false,
        isLoggedIn: false,
      ),
    );

    // Wait for animations to start
    await tester.pump(const Duration(milliseconds: 600));

    // Check that splash screen text appears
    expect(find.text('SmartLife+'), findsOneWidget);

    // Optional: wait for timer to navigate to login
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Check if login screen appeared (example, adjust text accordingly)
    expect(find.text('Login'), findsOneWidget);
  });
}
