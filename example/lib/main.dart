// A gallery of the iphone_duo_ui_pro widgets.
//
// Run it on an iPhone Duo (or drag the simulator edges) and watch the layout
// react: the navigation moves into the vertical bar, the panes split around the
// fold, the grid keeps an even number of columns, and dialogs step aside.

import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:flutter/material.dart';
import 'package:iphone_duo_ui_pro/iphone_duo_ui_pro.dart';

void main() => runApp(const DuoGalleryApp());

const Color _seed = Color(0xFF0F6079);

/// Launch options for screenshots and Device Hub checks, read from
/// `<app data container>/tmp/duo_launch.txt`, e.g. `tab=1;scroll_end=1;remote=1`.
/// Write it from the host with `xcrun simctl get_app_container <udid> <bundle id> data`.
final Map<String, String> launchOptions = () {
  try {
    final file = File('${Directory.systemTemp.path}/duo_launch.txt');
    if (!file.existsSync()) return const <String, String>{};
    return <String, String>{
      for (final part in file.readAsStringSync().trim().split(';'))
        if (part.contains('='))
          part.split('=')[0].trim(): part.split('=')[1].trim(),
    };
  } on Object {
    return const <String, String>{};
  }
}();

/// MediaQuery as seen above the scaffold (before SafeArea consumes it).
final ValueNotifier<MediaQueryData?> rootMedia = ValueNotifier<MediaQueryData?>(
  null,
);

class DuoGalleryApp extends StatelessWidget {
  const DuoGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iPhone Duo gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      // DuoScope feeds the native bridge into the tree; DuoDisplayFeatures
      // republishes the fold so every route below avoids it on its own.
      builder: (context, child) => DuoScope(
        child: DuoDisplayFeatures(
          child: Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              rootMedia.value = media;
              final duo = DuoScope.of(context);
              // Printed on every change so the state can be read from the
              // simulator log without touching the screen.
              debugPrint(
                'DUO-ENV size=${media.size.width.round()}x${media.size.height.round()} '
                'padding=${_insets(media.padding)} viewPadding=${_insets(media.viewPadding)} '
                'classes=${duo.horizontalSizeClass.name}x${duo.verticalSizeClass.name} '
                'sdk271=${duo.sdk271} edge=${duo.toolbarVerticalEdgeRaw}/${duo.uikitVerticalBarEdgeRaw} '
                'hinge=${duo.hinge?.status.name}:${duo.hinge?.angleDegrees?.round()} '
                'divisions=[${duo.divisions.map((r) => '${_rect(r.rect)}${r.active ? '!' : ''}').join('; ')}] '
                'occlusions=[${duo.occlusions.map((r) => _rect(r.rect)).join('; ')}] '
                'features=[${media.displayFeatures.map((f) => '${f.type.name}:${_rect(f.bounds)}:${f.state.name}').join('; ')}]',
              );
              return child ?? const SizedBox.shrink();
            },
          ),
        ),
      ),
      home: const GalleryHome(),
    );
  }
}

class GalleryHome extends StatefulWidget {
  const GalleryHome({super.key});

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  int _tab = (int.tryParse(launchOptions['tab'] ?? '') ?? 0).clamp(0, 2);
  int _selected = 0;
  int _unread = 3;

  static const List<String> _titles = <String>['Library', 'Grid', 'Bridge'];

  Timer? _remote;
  String _lastCommand = '';

  @override
  void initState() {
    super.initState();
    // A remote control for recordings and Device Hub checks: taps sent to a
    // simulator in the background never arrive, so with `remote=1` in the
    // launch options the host writes `<counter>:<command>` into
    // `<app data container>/tmp/duo_cmd.txt`. Commands: tab=1, select=4,
    // dialog, sheet, back.
    if (launchOptions['remote'] == '1') {
      _pollCommand(execute: false); // left over from an earlier run
      _remote = Timer.periodic(
        const Duration(milliseconds: 150),
        (_) => _pollCommand(),
      );
    }
  }

  @override
  void dispose() {
    _remote?.cancel();
    super.dispose();
  }

