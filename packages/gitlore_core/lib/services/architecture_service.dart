import '../models/architecture.dart';

/// Shared boundary for live GitHub analysis and offline demo fixtures.
abstract class ArchitectureService {
  Future<Architecture> analyze(String url);
}

class DemoArchitectureService implements ArchitectureService {
  static String repositoryFromUrl(String input) {
    final uri = Uri.tryParse(input.trim());
    final parts = uri?.pathSegments.where((part) => part.isNotEmpty).toList();
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        parts == null ||
        parts.length != 2 ||
        !parts.every((part) => RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(part)) ||
        parts.any((part) => part == '.' || part == '..') ||
        parts[1].replaceFirst(RegExp(r'\.git$'), '').isEmpty) {
      throw const FormatException(
        'Enter a repository URL like https://github.com/owner/repo',
      );
    }
    return '${parts[0]}/${parts[1].replaceFirst(RegExp(r'\.git$'), '')}';
  }

  @override
  Future<Architecture> analyze(String url) async {
    final repository = repositoryFromUrl(url);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    return Architecture(
      repository: repository,
      summary: 'An example request journey through a web application. This fixture demonstrates the GitLore experience; it does not describe the submitted repository.',
      nodes: const [
        ArchitectureNode(
          'client',
          'Web client',
          'PRESENTATION',
          'A visitor submits a request from the browser. The client presents the response as a readable interface.',
          ['example/client.tsx'],
        ),
        ArchitectureNode(
          'router',
          'API router',
          'ENTRY POINT',
          'The router receives the HTTP request, validates its input, and selects the appropriate handler.',
          ['example/routes.ts'],
        ),
        ArchitectureNode(
          'service',
          'Application service',
          'BUSINESS LOGIC',
          'The service coordinates the work and applies the rules of the application.',
          ['example/service.ts'],
        ),
        ArchitectureNode(
          'database',
          'Database',
          'PERSISTENCE',
          'The data layer reads or writes a record and returns the result to the service.',
          ['example/database.ts'],
        ),
      ],
      steps: const [
        StoryStep(
          'Every story starts with a request.',
          'A visitor clicks a button. The web client sends an HTTP request to the application API.',
          'client',
        ),
        StoryStep(
          'The router opens the right door.',
          'The API checks the request and passes validated input to the application service.',
          'router',
        ),
        StoryStep(
          'The application connects the dots.',
          'The service applies business rules and asks the data layer for the information it needs.',
          'service',
        ),
        StoryStep(
          'The data makes its way home.',
          'The database returns a result. It travels back through the service and API to the visitor’s screen.',
          'database',
        ),
      ],
    );
  }
}
