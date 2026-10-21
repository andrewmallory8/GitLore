import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitlore/main.dart';
import 'package:gitlore/models/architecture.dart';
import 'package:gitlore/services/architecture_service.dart';

class _RecordingDemo extends DemoArchitectureService {
  final calls = <String>[];

  @override
  Future<Architecture> analyze(String url) {
    calls.add(url);
    return super.analyze(url);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('reuses results and refreshes the displayed repository', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _RecordingDemo();
    await tester.pumpWidget(GitLoreApp(service: service));
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Analyze repository'));
      await tester.tap(find.text('Analyze repository'));
      await tester.pumpAndSettle();
    }
    expect(service.calls, ['https://github.com/expressjs/express']);

    // Editing the input must not change which result the refresh button owns.
    await tester.enterText(
      find.byType(TextField),
      'https://github.com/team/other',
    );
    await tester.ensureVisible(find.text('Refresh analysis'));
    await tester.tap(find.text('Refresh analysis'));
    await tester.pumpAndSettle();
    expect(service.calls.last, 'https://github.com/expressjs/express');
    expect(service.calls, hasLength(2));
    await tester.tap(find.text('Save project'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://github.com/team/other',
    );
    await tester.ensureVisible(find.text('Analyze repository'));
    await tester.tap(find.text('Analyze repository'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Saved projects (1)'));
    await tester.tap(find.text('Saved projects (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('expressjs/express'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'https://github.com/expressjs/express',
    );
    await tester.ensureVisible(find.text('Refresh analysis'));
    await tester.tap(find.text('Refresh analysis'));
    await tester.pumpAndSettle();
    expect(service.calls.last, 'https://github.com/expressjs/express');
    expect(service.calls, hasLength(4));
    expect(tester.takeException(), isNull);
  });

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
    await tester.pumpWidget(GitLoreApp(service: DemoArchitectureService()));
    await tester.tap(find.text('Analyze repository'));
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
    await tester.pumpWidget(GitLoreApp(service: DemoArchitectureService()));
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'not a URL');
    await tester.ensureVisible(find.text('Analyze repository'));
    await tester.tap(find.text('Analyze repository'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a repository URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byType(TextField),
      'https://github.com/owner/repo',
    );
    await tester.tap(find.text('Analyze repository'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next chapter →'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