  void _pollCommand({bool execute = true}) {
    try {
      final file = File('${Directory.systemTemp.path}/duo_cmd.txt');
      if (!file.existsSync()) return;
      final raw = file.readAsStringSync().trim();
      if (raw == _lastCommand || !raw.contains(':')) return;
      _lastCommand = raw;
      if (execute && mounted) _run(raw.substring(raw.indexOf(':') + 1));
    } on Object {
      // A half-written file: the next poll reads it again.
    }
  }

  void _run(String command) {
    final value = command.contains('=') ? command.split('=')[1] : '';
    debugPrint('DUO-CMD $command');
    if (command.startsWith('tab=')) {
      setState(() => _tab = (int.tryParse(value) ?? 0).clamp(0, 2));
    } else if (command.startsWith('select=')) {
      setState(() => _selected = int.tryParse(value) ?? 0);
    } else if (command == 'dialog') {
      _openDialog();
    } else if (command == 'sheet') {
      _openSheet();
    } else if (command == 'back') {
      Navigator.of(context).maybePop();
    }
  }

  void _openSheet() {
    showDuoModalBottomSheet<void>(
      context: context,
      builder: (context) => const _ControlsSheet(),
    );
  }

  void _openDialog() {
    showDuoDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anchored beside the fold'),
        content: const Text(
          'The anchor point is constant, so this dialog moves to the correct '
          'half even if you fold the device while it is open.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DuoAdaptiveScaffold(
      title: _titles[_tab],
      prominentAction: DuoBarAction(
        icon: Icons.add,
        label: 'Add',
        onPressed: () => setState(() => _unread++),
      ),
      topActions: <DuoBarAction>[
        DuoBarAction(
          icon: Icons.edit_outlined,
          label: 'Compose',
          priority: DuoVisibilityPriority.high,
          onPressed: _openDialog,
        ),
        DuoBarAction(
          icon: Icons.inbox_outlined,
          label: 'Inbox',
          badgeCount: _unread,
          onPressed: () => setState(() => _unread = 0),
        ),
        DuoBarAction(
          icon: Icons.delete_outline,
          label: 'Delete',
          priority: DuoVisibilityPriority.low,
          onPressed: () {},
        ),
      ],
      bottomActions: <DuoBarAction>[
        DuoBarAction(
          icon: Icons.tune,
          label: 'Controls',
          onPressed: _openSheet,
        ),
      ],
      textActions: <DuoTextAction>[
        DuoTextAction(label: 'Select', onPressed: () {}),
      ],
      tabs: const <DuoTab>[
        DuoTab(icon: Icons.photo_library_outlined, label: 'Library'),
        DuoTab(icon: Icons.grid_view_outlined, label: 'Grid'),
        DuoTab(icon: Icons.memory_outlined, label: 'Bridge'),
      ],
      selectedTabIndex: _tab,
      onTabSelected: (index) => setState(() => _tab = index),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _unread++),
        child: const Icon(Icons.add),
      ),
      body: switch (_tab) {
        0 => _LibraryPane(
          selected: _selected,
          onSelected: (index) => setState(() => _selected = index),
        ),
        1 => const _GridPane(),
        _ => const _BridgePane(),
      },
    );
  }
}

