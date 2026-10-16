import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitlore/main.dart';
import 'package:gitlore/services/architecture_service.dart';

void main() {
  test('repository URLs are validated before analysis', () {
    expect(
      DemoArchitectureService.repositoryFromUrl(
        'https://github.com/owner/repo.git',
      ),
      'owner/repo',
    );
    for (final url in [
      'https://example.com/owner/repo',
      'file:///owner/repo',
      'https://github.com/owner',
      'https://github.com/owner/repo/tree/main',
    ]) {
      expect(
        () => DemoArchitectureService.repositoryFromUrl(url),
        throwsFormatException,
      );
    }
  });

  testWidgets('demo, node selection, chapters, and saved projects work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GitLoreApp());
    await tester.tap(find.text('Try demo'));
    await tester.pumpAndSettle();
    expect(find.text('expressjs/express'), findsOneWidget);
    await tester.ensureVisible(find.text('Next chapter →'));
    await tester.tap(find.text('Next chapter →'));
    await tester.pumpAndSettle();
    expect(find.text('CHAPTER 2 OF 4'), findsOneWidget);
    expect(find.text('ENTRY POINT'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Application service'),
    );
    await tester.pumpAndSettle();
    expect(find.text('BUSINESS LOGIC'), findsOneWidget);
    await tester.ensureVisible(find.text('Save project'));
    await tester.tap(find.text('Save project'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Saved projects (1)'));
    await tester.tap(find.text('Saved projects (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Your bookshelf'), findsOneWidget);
    expect(find.text('expressjs/express'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile layout and invalid input show no framework errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const GitLoreApp());
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'not a URL');
    await tester.ensureVisible(find.text('Try demo'));
    await tester.tap(find.text('Try demo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a repository URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byType(TextField),
      'https://github.com/owner/repo',
    );
    await tester.tap(find.text('Try demo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next chapter →'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
