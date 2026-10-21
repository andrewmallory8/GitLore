import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'services/bookshelf_service.dart';
import 'services/preferences_shelf_storage.dart';
import 'services/server_architecture_service.dart';
import 'widgets/bookshelf_panel.dart';

import 'package:url_launcher/url_launcher.dart';

import 'services/github_architecture_service.dart';

import 'models/architecture.dart';
import 'services/architecture_service.dart';
import 'services/cached_architecture_service.dart';
import 'widgets/architecture_canvas.dart';

void main() => runApp(const GitLoreApp());

const ink = Color(0xFF202D28);
const green = Color(0xFF346B50);
const muted = Color(0xFF748078);
const paper = Color(0xFFF7F8F3);

class GitLoreApp extends StatelessWidget {
  const GitLoreApp({super.key, this.service, this.bookshelf});
  final BookshelfService? bookshelf;
  final ArchitectureService? service;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GitLore · Code tells a story',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        surface: Colors.white,
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    ),
    home: GitLoreHome(
      service: service ?? GitHubArchitectureService(),
      bookshelf: bookshelf ?? BookshelfService(PreferencesShelfStorage()),
      allowServer: service == null,
    ),
  );
}

class GitLoreHome extends StatefulWidget {
  const GitLoreHome({
    super.key,
    required this.service,
    required this.bookshelf,
    this.allowServer = false,
  });
  final BookshelfService bookshelf;
  final bool allowServer;
  final ArchitectureService service;
  @override
  State<GitLoreHome> createState() => _GitLoreHomeState();
}

class _GitLoreHomeState extends State<GitLoreHome> {
  late CachedArchitectureService _analyzer;
  final _url = TextEditingController(
    text: 'https://github.com/expressjs/express',
  );
  Architecture? _architecture;
  List<SavedProject> _saved = [];
  bool _shelfLoading = true;
  bool _saving = false;
  String? _shelfWarning;
  bool _useAi = false;
  String _serverUrl = const String.fromEnvironment(
    'GITLORE_API_URL',
    defaultValue: '',
  );
  String _accessToken = '';

  String? _error;
  bool _loading = false;
  int _step = 0;
  int _page = 0;
  String _selected = 'client';

  @override
  void initState() {
    super.initState();
    _analyzer = CachedArchitectureService(widget.service);
    if (_serverUrl.isEmpty) {
      _serverUrl = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8087'
          : 'http://127.0.0.1:8087';
    }
    _loadShelf();
  }

