// A gallery of iphone_duo_ui_pro_glass.
//
// The bars are UIKit's own Liquid Glass (through adaptive_platform_ui); the
// content below them is laid out by iphone_duo_ui_pro. Run it on an iPhone Duo
// simulator: the toolbar and the tab bar move into the vertical bar as native
// glass capsules, the panes split on the fold, the grid mirrors around it.

import 'dart:async';
import 'dart:io' show Directory, File;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:iphone_duo_ui_pro_glass/iphone_duo_ui_pro_glass.dart';

void main() => runApp(const DuoGlassGalleryApp());

const Color _seed = Color(0xFF0F6079);

/// The gallery runs in either of the two modes `iphone_duo_ui_pro` offers for
/// the bars: official Liquid Glass (`DuoGlassScaffold`, UIKit) or custom
/// navigation (`DuoAdaptiveScaffold`, drawn by Flutter). The same actions and
/// tabs feed both; switch on the Controls tab, with `mode=custom` in the launch
/// options, or with the `mode=` remote command.
final ValueNotifier<bool> liquidGlass = ValueNotifier<bool>(
  launchOptions['mode'] != 'custom',
);

/// Launch options for screenshots and recordings, read from
/// `<app data container>/tmp/duo_launch.txt`, e.g. `tab=1;demo=1`.
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

class DuoGlassGalleryApp extends StatelessWidget {
  const DuoGlassGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duo Glass gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed),
      darkTheme: ThemeData(colorSchemeSeed: _seed, brightness: Brightness.dark),
      // One line wires both packages: the bridge, the fold as a DisplayFeature,
      // and the fixed Liquid Glass toolbar host.
      builder: (context, child) => DuoGlassHost(
        child: _EnvironmentLog(child: child ?? const SizedBox.shrink()),
      ),
      home: const GalleryHome(),
    );
  }
}

/// Prints the environment on every change, so the state can be read from the
/// simulator log without touching the screen.
class _EnvironmentLog extends StatelessWidget {
  const _EnvironmentLog({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final duo = DuoScope.of(context);
    debugPrint(
      'DUO-ENV size=${media.size.width.round()}x${media.size.height.round()} '
      'viewPadding=${_insets(media.viewPadding)} '
      'pose=${DuoGlassPose.forViewPadding(media.viewPadding).name} '
      'core=${DuoAdaptiveScaffold.resolveLayout(context).name} '
      'classes=${duo.horizontalSizeClass.name}x${duo.verticalSizeClass.name} '
      'sdk271=${duo.sdk271} hinge=${duo.hinge?.status.name}:${duo.hinge?.angleDegrees?.round()} '
      'divisions=[${duo.divisions.map((r) => '${_rect(r.rect)}${r.active ? '!' : ''}').join('; ')}] '
      'occlusions=[${duo.occlusions.map((r) => _rect(r.rect)).join('; ')}]',
    );
    return child;
  }
}

class GalleryHome extends StatefulWidget {
  const GalleryHome({super.key});

  @override
  State<GalleryHome> createState() => _GalleryHomeState();
}

class _GalleryHomeState extends State<GalleryHome> {
  int _tab = (int.tryParse(launchOptions['tab'] ?? '') ?? 0).clamp(0, 3);
  int _selected = 0;
  int _unread = 3;
  Timer? _remote;
  String _lastCommand = '';

  static const List<String> _titles = <String>[
    'Library',
    'Grid',
    'Controls',
    'Bridge',
  ];

  @override
  void initState() {
    super.initState();
    // A remote control for recordings: taps sent to a simulator in the
    // background never arrive, so the host writes commands into
    // `<app data container>/tmp/duo_cmd.txt` instead, as `<counter>:<command>`.
    // Commands: tab=2, open=3, back, alert, scroll=640, mode=custom, mode=glass.
    if (launchOptions['remote'] == '1') {
      // Whatever is in the file now was meant for an earlier run.
      _pollCommand(execute: false);
      _remote = Timer.periodic(
        const Duration(milliseconds: 150),
        (_) => _pollCommand(),
      );
    }
  }

  void _pollCommand({bool execute = true}) {
    try {
      final file = File('${Directory.systemTemp.path}/duo_cmd.txt');
      if (!file.existsSync()) return;
      final raw = file.readAsStringSync().trim();
      if (raw == _lastCommand || !raw.contains(':')) return;
      _lastCommand = raw;
      if (execute) _run(raw.substring(raw.indexOf(':') + 1));
    } on Object {
      // A half-written file: the next poll reads it again.
    }
  }

