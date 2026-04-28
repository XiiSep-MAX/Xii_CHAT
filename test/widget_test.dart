// This is a basic Flutter widget test for AI Chat App.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_chat_app/main.dart';

void main() {
  testWidgets('AI Chat App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AIChatApp());

    // Verify that our app shows the chat screen
    expect(find.text('Xii_Raw Graph'), findsOneWidget);
    expect(find.byType(ChatScreen), findsOneWidget);

    // Verify that the input field is present
    expect(find.byType(TextField), findsOneWidget);

    // Verify that the image picker button is present
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);

    // Verify that the send button is present
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}