/// List and detail, split exactly on the fold when the device is half open.
class _LibraryPane extends StatelessWidget {
  const _LibraryPane({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return FoldAwareTwoPane(
      divider: const VerticalDivider(width: 1),
      startPane: ListView.builder(
        itemCount: 18,
        itemBuilder: (context, index) => ListTile(
          selected: index == selected,
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text('Session ${index + 1}'),
          subtitle: const Text('12 min · 340 MB'),
          onTap: () => onSelected(index),
        ),
      ),
      endPane: _DetailPane(index: selected),
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Session ${index + 1}', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'On the inner display this pane sits on the far side of the fold. '
            'Fold the device and neither pane crosses the hinge.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FoldAlignedGrid(
              itemCount: 12,
              tileHeight: 92,
              itemBuilder: (context, i) => _Tile(index: i),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grid whose columns stay symmetric around the fold.
class _GridPane extends StatefulWidget {
  const _GridPane();

  @override
  State<_GridPane> createState() => _GridPaneState();
}

class _GridPaneState extends State<_GridPane> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // `scroll_end=1` in the launch options jumps to the end of the grid, to
    // check the bottom inset without touching the simulator.
    if (launchOptions['scroll_end'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (_controller.hasClients) {
            _controller.jumpTo(_controller.position.maxScrollExtent);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FoldAlignedGrid(
      controller: _controller,
      itemCount: 36,
      tileHeight: 104,
      minTileWidth: 120,
      itemBuilder: (context, index) => _Tile(index: index),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: index.isEven
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(color: scheme.onSecondaryContainer),
        ),
      ),
    );
  }
}

/// Live values coming from the native bridge — handy while testing in Device Hub.
class _BridgePane extends StatelessWidget {
  const _BridgePane();

  @override
  Widget build(BuildContext context) {
    final duo = DuoScope.of(context);
    final classes = DuoSizeClasses.of(context);
    final edge = duo.barEdgeFor(Directionality.of(context));
    final fold = duo.activeFold;
    final media = MediaQuery.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _Row(
          label: 'Bridge',
          value: duo.isAvailable ? 'connected' : 'unavailable',
        ),
        _Row(
          label: 'iOS 27.1 APIs',
          value: duo.sdk271 ? 'on' : 'off (DUO_SDK_27_1 not set)',
        ),
        _Row(
          label: 'Size',
          value: duo.size == null
              ? '—'
              : '${duo.size!.width.round()} × ${duo.size!.height.round()} pt',
        ),
        _Row(
          label: 'Size classes',
          value: '${classes.horizontal.name} × ${classes.vertical.name}',
        ),
        _Row(
          label: 'Fold in view',
          value: duo.hasDivisionInView ? 'yes' : 'no',
        ),
        _Row(
          label: 'Active fold',
          value: fold == null ? 'none' : fold.rect.toString(),
        ),
        _Row(
          label: 'Pose',
          value: duo.isBookPose
              ? 'book'
              : duo.isTabletopPose
              ? 'tabletop'
              : 'flat',
        ),
        _Row(
          label: 'Hinge',
          value: duo.hinge == null
              ? 'no hinge'
              : '${duo.hinge!.status.name} · ${duo.hinge!.angleDegrees?.round() ?? '—'}°',
        ),
        _Row(label: 'Vertical bar edge', value: edge.name),
        _Row(
          label: 'Raw edge (SwiftUI)',
          value: duo.toolbarVerticalEdgeRaw ?? '—',
        ),
        _Row(
          label: 'Raw edge (UIKit)',
          value: duo.uikitVerticalBarEdgeRaw ?? '—',
        ),
        _Row(
          label: 'Window',
          value:
              '${media.size.width.round()} × ${media.size.height.round()} pt',
        ),
        _Row(
          label: 'root padding',
          value: rootMedia.value == null
              ? '—'
              : _insets(rootMedia.value!.padding),
        ),
        _Row(
          label: 'root viewPadding',
          value: rootMedia.value == null
              ? '—'
              : _insets(rootMedia.value!.viewPadding),
        ),
        _Row(
          label: 'divisions',
          value: duo.divisions
              .map((r) => '${_rect(r.rect)}${r.active ? ' active' : ''}')
              .join('; '),
        ),
        _Row(
          label: 'occlusions',
          value: duo.occlusions.map((r) => _rect(r.rect)).join('; '),
        ),
        _Row(
          label: 'displayFeatures',
          value: media.displayFeatures
              .map(
                (f) =>
                    '${f.type.name} ${f.bounds.left.round()}..${f.bounds.right.round()} ${f.state.name}',
              )
              .join('; '),
        ),
        const SizedBox(height: 24),
        FilledButton.tonal(
          onPressed: () => showDuoDialog<void>(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('Alert'),
              content: Text(
                'Alerts take the upper region in the tabletop pose.',
              ),
            ),
          ),
          child: const Text('Show an anchored dialog'),
        ),
      ],
    );
  }
}

String _rect(Rect r) =>
    '${r.left.round()},${r.top.round()} ${r.width.round()}×${r.height.round()}';

String _insets(EdgeInsets i) =>
    'L${i.left.round()} T${i.top.round()} R${i.right.round()} B${i.bottom.round()}';

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ControlsSheet extends StatelessWidget {
  const _ControlsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Controls', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            const Text(
              'Sheets carrying controls are anchored to the lower region, so in '
              'the tabletop pose they stay within reach.',
            ),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