  void _run(String command) {
    if (!mounted) return;
    final value = command.contains('=') ? command.split('=')[1] : '';
    final navigator = Navigator.of(context);
    debugPrint('DUO-CMD $command');
    if (command.startsWith('tab=')) {
      setState(() => _tab = (int.tryParse(value) ?? 0).clamp(0, 3));
    } else if (command.startsWith('open=')) {
      final index = int.tryParse(value) ?? 0;
      setState(() => _selected = index);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (context) => _SessionPage(index: index),
        ),
      );
    } else if (command.startsWith('mode=')) {
      liquidGlass.value = value != 'custom';
    } else if (command == 'back') {
      navigator.maybePop();
    } else if (command == 'alert') {
      _openDialog();
    } else if (command.startsWith('select=')) {
      setState(() => _selected = int.tryParse(value) ?? 0);
    } else if (command.startsWith('scroll=')) {
      final offset = double.tryParse(value) ?? 0;
      for (final position in gridScroll.positions) {
        position.animateTo(
          offset,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _remote?.cancel();
    super.dispose();
  }

  void _openDialog() {
    AdaptiveAlertDialog.show(
      context: context,
      title: 'Official Liquid Glass',
      message:
          'This alert, the toolbar and the tab bar are UIKit views. '
          'The layout underneath is Flutter.',
      actions: <AlertAction>[AlertAction(title: 'Close', onPressed: () {})],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prominentAction = DuoBarAction(
      icon: Icons.add,
      sfSymbol: 'plus',
      label: 'Add',
      onPressed: () => setState(() => _unread++),
    );
    final topActions = <DuoBarAction>[
      DuoBarAction(
        icon: Icons.edit_outlined,
        sfSymbol: 'square.and.pencil',
        label: 'Compose',
        priority: DuoVisibilityPriority.high,
        onPressed: _openDialog,
      ),
      DuoBarAction(
        icon: Icons.inbox_outlined,
        sfSymbol: 'tray',
        label: 'Inbox',
        onPressed: () => setState(() => _unread = 0),
      ),
      DuoBarAction(
        icon: Icons.delete_outline,
        sfSymbol: 'trash',
        label: 'Delete',
        priority: DuoVisibilityPriority.low,
        onPressed: () {},
      ),
    ];
    final bottomActions = <DuoBarAction>[
      DuoBarAction(
        icon: Icons.tune,
        sfSymbol: 'slider.horizontal.3',
        label: 'Filters',
        onPressed: () {},
      ),
    ];
    final textActions = <DuoTextAction>[
      DuoTextAction(label: 'Select', onPressed: () {}),
    ];
    final tabs = <DuoTab>[
      const DuoTab(
        icon: Icons.photo_library_outlined,
        sfSymbol: 'photo.on.rectangle',
        selectedSfSymbol: 'photo.fill.on.rectangle.fill',
        label: 'Library',
      ),
      const DuoTab(
        icon: Icons.grid_view_outlined,
        sfSymbol: 'square.grid.2x2',
        selectedSfSymbol: 'square.grid.2x2.fill',
        label: 'Grid',
      ),
      const DuoTab(
        icon: Icons.toggle_on_outlined,
        sfSymbol: 'switch.2',
        label: 'Controls',
      ),
      DuoTab(
        icon: Icons.memory_outlined,
        sfSymbol: 'cpu',
        selectedSfSymbol: 'cpu.fill',
        label: 'Bridge',
        badgeCount: _unread == 0 ? null : _unread,
      ),
    ];
    final body = switch (_tab) {
      0 => _LibraryPane(
        selected: _selected,
        onSelected: (index) => setState(() => _selected = index),
      ),
      1 => const _GridPane(),
      2 => const _ControlsPane(),
      _ => const _BridgePane(),
    };
    void selectTab(int index) => setState(() => _tab = index);

    // Two modes, one set of values: the same actions and tabs go to whichever
    // scaffold draws the bars.
    return ValueListenableBuilder<bool>(
      valueListenable: liquidGlass,
      builder: (context, glass, _) {
        if (glass) {
          return DuoGlassScaffold(
            title: _titles[_tab],
            tintColor: _tint(context),
            backdrop: const _Backdrop(),
            textActions: textActions,
            prominentAction: prominentAction,
            topActions: topActions,
            bottomActions: bottomActions,
            tabs: tabs,
            selectedTabIndex: _tab,
            onTabSelected: selectTab,
            body: body,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const _Backdrop(),
            DuoAdaptiveScaffold(
              title: _titles[_tab],
              backgroundColor: Colors.transparent,
              textActions: textActions,
              prominentAction: prominentAction,
              topActions: topActions,
              bottomActions: bottomActions,
              tabs: tabs,
              selectedTabIndex: _tab,
              onTabSelected: selectTab,
              body: body,
            ),
          ],
        );
      },
    );
  }
}

/// List and detail, split exactly on the fold when the device is half open.
/// At compact width (the cover display) the list stands alone and a session
/// opens as a page of its own, with the system back button in the glass bar.
class _LibraryPane extends StatelessWidget {
  const _LibraryPane({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: FoldAwareTwoPane(
        divider: const VerticalDivider(width: 1),
        startPane: _SessionList(selected: selected, onSelected: onSelected),
        endPane: _DetailPane(index: selected),
        compactPane: _SessionList(
          selected: selected,
          onSelected: (index) {
            onSelected(index);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => _SessionPage(index: index),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 18,
      itemBuilder: (context, index) => ListTile(
        selected: index == selected,
        leading: CircleAvatar(
          backgroundColor: _tileColor(index),
          foregroundColor: Colors.white,
          child: Text('${index + 1}'),
        ),
        title: Text('Session ${index + 1}'),
        subtitle: const Text('12 min · 340 MB'),
        onTap: () => onSelected(index),
      ),
    );
  }
}

/// A pushed page: the back button appears in the bar on its own.
class _SessionPage extends StatelessWidget {
  const _SessionPage({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final topActions = <DuoBarAction>[
      DuoBarAction(
        icon: Icons.ios_share,
        sfSymbol: 'square.and.arrow.up',
        label: 'Share',
        onPressed: () {},
      ),
      DuoBarAction(
        icon: Icons.star_border,
        sfSymbol: 'star',
        label: 'Favourite',
        onPressed: () {},
      ),
    ];
    final body = Material(
      type: MaterialType.transparency,
      child: _DetailPane(index: index),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: liquidGlass,
      builder: (context, glass, _) {
        if (glass) {
          return DuoGlassScaffold(
            title: 'Session ${index + 1}',
            tintColor: _tint(context),
            topActions: topActions,
            backdrop: const _Backdrop(),
            body: body,
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const _Backdrop(),
            DuoAdaptiveScaffold(
              title: 'Session ${index + 1}',
              backgroundColor: Colors.transparent,
              // The system back button is UIKit's; here it is an action.
              leading: DuoBarAction(
                icon: Icons.arrow_back_ios_new,
                label: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              topActions: topActions,
              body: body,
            ),
          ],
        );
      },
    );
  }
}

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Session ${index + 1}', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'The bars are UIKit. The panes are Flutter, and neither of them '
              'crosses the hinge.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: FoldAlignedGrid(
                  itemCount: 12,
                  tileHeight: 92,
                  itemBuilder: (context, i) => _Tile(index: i + index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scroll positions of the grid, for the `scroll=` remote command.
final ScrollController gridScroll = ScrollController();

/// A grid whose columns stay symmetric around the fold.
class _GridPane extends StatelessWidget {
  const _GridPane();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: FoldAlignedGrid(
        controller: gridScroll,
        itemCount: 48,
        tileHeight: 104,
        minTileWidth: 120,
        itemBuilder: (context, index) => _Tile(index: index),
      ),
    );
  }
}

/// A background that runs under the vertical bar, the way Apple asks a hero or
/// a background image to: it is what the glass capsules refract.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF0B141A) : const Color(0xFFF4F8FA);
    final strength = dark ? 0.55 : 0.42;

    Widget light(Alignment center, Color color, double radius) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: <Color>[
              color.withValues(alpha: strength),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: base),
        light(const Alignment(1.1, -0.75), const Color(0xFF18B7C9), 0.9),
        light(const Alignment(1.15, 0.2), const Color(0xFF7A5CFF), 0.8),
        light(const Alignment(0.9, 1.1), const Color(0xFFFF9F45), 0.75),
        light(const Alignment(-1.1, 1.0), const Color(0xFF18B7C9), 0.7),
      ],
    );
  }
}

/// The brand colour in light mode, its lighter tone in dark mode, where the
/// seed itself would not read on the glass.
Color _tint(BuildContext context) => Theme.of(context).colorScheme.primary;

Color _tileColor(int index) {
  const hues = <double>[192, 168, 212, 28, 340, 262, 142, 48];
  return HSLColor.fromAHSL(1, hues[index % hues.length], 0.62, 0.52).toColor();
}

class _Tile extends StatelessWidget {
  const _Tile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final color = _tileColor(index);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[color, Color.lerp(color, Colors.black, 0.28)!],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Native Liquid Glass controls from adaptive_platform_ui, one group per pane.
class _ControlsPane extends StatefulWidget {
  const _ControlsPane();

  @override
  State<_ControlsPane> createState() => _ControlsPaneState();
}

class _ControlsPaneState extends State<_ControlsPane> {
  bool _glass = true;
  double _level = 0.6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: FoldAwareTwoPane(
        startPane: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text('Native controls', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Bars drawn by', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: liquidGlass,
                builder: (context, glass, _) => AdaptiveSegmentedControl(
                  labels: const <String>['Flutter', 'UIKit glass'],
                  selectedIndex: glass ? 1 : 0,
                  onValueChanged: (index) => liquidGlass.value = index == 1,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  const Expanded(child: Text('Liquid Glass')),
                  AdaptiveSwitch(
                    value: _glass,
                    activeColor: _tint(context),
                    onChanged: (value) => setState(() => _glass = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdaptiveSlider(
                value: _level,
                activeColor: _tint(context),
                onChanged: (value) => setState(() => _level = value),
              ),
            ],
          ),
        ),
        endPane: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              Text('Buttons', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              AdaptiveButton(
                onPressed: () {},
                style: AdaptiveButtonStyle.prominentGlass,
                color: _tint(context),
                textColor: Theme.of(context).colorScheme.onPrimary,
                label: 'Prominent glass',
              ),
              const SizedBox(height: 12),
              AdaptiveButton(
                onPressed: () {},
                style: AdaptiveButtonStyle.glass,
                textColor: _tint(context),
                label: 'Glass',
              ),
              const SizedBox(height: 12),
              AdaptiveButton(
                onPressed: () {},
                style: AdaptiveButtonStyle.tinted,
                color: _tint(context),
                label: 'Tinted',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Live values from the native bridge, handy while folding the simulator.
class _BridgePane extends StatelessWidget {
  const _BridgePane();

  @override
  Widget build(BuildContext context) {
    final duo = DuoScope.of(context);
    final classes = DuoSizeClasses.of(context);
    final fold = duo.activeFold;
    final media = MediaQuery.of(context);
    final angle = duo.hinge?.angleDegrees;

    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, media.padding.top + 12, 20, 40),
        children: <Widget>[
          Text(
            angle == null ? '—' : '${angle.round()}°',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: _tint(context),
            ),
          ),
          Text(
            duo.hinge == null ? 'no hinge' : duo.hinge!.status.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _Row(
            label: 'Chrome',
            value: PlatformInfo.isIOS26OrHigher()
                ? 'UIKit Liquid Glass (iOS ${PlatformInfo.iOSVersion})'
                : 'fallback bars',
          ),
          _Row(label: 'Bars', value: DuoGlassHost.poseOf(context).name),
          _Row(
            label: 'Bridge',
            value: duo.isAvailable ? 'connected' : 'unavailable',
          ),
          _Row(label: 'iOS 27.1 APIs', value: duo.sdk271 ? 'on' : 'off'),
          _Row(
            label: 'Window',
            value:
                '${media.size.width.round()} × ${media.size.height.round()} pt',
          ),
          _Row(
            label: 'Size classes',
            value: '${classes.horizontal.name} × ${classes.vertical.name}',
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
            label: 'Active fold',
            value: fold == null ? 'none' : _rect(fold.rect),
          ),
          _Row(
            label: 'Occlusions',
            value: duo.occlusions.map((r) => _rect(r.rect)).join('; '),
          ),
        ],
      ),
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
            width: 130,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