  @override
  void didUpdateWidget(covariant GitLoreHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      _analyzer = CachedArchitectureService(widget.service);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _analyze({bool refresh = false}) async {
    if (_loading) return;
    final url = refresh && _architecture != null
        ? 'https://github.com/${_architecture!.repository}'
        : _url.text;
    setState(() {
      _loading = true;
      _error = null;
      _architecture = null;
    });
    try {
      final result = await (refresh
          ? _analyzer.refresh(url)
          : _analyzer.analyze(url));
      if (!mounted) return;
      setState(() {
        _architecture = result;
        _url.text = 'https://github.com/${result.repository}';
        _step = 0;
        _selected = result.nodes.first.id;
        _page = 0;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on AnalysisException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadShelf() async {
    setState(() => _shelfLoading = true);
    final result = await widget.bookshelf.load();
    if (!mounted) return;
    setState(() {
      _saved = result.projects;
      _shelfWarning = result.warning;
      _shelfLoading = false;
    });
  }

  Future<void> _shelfAction(
    Future<List<SavedProject>> Function() action,
    String message,
  ) async {
    if (_saving || _shelfLoading) return;
    setState(() => _saving = true);
    try {
      final projects = await action();
      if (!mounted) return;
      setState(() {
        _saved = projects;
        _shelfWarning = null;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update saved projects. Storage may be full or unavailable. Retry or delete an older save.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final snapshot = _architecture!;
    await _shelfAction(
      () => widget.bookshelf.save(snapshot),
      'Saved on this device.',
    );
  }

  void _setAi(bool enabled) {
    setState(() {
      _useAi = enabled;
      _analyzer = CachedArchitectureService(
        enabled
            ? ServerArchitectureService(_serverUrl, accessToken: _accessToken)
            : widget.service,
      );
    });
  }

  Future<void> _configureServer() async {
    final address = TextEditingController(text: _serverUrl);
    final token = TextEditingController(text: _accessToken);
    String? error;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Analysis server'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Server URL'),
                ),
                TextField(
                  controller: token,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Team access code (if required)',
                  ),
                ),
                const Text(
                  'Enter a team access code, never your Gemini API key. Connection settings last for this session.',
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final uri = Uri.tryParse(address.text.trim());
                if (uri == null ||
                    uri.host.isEmpty ||
                    uri.userInfo.isNotEmpty ||
                    uri.hasQuery ||
                    uri.hasFragment ||
                    (uri.path.isNotEmpty && uri.path != '/') ||
                    (uri.scheme != 'https' &&
                        !(uri.scheme == 'http' &&
                            [
                              'localhost',
                              '127.0.0.1',
                              '10.0.2.2',
                            ].contains(uri.host)))) {
                  setDialog(
                    () => error =
                        'Use HTTPS, or HTTP for a local development server.',
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Use server'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      _serverUrl = address.text.trim();
      _accessToken = token.text.trim();
      _setAi(_useAi);
    }
    // Dialog transition may still be using its controllers; dispose next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      address.dispose();
      token.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const Divider(color: Color(0xFFE0E5DC), height: 1),
                  if (_page == 1)
                    _savedPage()
                  else ...[
                    const SizedBox(height: 54),
                    const Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 17,
                          color: green,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'A LITTLE CONTEXT. A WHOLE NEW PERSPECTIVE.',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.6,
                            color: green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Every repo has a story.\nLet’s unfold it.',
                      style: TextStyle(
                        fontSize: 48,
                        height: 1.08,
                        letterSpacing: -2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Turn a GitHub repository into a visual map and a story you can follow.\nLess digging through files. More understanding how it all fits together.',
                      style: TextStyle(color: muted, fontSize: 16, height: 1.7),
                    ),
                    const SizedBox(height: 28),
                    if (widget.allowServer)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: _useAi,
                                onChanged: _loading ? null : _setAi,
                              ),
                              const Text('AI explanation'),
                            ],
                          ),
                          TextButton(
                            onPressed: _loading ? null : _configureServer,
                            child: const Text('Server settings'),
                          ),
                        ],
                      ),
                    if (widget.allowServer && _useAi)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Selected public source excerpts are sent through your server to Gemini. AI can make mistakes. The first request may take longer while a free server wakes.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    _input(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      'PUBLIC GITHUB REPOSITORIES  •  Source-backed map · Optional AI chapters',
                      style: TextStyle(
                        fontSize: 11,
                        color: muted,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Results are reused for up to 10 minutes in this session. Use Refresh analysis to check for changes.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 42),
                    if (_architecture == null) _empty() else _result(),
                  ],
                  const SizedBox(height: 36),
                  const Divider(color: Color(0xFFE0E5DC)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'GitLore  /  A new way to read code.                                      Built for curious developers.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 28,
      runSpacing: 16,
      children: [
        const Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.account_tree_rounded, color: green, size: 28),
            SizedBox(width: 10),
            Text(
              'GitLore',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 25,
                letterSpacing: -1,
              ),
            ),
            SizedBox(width: 10),
            Chip(
              label: Text(
                'EARLY CHAPTER',
                style: TextStyle(fontSize: 9, color: green),
              ),
              side: BorderSide.none,
              backgroundColor: Color(0xFFE8EEDF),
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => setState(() => _page = 0),
              child: Text(
                'Workspace',
                style: TextStyle(color: _page == 0 ? green : muted),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => setState(() => _page = 1),
              child: Text(
                'Saved projects (${_saved.length})',
                style: TextStyle(color: _page == 1 ? green : muted),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _input() => Container(
    constraints: const BoxConstraints(maxWidth: 850),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFD9DFD4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 16,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final field = TextField(
          controller: _url,
          enabled: !_loading,
          onSubmitted: (_) {
            if (!_loading) _analyze();
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.link, color: muted),
            hintText: 'https://github.com/owner/repository',
            contentPadding: EdgeInsets.symmetric(vertical: 16),
          ),
        );
        final button = FilledButton.icon(
          onPressed: _loading ? null : _analyze,
          style: FilledButton.styleFrom(
            backgroundColor: green,
            padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 21),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome, size: 17),
          label: Text(_loading ? 'Unfolding…' : 'Analyze repository'),
        );
        return constraints.maxWidth < 580
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [field, button],
              )
            : Row(
                children: [
                  Expanded(child: field),
                  button,
                ],
              );
      },
    ),
  );

  Widget _empty() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF1E8),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Column(
      children: [
        Icon(Icons.hub_outlined, size: 50, color: green),
        SizedBox(height: 18),
        Text(
          'From a codebase to the bigger picture.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 10),
        Text(
          'Analyze a public repository to explore its real files, dependencies, and code tour.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.6),
        ),
        SizedBox(height: 22),
        Wrap(
          spacing: 30,
          runSpacing: 12,
          children: [
            Text('01  Explore the architecture'),
            Text('02  Follow the code tour'),
            Text('03  Connect it to code'),
          ],
        ),
      ],
    ),
  );

  Widget _result() {
    final architecture = _architecture!;
    final node = architecture.nodes.firstWhere((node) => node.id == _selected);
    final aiFailed = _useAi && architecture.analysisKind != 'ai';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (aiFailed)
          Card(
            color: const Color(0xFFFFF0D5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI explanation unavailable',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Showing the static code map and chapters instead.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    architecture.warnings.isEmpty
                        ? 'No AI explanation was returned. Check Server settings and try again.'
                        : architecture.warnings.last,
                  ),
                  TextButton.icon(
                    onPressed: _loading ? null : () => _analyze(refresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry AI analysis'),
                  ),
                ],
              ),
            ),
          ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 10,
          children: [
            const Icon(Icons.folder_open, color: green),
            Text(
              architecture.repository,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            Chip(
              label: Text(
                architecture.analysisKind == 'ai'
                    ? 'AI CHAPTERS · STATIC MAP'
                    : architecture.isLive
                    ? 'SOURCE-BACKED'
                    : 'DEMO FIXTURE',
                style: const TextStyle(fontSize: 10),
              ),
              side: BorderSide.none,
            ),
            OutlinedButton.icon(
              onPressed: _saving || _shelfLoading ? null : _save,
              icon: const Icon(Icons.bookmark_border, size: 17),
              label: Text(
                _saved.any(
                      (item) =>
                          item.architecture.repository ==
                          architecture.repository,
                    )
                    ? 'Saved'
                    : 'Save project',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _analyze(refresh: true),
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Refresh analysis'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          architecture.summary,
          style: const TextStyle(color: muted, height: 1.6),
        ),
        if (architecture.isLive) ...[
          const SizedBox(height: 12),
          Text(
            'COMMIT ${architecture.commitSha!.substring(0, 7)}  ·  ${architecture.branch}  ·  ${architecture.files.length}/${architecture.fileCount} files read',
            style: const TextStyle(fontSize: 12, color: green),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: architecture.technologies
                .map((tech) => Chip(label: Text(tech)))
                .toList(),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Analysis scope & limitations',
              style: TextStyle(fontSize: 13),
            ),
            children: architecture.warnings
                .map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        warning,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final map = _panel(
              '01',
              'The big picture',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a component. Reading order does not imply data flow.',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  ArchitectureCanvas(
                    nodes: architecture.nodes,
                    selected: _selected,
                    edges: architecture.edges,
                    onSelect: (id) => setState(() => _selected = id),
                  ),
                  const Divider(height: 32),
                  Text(
                    node.kind,
                    style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.bold,
                      color: green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    node.label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    node.description,
                    style: const TextStyle(height: 1.6, color: muted),
                  ),
                  const SizedBox(height: 14),
                  ...node.files.map(
                    (path) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (architecture.isLive)
                          TextButton.icon(
                            onPressed: () =>
                                _openSource(architecture.sourceUrl(path)),
                            icon: const Icon(Icons.open_in_new, size: 14),
                            label: Text(
                              path,
                              style: const TextStyle(fontSize: 12),
                            ),
                          )
                        else
                          SelectableText(path),
                        ...architecture.files
                            .where((file) => file.path == path)
                            .map(
                              (file) => Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: paper,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SelectableText(
                                    file.content
                                        .split('\n')
                                        .take(24)
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map(
                                          (entry) =>
                                              '${entry.key + 1}  ${entry.value}',
                                        )
                                        .join('\n'),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      height: 1.6,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        const SizedBox(height: 8),
                        Text(
                          architecture.isLive
                              ? 'Source excerpt · first 24 lines · pinned to analyzed commit'
                              : 'Illustrative file paths · demo only',
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (architecture.isLive && architecture.edges.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Observed relative imports',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ...architecture.edges.map(
                      (edge) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${edge.from} → ${edge.to}',
                          style: const TextStyle(fontSize: 12, color: green),
                        ),
                      ),
                    ),
                  ],
                  if (architecture.isLive && architecture.edges.isEmpty)
                    const Text(
                      'No relative imports resolved between the sampled files. Other connections may exist.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                ],
              ),
            );
            final story = _panel(
              '02',
              'Follow the story',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(
                      architecture.steps.length,
                      (index) => Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: index <= _step
                                ? green
                                : const Color(0xFFE8ECE3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'CHAPTER ${_step + 1} OF ${architecture.steps.length}',
                    style: const TextStyle(
                      color: green,
                      letterSpacing: 1.6,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2E8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        [
                          Icons.touch_app_outlined,
                          Icons.signpost_outlined,
                          Icons.settings_suggest_outlined,
                          Icons.storage_rounded,
                        ][_step % 4],
                        size: 52,
                        color: green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    architecture.steps[_step].title,
                    style: const TextStyle(
                      fontSize: 26,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    architecture.steps[_step].body,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 15,
                      height: 1.7,
                    ),
                  ),
                  if (architecture.analysisKind == 'ai') ...[
                    const SizedBox(height: 12),
                    Text(
                      'AI interpretation · ${architecture.model}',
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                    for (final evidence in architecture.steps[_step].evidence)
                      TextButton(
                        onPressed: () => _openSource(
                          architecture
                              .sourceUrl(evidence.path)
                              .replace(
                                fragment:
                                    'L${evidence.startLine}-L${evidence.endLine}',
                              ),
                        ),
                        child: Text(
                          '${evidence.path}:${evidence.startLine}–${evidence.endLine}',
                        ),
                      ),
                  ],
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: _step == 0
                            ? null
                            : () => _changeStep(_step - 1),
                        child: const Text('← Previous'),
                      ),
                      FilledButton(
                        onPressed: () => _changeStep(
                          (_step + 1) % architecture.steps.length,
                        ),
                        style: FilledButton.styleFrom(backgroundColor: green),
                        child: Text(
                          _step == architecture.steps.length - 1
                              ? 'Read again ↺'
                              : 'Next chapter →',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            if (constraints.maxWidth < 850) {
              return Column(children: [map, const SizedBox(height: 20), story]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: map),
                const SizedBox(width: 22),
                Expanded(flex: 2, child: story),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openSource(Uri url) async {
    try {
      if (await launchUrl(url)) return;
    } catch (_) {
      /* Surface unavailable launchers without crashing. */
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText(
            'Could not open browser. Copy this link: $url',
          ),
        ),
      );
    }
  }

  void _changeStep(int step) => setState(() {
    _step = step;
    _selected = _architecture!.steps[step].nodeId;
  });

  Widget _panel(String number, String title, Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE0E5DC)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(number, style: const TextStyle(color: muted, fontSize: 11)),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 22),
        child,
      ],
    ),
  );

  Widget _savedPage() => BookshelfPanel(
    projects: _saved,
    loading: _shelfLoading,
    busy: _saving,
    warning: _shelfWarning,
    onRetry: _loadShelf,
    onDelete: (project) => _shelfAction(
      () => widget.bookshelf.delete(project.architecture.repository),
      'Saved project deleted.',
    ),
    onClear: () => _shelfAction(widget.bookshelf.clear, 'Local saves cleared.'),
    onOpen: (project) => setState(() {
      final item = project.architecture;
      _architecture = item;
      _url.text = 'https://github.com/${item.repository}';
      _step = 0;
      _selected = item.nodes.first.id;
      _page = 0;
    }),
  );
}
