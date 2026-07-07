import 'dart:math' as math;
import 'dart:ui';

class CollageLayout {
  const CollageLayout();

  List<Rect> build({
    required int itemCount,
    required int columns,
    required Size canvasSize,
    required double gutter,
  }) {
    if (itemCount <= 0) {
      return const [];
    }

    final safeColumns = math.max(1, math.min(columns, itemCount));
    final rows = (itemCount / safeColumns).ceil();
    final totalGutterX = gutter * (safeColumns + 1);
    final totalGutterY = gutter * (rows + 1);
    final cellWidth = (canvasSize.width - totalGutterX) / safeColumns;
    final cellHeight = (canvasSize.height - totalGutterY) / rows;

    return List.generate(itemCount, (index) {
      final row = index ~/ safeColumns;
      final column = index % safeColumns;
      final left = gutter + column * (cellWidth + gutter);
      final top = gutter + row * (cellHeight + gutter);
      return Rect.fromLTWH(left, top, cellWidth, cellHeight);
    });
  }
}
