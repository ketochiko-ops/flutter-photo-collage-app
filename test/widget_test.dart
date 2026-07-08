import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_photo_collage_app/main.dart';
import 'package:flutter_photo_collage_app/models/export_settings.dart';

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

  testWidgets('export controls use megabytes for target size', (tester) async {
    ExportSettings? changed;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExportControls(
            settings: const ExportSettings(
              longSide: 3000,
              targetBytes: 1572864,
            ),
            onChanged: (settings) => changed = settings,
          ),
        ),
      ),
    );

    expect(find.text('Target MB'), findsOneWidget);
    expect(find.text('Long Side'), findsOneWidget);
    expect(find.text('3000'), findsOneWidget);
    expect(find.text('1.5'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Target MB'), '2.25');

    expect(changed?.targetBytes, (2.25 * 1024 * 1024).round());

    await tester.enterText(find.widgetWithText(TextField, 'Long Side'), '');

    expect(changed?.longSide, isNull);
  });

  testWidgets('slider field accepts direct numeric input', (tester) async {
    var value = 12.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SliderField(
                label: 'Value',
                value: value,
                min: 0,
                max: 100,
                onChanged: (next) => setState(() => value = next),
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.widgetWithText(TextField, '12'), '42.5');
    await tester.pump();

    expect(value, 42.5);
  });
}
