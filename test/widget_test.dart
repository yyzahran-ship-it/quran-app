import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/main.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: QuranApp()),
    );
    // Loading spinner appears while seeding (DB is empty in test environment)
    expect(find.byType(CircularProgressIndicator), findsAny);
  });
}
