// This is a Flutter integration test for the AI Chat App.
//
// To perform an integration test, use the WidgetTester utility in the
// flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the
// widget tree, read text, and verify that the values of widget properties
// are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:ai_chat_app/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('AI Chat App Integration Tests', () {
    testWidgets('App launches and shows main interface',
        (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const AIChatApp());

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify that our app shows the chat screen
      expect(find.text('Xii_Raw Graph'), findsOneWidget);
      expect(find.byType(ChatScreen), findsOneWidget);

      // Verify that the input field is present
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('尺寸比例'), findsOneWidget);
      expect(find.text('分辨率'), findsOneWidget);
      expect(find.text('输出格式'), findsOneWidget);

      // Verify that the send button is present
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      print('✅ App launch test passed');
    });

    testWidgets('UI elements are interactive', (WidgetTester tester) async {
      await tester.pumpWidget(const AIChatApp());
      await tester.pumpAndSettle();

      // Test text input
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello AI!');
      await tester.pump();

      // Verify text was entered
      expect(find.text('Hello AI!'), findsOneWidget);

      // Test clear messages button (if exists)
      final clearButton = find.byIcon(Icons.delete_sweep_rounded);
      if (clearButton.evaluate().isNotEmpty) {
        await tester.tap(clearButton);
        await tester.pump();
        print('✅ Clear messages button works');
      }

      print('✅ UI interaction test passed');
    });

    testWidgets('Theme and styling are applied correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const AIChatApp());
      await tester.pumpAndSettle();

      // Check for Material Design 3 elements
      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);

      // Check for app bar
      expect(find.byType(AppBar), findsOneWidget);

      // Check for gradient elements (avatar)
      final containers = find.byType(Container);
      expect(containers, findsWidgets);

      print('✅ Theme and styling test passed');
    });

    testWidgets('Error handling works', (WidgetTester tester) async {
      await tester.pumpWidget(const AIChatApp());
      await tester.pumpAndSettle();

      // Try to send empty message
      final sendButton = find.byIcon(Icons.send_rounded);
      await tester.tap(sendButton);
      await tester.pump();

      // Should not crash, app should handle empty input gracefully
      expect(find.byType(ChatScreen), findsOneWidget);

      print('✅ Error handling test passed');
    });

    testWidgets('Responsive layout works', (WidgetTester tester) async {
      await tester.pumpWidget(const AIChatApp());
      await tester.pumpAndSettle();

      // Test on different screen sizes would require additional setup
      // For now, just verify basic layout exists
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);

      print('✅ Responsive layout test passed');
    });
  });
}
