import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_app/core/widgets/assistant_avatar.dart';

void main() {
  test('avatar glyph uses the last character of the name', () {
    expect(assistantGlyph('阿智'), '智');
    expect(assistantGlyph('Buddy'), 'y');
    expect(assistantGlyph('  '), '智');
  });

  test('a drop in the top-left half snaps to that corner', () {
    const screen = Size(400, 800);
    final dropped = AssistantAvatarGeometry.nearest(
      topLeft: const Offset(20, 30),
      screen: screen,
    );
    final opposite = AssistantAvatarGeometry.nearest(
      topLeft: const Offset(300, 700),
      screen: screen,
    );
    expect(dropped, AssistantCorner.topLeft);
    expect(opposite, AssistantCorner.bottomRight);
    expect(
      AssistantAvatarGeometry.origin(
        corner: AssistantCorner.bottomRight,
        screen: screen,
        safe: EdgeInsets.zero,
      ),
      const Offset(304, 692),
    );
  });

  testWidgets('tap opens chat and a long drag changes the resting corner',
      (tester) async {
    var opens = 0;
    AssistantCorner? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              AssistantAvatar(
                name: '阿智',
                corner: AssistantCorner.bottomRight,
                safe: EdgeInsets.zero,
                onOpen: () => opens++,
                onCornerChanged: (corner) => saved = corner,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('阿智'), findsOneWidget);
    await tester.tap(find.text('阿智'));
    await tester.pump();
    expect(opens, 1);

    await tester.drag(find.text('阿智'), const Offset(-500, -500));
    await tester.pumpAndSettle();
    expect(saved, AssistantCorner.topLeft);
  });
}
