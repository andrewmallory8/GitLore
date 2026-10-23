import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';

import 'services/bookshelf_service.dart';
import 'services/preferences_shelf_storage.dart';
import 'services/server_architecture_service.dart';
import 'widgets/storybook_presentation.dart';
import 'widgets/explore_panel.dart';
import 'widgets/export_dialog.dart';
import 'widgets/bookshelf_panel.dart';

import 'package:url_launcher/url_launcher.dart';

import 'services/github_architecture_service.dart';

import 'models/architecture.dart';
import 'services/architecture_service.dart';
import 'services/cached_architecture_service.dart';
import 'widgets/architecture_canvas.dart';

void main() => runApp(const GitLoreApp());

class GitLoreApp extends StatefulWidget {
  const GitLoreApp({super.key, this.service, this.bookshelf});
  final BookshelfService? bookshelf;
  final ArchitectureService? service;
  @override
  State<GitLoreApp> createState() => _GitLoreAppState();
}

class _GitLoreAppState extends State<GitLoreApp> {
  ThemeMode mode = ThemeMode.system;
  late final defaultService = GitHubArchitectureService();
  late final defaultShelf = BookshelfService(PreferencesShelfStorage());
  bool changed = false;
  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final dark = preferences.getBool('gitlore.darkMode');
      if (mounted && !changed && dark != null) {
        setState(() => mode = dark ? ThemeMode.dark : ThemeMode.light);
      }
    } catch (_) {
      /* Theme preference failure does not block analysis. */
    }
  }

  Future<void> _toggleTheme(bool dark) async {
    changed = true;
    setState(() => mode = dark ? ThemeMode.dark : ThemeMode.light);
    try {
      await (await SharedPreferences.getInstance()).setBool(
        'gitlore.darkMode',
        dark,
      );
    } catch (_) {
      /* Session theme still works. */
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GitLore · Repository intelligence',
    debugShowCheckedModeBanner: false,
    theme: gitLoreTheme(Brightness.light),
    darkTheme: gitLoreTheme(Brightness.dark),
    themeMode: mode,
    home: GitLoreHome(
      service: widget.service ?? defaultService,
      bookshelf: widget.bookshelf ?? defaultShelf,
      allowServer: widget.service == null,
      onToggleTheme: _toggleTheme,
    ),
  );
}

class GitLoreHome extends StatefulWidget {
  const GitLoreHome({
    super.key,
    required this.service,
    required this.bookshelf,
    this.allowServer = false,
    this.onToggleTheme,
  });
  final BookshelfService bookshelf;
  final bool allowServer;
  final ValueChanged<bool>? onToggleTheme;
  final ArchitectureService service;
  @override
  State<GitLoreHome> createState() => _GitLoreHomeState();
}

