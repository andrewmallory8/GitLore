import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gitlore/services/github_architecture_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gitlore/main.dart';
import 'package:gitlore/models/architecture.dart';
import 'package:gitlore/services/architecture_service.dart';

class _ControlledService implements ArchitectureService {
  Completer<Architecture> pending = Completer<Architecture>();
  @override
  Future<Architecture> analyze(String url) => pending.future;
}

class _RecordingDemo extends DemoArchitectureService {
  final calls = <String>[];

  @override
  Future<Architecture> analyze(String url) {
    calls.add(url);
    return super.analyze(url);
  }
}

class _AiOverviewService implements ArchitectureService {
  @override
  Future<Architecture> analyze(String url) async => const Architecture(
    repository: 'team/repo',
    summary: 'This AI overview explains the sampled entry point.',
    nodes: [
      ArchitectureNode('main.js', 'Entry point', 'SOURCE', 'Source', [
        'main.js',
      ]),
    ],
    steps: [
      StoryStep(
        'Overview',
        'This AI overview explains the sampled entry point.',
        'main.js',
        evidence: [SourceEvidence('main.js', 1, 1)],
      ),
    ],
    files: [SourceFile('main.js', 'export const value = 1;')],
    commitSha: '1234567890abcdef1234567890abcdef12345678',
    branch: 'main',
    fileCount: 1,
    analysisKind: 'ai',
    model: 'fixture-model',
  );
}

void main() {
  testWidgets('theme toggles and static analyze has no sparkle', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'gitlore.darkMode': false});
    await tester.pumpWidget(GitLoreApp(service: DemoArchitectureService()));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Analyze repository');
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.auto_awesome)),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(find.byTooltip('Switch to light mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading is visible and failed refresh retains prior result', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = _ControlledService();
    final result = await tester.runAsync(
      () => DemoArchitectureService().analyze('https://github.com/team/repo'),
    );
    await tester.pumpWidget(GitLoreApp(service: service));
    await tester.tap(find.text('Analyze repository'));
    await tester.pump();
    expect(find.text('Checking input and cached results'), findsOneWidget);
    service.pending.complete(result!);
    await tester.pumpAndSettle();
    service.pending = Completer<Architecture>();
    await tester.ensureVisible(find.text('Refresh analysis'));
    await tester.tap(find.text('Refresh analysis'));
    await tester.pump();
    service.pending.completeError(
      const AnalysisException('Network unavailable'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Network unavailable'), findsOneWidget);
    expect(
      find.textContaining('Your previous result is still shown'),
      findsOneWidget,
    );
    expect(find.text('Retry analysis'), findsOneWidget);
    expect(find.text('team/repo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('displays the server AI overview as the repository summary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GitLoreApp(service: _AiOverviewService()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Analyze repository'));
    await tester.tap(find.text('Analyze repository'));
    await tester.pumpAndSettle();
    expect(
      find.text('This AI overview explains the sampled entry point.'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('server settings use hosted HTTPS and allow a local override', (
    tester,
  ) async {
    await tester.pumpWidget(const GitLoreApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Server settings'));
    await tester.tap(find.text('Server settings'));
    await tester.pumpAndSettle();
    final address = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Server URL',
    );
    final code = find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.decoration?.labelText == 'Team access code (if required)',
    );
    expect(
      tester.widget<TextField>(address).controller!.text,
      'https://gitlore-api.jack-j-dugan.workers.dev',
    );
    expect(tester.widget<TextField>(code).obscureText, isTrue);
    await tester.enterText(address, 'http://untrusted.example');
    await tester.tap(find.text('Use server'));
    await tester.pumpAndSettle();
    expect(
      find.text('Use HTTPS, or HTTP for a local development server.'),
      findsOneWidget,
    );
    await tester.enterText(address, 'http://127.0.0.1:8087');
    await tester.tap(find.text('Use server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Server settings'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(address).controller!.text,
      'http://127.0.0.1:8087',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

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
