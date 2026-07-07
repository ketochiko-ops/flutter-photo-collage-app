import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_photo_collage_app/main.dart';

void main() {
  testWidgets('home screen shows editor navigation', (tester) async {
    await tester.pumpWidget(const CollageApp());

    expect(find.text('Photo Collage Studio'), findsOneWidget);
    expect(find.text('Frame'), findsOneWidget);
    expect(find.text('Collage'), findsOneWidget);
    expect(find.text('Project'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Select Images'), findsOneWidget);
  });
}