class _GitLoreHomeState extends State<GitLoreHome> {
  ColorScheme get palette => Theme.of(context).colorScheme;
  Color get green => palette.primary;
  Color get muted => palette.onSurfaceVariant;
  Color get paper => palette.surfaceContainerLow;
  bool _graphActive = false;
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
    defaultValue: 'https://gitlore-api.jack-j-dugan.workers.dev',
  );
  String _accessToken = '';

  String? _error;
  bool _loading = false;
  String _progress = '';
  String? _failedUrl;
  DateTime? _retryAt;

  void _reportProgress(String stage) {
    if (mounted && _loading) setState(() => _progress = stage);
  }

  ArchitectureService get _staticService => widget.allowServer
      ? GitHubArchitectureService(onProgress: _reportProgress)
      : widget.service;
  int _step = 0;
  int _page = 0;
  String _selected = 'client';

  @override
  void initState() {
    super.initState();
    _analyzer = CachedArchitectureService(_staticService);
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
      _analyzer = CachedArchitectureService(_staticService);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _analyze({bool refresh = false, String? retryUrl}) async {
    if (_loading) return;
    final url =
        retryUrl ??
        (refresh && _architecture != null
            ? 'https://github.com/${_architecture!.repository}'
            : _url.text);
    setState(() {
      _loading = true;
      _error = null;
      _progress = 'Checking input and cached results';
      _failedUrl = url;
      _retryAt = null;
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
      if (mounted) {
        setState(() {
          _error = error.message;
          _retryAt = error.retryAt;
        });
      }
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
            ? ServerArchitectureService(
                _serverUrl,
                accessToken: _accessToken,
                onProgress: _reportProgress,
              )
            : _staticService,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: palette.surface,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _pageGutter),
              child: _header(),
            ),
          ),
          Divider(height: 1, color: palette.outlineVariant),
          Expanded(child: _workspaceBody()),
        ],
      ),
    ),
  );

  double get _pageGutter =>
      (MediaQuery.sizeOf(context).width * .035).clamp(16.0, 72.0);

  Widget _workspaceBody() => SafeArea(
    child: NotificationListener<GraphInteractionNotification>(
      onNotification: (event) {
        setState(() => _graphActive = event.active);
        return true;
      },
      child: SingleChildScrollView(
        physics: _graphActive ? const NeverScrollableScrollPhysics() : null,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: double.infinity),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _pageGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_page == 2)
                    ExplorePanel(
                      busy: _loading,
                      onAnalyze: (url) {
                        setState(() {
                          _page = 0;
                          _url.text = url;
                        });
                        _analyze(refresh: true, retryUrl: url);
                      },
                    )
                  else if (_page == 1)
                    _savedPage()
                  else ...[
                    const SizedBox(height: 32),
                    if (_architecture == null) ...[
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            size: 17,
                            color: green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'YOUR CODEBASE, EXPLAINED',
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
                      Text(
                        'Understand code.\nSee the bigger picture.',
                        style: TextStyle(
                          fontSize: MediaQuery.sizeOf(context).width < 600
                              ? 32
                              : 44,
                          height: 1.08,
                          letterSpacing: -2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Turn a GitHub repository into a visual map and a story you can follow.\nLess digging through files. More understanding how it all fits together.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 16,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 28),
                    ] else ...[
                      Text(
                        'Repository workspace',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Selected public source excerpts are sent through your server to Gemini. AI can make mistakes. Generating an explanation may take a little longer.',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ),
                    _input(),
                    if (_loading)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const LinearProgressIndicator(),
                              const SizedBox(height: 8),
                              Text(_progress),
                            ],
                          ),
                        ),
                      ),
                    if (_error != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                              if (_architecture != null)
                                const Text(
                                  'Your previous result is still shown below; it has not been refreshed.',
                                ),
                              if (_retryAt != null)
                                Text(
                                  'Suggested retry time: ${_retryAt!.toLocal()}',
                                ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: _loading
                                        ? null
                                        : () => _analyze(
                                            refresh: true,
                                            retryUrl: _failedUrl,
                                          ),
                                    child: const Text('Retry analysis'),
                                  ),
                                  if (_useAi)
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () {
                                              _setAi(false);
                                              _analyze(
                                                refresh: true,
                                                retryUrl: _failedUrl,
                                              );
                                            },
                                      child: const Text('Use static analysis'),
                                    ),
                                  if (_useAi)
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : _configureServer,
                                      child: const Text(
                                        'Check server settings',
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'PUBLIC GITHUB REPOSITORIES  •  Source-backed map · Optional AI chapters',
                      style: TextStyle(
                        fontSize: 11,
                        color: muted,
                        letterSpacing: .5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Results are reused for up to 10 minutes in this session. Use Refresh analysis to check for changes.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                    const SizedBox(height: 42),
                    if (_architecture == null) _empty() else _result(),
                  ],
                  const SizedBox(height: 36),
                  Divider(color: palette.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
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
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 28,
      runSpacing: 16,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(Icons.account_tree_rounded, color: green, size: 28),
            const SizedBox(width: 10),
            const Text(
              'GitLore',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 25,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 10),
            Chip(
              label: Text(
                'REPOSITORY INTELLIGENCE',
                style: TextStyle(fontSize: 9, color: green),
              ),
              side: BorderSide.none,
              backgroundColor: palette.primaryContainer,
            ),
          ],
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: Theme.of(context).brightness == Brightness.dark
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              icon: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              onPressed: () => widget.onToggleTheme?.call(
                Theme.of(context).brightness != Brightness.dark,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _page = 0),
              child: Text(
                'Workspace',
                style: TextStyle(color: _page == 0 ? green : muted),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => setState(() => _page = 2),
              child: Text(
                'Explore',
                style: TextStyle(color: _page == 2 ? green : muted),
              ),
            ),
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
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: palette.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: palette.outlineVariant),
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
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.link, color: muted),
            hintText: 'https://github.com/owner/repository',
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
              : Icon(
                  _useAi ? Icons.auto_awesome : Icons.manage_search,
                  size: 17,
                ),
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
      color: palette.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      children: [
        Icon(Icons.hub_outlined, size: 50, color: green),
        const SizedBox(height: 18),
        const Text(
          'From a codebase to the bigger picture.',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          'Analyze a public repository to explore its real files, dependencies, and code tour.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, height: 1.6),
        ),
        const SizedBox(height: 22),
        const Wrap(
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
    final connections = architecture.edges
        .where((edge) => edge.from == node.id || edge.to == node.id)
        .toList();
    final aiFailed = _useAi && architecture.analysisKind != 'ai';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.auto_stories_outlined),
            label: const Text('Present storybook'),
            onPressed: _loading
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StorybookPresentation(
                        architecture: architecture,
                        onOpenSource: _openSource,
                      ),
                    ),
                  ),
          ),
        ),

        if (aiFailed)
          Card(
            color: palette.errorContainer,
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
        OutlinedButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => ExportDialog(architecture: architecture),
          ),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export analysis'),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 10,
          children: [
            Icon(Icons.folder_open, color: green),
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
        Text(architecture.summary, style: TextStyle(color: muted, height: 1.6)),
        if (architecture.isLive) ...[
          const SizedBox(height: 12),
          Text(
            'COMMIT ${architecture.commitSha!.substring(0, 7)}  ·  ${architecture.branch}  ·  ${architecture.files.length}/${architecture.fileCount} files read',
            style: TextStyle(fontSize: 12, color: green),
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
                        style: TextStyle(
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
                  Text(
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
                    style: TextStyle(
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
                    style: TextStyle(height: 1.6, color: muted),
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
                          style: TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (architecture.isLive && connections.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Observed relative imports',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    ...connections.map(
                      (edge) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${edge.from} → ${edge.to}',
                          style: TextStyle(fontSize: 12, color: green),
                        ),
                      ),
                    ),
                  ],
                  if (architecture.isLive && connections.isEmpty)
                    Text(
                      'No incoming or outgoing imports resolved for this component. Other connections may exist.',
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
                                : palette.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'CHAPTER ${_step + 1} OF ${architecture.steps.length}',
                    style: TextStyle(
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
                      color: palette.surfaceContainerLow,
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
                    style: TextStyle(color: muted, fontSize: 15, height: 1.7),
                  ),
                  if (architecture.analysisKind == 'ai') ...[
                    const SizedBox(height: 12),
                    Text(
                      'AI interpretation · ${architecture.model}',
                      style: TextStyle(fontSize: 12, color: muted),
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
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: palette.outlineVariant),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(number, style: TextStyle(color: muted, fontSize: 11)),
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
