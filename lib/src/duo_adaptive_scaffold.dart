// A scaffold with an iPhone Duo vertical bar (HIG "Vertical controls", Tech Talk "Raise the bar").
// Sources: Apple iPhone Duo Tech Talks and HIG - see README.md.
//
// Rules taken from Apple:
// * a vertical bar on the outer display and on the inner display in landscape; horizontal bars on the
//   inner display in portrait, and the bar is aligned to the hardware (in RTL it stays on the same side),
// * order from the top: back/close -> prominent action -> top actions -> overflow -> spacer -> bottom
//   actions -> tab bar, with an icon and a label on every action (tooltip, semantics, overflow menu),
// * overflow fills from the bottom up by priority; compression takes the toolbar first (navigational)
//   or the tab bar first (task-based). The bar stays inside the safe area, clear of the status bar column.
// Content state (scroll offset, fields) survives the switch between the horizontal and vertical layouts.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'duo_environment.dart';

/// Visibility priority of an action (the equivalent of visibilityPriority).
enum DuoVisibilityPriority {
  /// Moved to the overflow menu first.
  low,

  /// The default: overflow order follows position, from the bottom up.
  automatic,

  /// Kept visible as long as there is room.
  high,
}

/// What compresses first when the vertical bar runs out of room.
enum DuoBarCompression {
  /// Toolbar actions move to the overflow menu, the tab bar stays: navigational experiences. The default.
  toolbarFirst,

  /// The tab bar collapses to a single button, actions stay: task-based experiences.
  tabBarFirst,
}

/// Forces a bar layout (null means automatic).
enum DuoBarLayout {
  /// A regular [AppBar] and [NavigationBar].
  horizontal,

  /// A vertical bar on the hardware edge.
  vertical,
}

/// A bar action: always an icon and a label.
@immutable
class DuoBarAction {
  /// Creates a bar action.
  const DuoBarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.priority = DuoVisibilityPriority.automatic,
    this.badgeCount,
    this.sfSymbol,
  });

  /// Symbol shown in the bar.
  final IconData icon;

  /// Label used for the tooltip, accessibility and the overflow menu.
  final String label;

  /// Called when the action is tapped; null disables it.
  final VoidCallback? onPressed;

  /// How eagerly the action moves to the overflow menu.
  final DuoVisibilityPriority priority;

  /// A count shown as a badge instead of text next to the icon.
  final int? badgeCount;

  /// SF Symbol name, such as `square.and.pencil`, for renderers that draw the
  /// action with UIKit (the `iphone_duo_ui_pro_glass` companion). This
  /// package's own widgets draw [icon] and ignore it.
  final String? sfSymbol;
}

/// A text-only action such as "Edit" or "Select". It stays in the horizontal header.
@immutable
class DuoTextAction {
  /// Creates a text-only action.
  const DuoTextAction({required this.label, required this.onPressed});

  /// Text shown in the horizontal header.
  final String label;

  /// Called when the action is tapped; null disables it.
  final VoidCallback? onPressed;
}

/// A tab.
@immutable
class DuoTab {
  /// Creates a tab.
  const DuoTab({
    required this.icon,
    required this.label,
    this.badgeCount,
    this.sfSymbol,
    this.selectedSfSymbol,
  });

  /// Symbol shown in the tab bar.
  final IconData icon;

  /// Label of the tab.
  final String label;

  /// A count shown as a badge on the tab.
  final int? badgeCount;

  /// SF Symbol name, such as `photo.on.rectangle`, for renderers that draw the
  /// tab bar with UIKit (the `iphone_duo_ui_pro_glass` companion). This
  /// package's own widgets draw [icon] and ignore it.
  final String? sfSymbol;

  /// SF Symbol for the selected state, usually the `.fill` variant of
  /// [sfSymbol]. Falls back to [sfSymbol].
  final String? selectedSfSymbol;
}

/// The result of planning the vertical bar.
@immutable
class DuoVerticalBarPlan {
  /// Creates a plan for the vertical bar.
  const DuoVerticalBarPlan({
    required this.visibleTop,
    required this.visibleBottom,
    required this.overflow,
    required this.tabsCollapsed,
  });

  /// Indices of the visible actions from `topActions`.
  final List<int> visibleTop;

  /// Indices of the visible actions from `bottomActions`.
  final List<int> visibleBottom;

  /// Actions in the overflow menu, in visual order.
  final List<DuoBarAction> overflow;

  /// Whether the tab bar collapsed to a single button.
  final bool tabsCollapsed;
}

/// A scaffold that moves its actions and tabs into a vertical bar on iPhone Duo.
///
/// This is the custom navigation mode: Flutter draws the bars, so they look the
/// same on every platform and are yours to restyle. The other mode is official
/// Liquid Glass: `DuoGlassScaffold` in the companion package
/// `iphone_duo_ui_pro_glass` takes the same actions and tabs and lets UIKit
/// draw them.
///
/// In the horizontal layout it renders a regular [AppBar] and [NavigationBar]. In the
/// vertical layout the same actions sit in a bar on the hardware edge, ordered
/// back/close, [prominentAction], [topActions], overflow, [bottomActions], [tabs].
class DuoAdaptiveScaffold extends StatefulWidget {
  /// Creates an adaptive scaffold.
  const DuoAdaptiveScaffold({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.prominentAction,
    this.topActions = const <DuoBarAction>[],
    this.bottomActions = const <DuoBarAction>[],
    this.textActions = const <DuoTextAction>[],
    this.tabs = const <DuoTab>[],
    this.selectedTabIndex = 0,
    this.onTabSelected,
    this.compression = DuoBarCompression.toolbarFirst,
    this.layout,
    this.backgroundColor,
    this.floatingActionButton,
  }) : assert(
         floatingActionButton == null || prominentAction != null,
         'A floating action button is not shown in the vertical bar. Pass the same action as '
         'prominentAction so it stays reachable in every configuration.',
       );

  /// Height of one item in the vertical bar, in logical pixels.
  static const double itemExtent = 48;

  /// Gap between items in the vertical bar.
  static const double itemGap = 4;

  /// Gap between groups in the vertical bar.
  static const double groupGap = 16;

  /// Padding at the top and bottom of the vertical bar.
  static const double barPadding = 8;

  /// Width of the vertical bar, including padding.
  static const double barWidth = 64;

  /// How many top actions stay in the horizontal app bar; the rest, and the
  /// bottom actions when a tab bar is shown, go to the overflow menu.
  static const int maxInlineActions = 3;

  /// A safe-area inset at least this wide on the bar edge is treated as the
  /// system column (status bar and camera); the bar then moves into it.
  static const double minSystemColumnWidth = 56;

  /// Distance from the physical edge to the axis the system centres its status
  /// bar glyphs on: 143.5 px at 3x, measured to the pixel on both displays of
  /// the iOS 27.1 simulator. It coincides with the centre of the outer camera.
  static const double systemColumnAxisFromEdge = 143.5 / 3;

  /// The content of the screen.
  final Widget body;

  /// Title shown in the horizontal [AppBar].
  final String? title;

  /// Back or Close - always at the top of the vertical bar.
  final DuoBarAction? leading;

  /// The prominent action (Done, Send, Add) - right below back/close, and never moved to overflow.
  /// It also takes over the role of the floating action button in the vertical layout.
  final DuoBarAction? prominentAction;

  /// Actions from the top bar (the top group in the vertical layout).
  final List<DuoBarAction> topActions;

  /// Actions from the bottom bar (the bottom group in the vertical layout).
  final List<DuoBarAction> bottomActions;

  /// Text-only actions, always horizontal, in the header.
  final List<DuoTextAction> textActions;

  /// Tabs shown in the [NavigationBar], or at the bottom of the vertical bar.
  final List<DuoTab> tabs;

  /// Index of the selected tab.
  final int selectedTabIndex;

  /// Called when a tab is selected.
  final ValueChanged<int>? onTabSelected;

  /// What compresses first when the vertical bar runs out of room.
  final DuoBarCompression compression;

  /// Forces a layout; null picks one from the environment.
  final DuoBarLayout? layout;

  /// Background color of the scaffold.
  final Color? backgroundColor;

  /// A floating action button only in the horizontal layout (a regular iPhone, Android, the inner display
  /// in portrait), so those keep their usual look. In the vertical layout [prominentAction] takes over and
  /// must be provided. When a fab is given, [prominentAction] is not duplicated in the horizontal AppBar.
  final Widget? floatingActionButton;

  /// Vertical when the system reports a bar edge (iOS 27.1). Otherwise only on a folding iPhone:
  /// in landscape, or when the shortest side is below 600 (the outer display, a Split View half).
  static DuoBarLayout resolveLayout(BuildContext context) {
    final environment = DuoScope.of(context);
    if (environment.verticalBarEdgeKnown) return DuoBarLayout.vertical;
    if (!environment.hasFoldHardware) return DuoBarLayout.horizontal;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    return isLandscape || size.shortestSide < 600
        ? DuoBarLayout.vertical
        : DuoBarLayout.horizontal;
  }

  /// The physical edge of the vertical bar, the right one by default.
  static DuoBarEdge resolveEdge(BuildContext context) {
    final edge = DuoScope.of(context).barEdgeFor(Directionality.of(context));
    return edge == DuoBarEdge.none ? DuoBarEdge.right : edge;
  }

  /// Plans action visibility in a vertical bar [availableHeight] tall.
  static DuoVerticalBarPlan planVerticalBar({
    required double availableHeight,
    required int fixedTopCount,
    required List<DuoBarAction> topActions,
    required List<DuoBarAction> bottomActions,
    required int tabCount,
    required DuoBarCompression compression,
  }) {
    final overflowedTop = <int>{};
    final overflowedBottom = <int>{};
    var tabsCollapsed = false;

    double groupHeight(int count) =>
        count <= 0 ? 0 : count * itemExtent + (count - 1) * itemGap;

    bool fits() {
      final hasOverflow =
          overflowedTop.isNotEmpty || overflowedBottom.isNotEmpty;
      final top =
          fixedTopCount +
          topActions.length -
          overflowedTop.length +
          (hasOverflow ? 1 : 0);
      final bottom = bottomActions.length - overflowedBottom.length;
      final tabItems = tabCount == 0 ? 0 : (tabsCollapsed ? 1 : tabCount);
      var height = 2 * barPadding + groupHeight(top);
      if (bottom > 0) height += groupGap + groupHeight(bottom);
      if (tabItems > 0) height += groupGap + groupHeight(tabItems);
      return height <= availableHeight;
    }

    if (compression == DuoBarCompression.tabBarFirst &&
        tabCount > 1 &&
        !fits()) {
      tabsCollapsed = true;
    }

    // Overflow order: low priority first, then from the bottom up.
    final candidates =
        <
            ({
              bool isTop,
              int index,
              DuoVisibilityPriority priority,
              int visualOrder,
            })
          >[
            for (var i = 0; i < topActions.length; i++)
              (
                isTop: true,
                index: i,
                priority: topActions[i].priority,
                visualOrder: i,
              ),
            for (var i = 0; i < bottomActions.length; i++)
              (
                isTop: false,
                index: i,
                priority: bottomActions[i].priority,
                visualOrder: topActions.length + i,
              ),
          ]
          ..sort((a, b) {
            final byPriority = a.priority.index.compareTo(b.priority.index);
            return byPriority != 0
                ? byPriority
                : b.visualOrder.compareTo(a.visualOrder);
          });

    for (final candidate in candidates) {
      if (fits()) break;
      (candidate.isTop ? overflowedTop : overflowedBottom).add(candidate.index);
    }
    if (!fits() && tabCount > 1) tabsCollapsed = true;

    return DuoVerticalBarPlan(
      visibleTop: [
        for (var i = 0; i < topActions.length; i++)
          if (!overflowedTop.contains(i)) i,
      ],
      visibleBottom: [
        for (var i = 0; i < bottomActions.length; i++)
          if (!overflowedBottom.contains(i)) i,
      ],
      overflow: [
        for (var i = 0; i < topActions.length; i++)
          if (overflowedTop.contains(i)) topActions[i],
        for (var i = 0; i < bottomActions.length; i++)
          if (overflowedBottom.contains(i)) bottomActions[i],
      ],
      tabsCollapsed: tabsCollapsed,
    );
  }

  @override
  State<DuoAdaptiveScaffold> createState() => _DuoAdaptiveScaffoldState();
}

class _DuoAdaptiveScaffoldState extends State<DuoAdaptiveScaffold> {
  /// The content goes once into `Scaffold.body` and once into the `Row` of the vertical layout. A GlobalKey
  /// moves the element together with its state (scroll offset, text fields) as the device opens and rotates.
  final GlobalKey _bodyKey = GlobalKey(debugLabel: 'DuoAdaptiveScaffold.body');

  @override
  Widget build(BuildContext context) {
    final body = KeyedSubtree(key: _bodyKey, child: widget.body);
    final resolved =
        widget.layout ?? DuoAdaptiveScaffold.resolveLayout(context);
    return resolved == DuoBarLayout.vertical
        ? _buildVertical(context, body)
        : _buildHorizontal(context, body);
  }

  Widget _buildVertical(BuildContext context, Widget body) {
    final edge = DuoAdaptiveScaffold.resolveEdge(context);
    final appDirection = Directionality.of(context);
    final media = MediaQuery.of(context);
    final environment = DuoScope.of(context);
    final leading = widget.leading;
    final prominentAction = widget.prominentAction;

    // The system column: on iPhone Duo the status bar and the camera live in a
    // safe-area inset along the bar edge (84 pt on both displays). The system
    // draws its own bars inside that column, so the scaffold does the same:
    // the bar takes the column and starts below the status/camera region,
    // which the bridge reports as an occlusion. Without a column (a regular
    // iPhone, tests) the bar keeps its own width inside the safe area.
    final columnInset = edge == DuoBarEdge.left
        ? media.padding.left
        : media.padding.right;
    final inSystemColumn =
        columnInset >= DuoAdaptiveScaffold.minSystemColumnWidth;
    final columnWidth = inSystemColumn
        ? columnInset
        : DuoAdaptiveScaffold.barWidth;
    var topClearance = inSystemColumn ? media.padding.top : 0.0;
    if (inSystemColumn) {
      for (final occlusion in environment.occlusions) {
        final rect = occlusion.rect;
        final overlapsColumn = edge == DuoBarEdge.left
            ? rect.left < columnWidth
            : rect.right > media.size.width - columnWidth;
        if (overlapsColumn && rect.top <= topClearance + 1) {
          topClearance = math.max(topClearance, rect.bottom);
        }
      }
    }
    final bottomClearance = inSystemColumn ? media.padding.bottom : 0.0;

    // The system centres its status bar glyphs 48 pt from the physical edge on
    // both displays (measured to the pixel on the iOS 27.1 simulator), not on
    // the middle of the 84 pt column, so the bar items share that axis.
    final axisFromEdge = inSystemColumn
        ? DuoAdaptiveScaffold.systemColumnAxisFromEdge
        : columnWidth / 2;
    final half = DuoAdaptiveScaffold.itemExtent / 2;
    final edgePad = math.max(0.0, axisFromEdge - half);
    final innerPad = math.max(0.0, columnWidth - axisFromEdge - half);

    final bar = SizedBox(
      width: columnWidth,
      child: Padding(
        padding: EdgeInsets.only(
          top: topClearance + DuoAdaptiveScaffold.barPadding,
          bottom: bottomClearance + DuoAdaptiveScaffold.barPadding,
          left: edge == DuoBarEdge.left ? edgePad : innerPad,
          right: edge == DuoBarEdge.left ? innerPad : edgePad,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final plan = DuoAdaptiveScaffold.planVerticalBar(
              availableHeight:
                  constraints.maxHeight + 2 * DuoAdaptiveScaffold.barPadding,
              fixedTopCount:
                  (leading != null ? 1 : 0) + (prominentAction != null ? 1 : 0),
              topActions: widget.topActions,
              bottomActions: widget.bottomActions,
              tabCount: widget.tabs.length,
              compression: widget.compression,
            );
            return Column(
              children: [
                if (leading != null) _DuoBarButton(action: leading),
                if (prominentAction != null)
                  _DuoBarButton(action: prominentAction, prominent: true),
                for (final index in plan.visibleTop)
                  _DuoBarButton(action: widget.topActions[index]),
                if (plan.overflow.isNotEmpty)
                  _DuoOverflowButton(actions: plan.overflow),
                const Spacer(),
                for (final index in plan.visibleBottom)
                  _DuoBarButton(action: widget.bottomActions[index]),
                if (widget.tabs.isNotEmpty) ...[
                  if (plan.visibleBottom.isNotEmpty)
                    const SizedBox(height: DuoAdaptiveScaffold.groupGap),
                  if (plan.tabsCollapsed)
                    _DuoCollapsedTabs(
                      tabs: widget.tabs,
                      selectedIndex: widget.selectedTabIndex,
                      onSelected: widget.onTabSelected,
                    )
                  else
                    _DuoVerticalTabs(
                      tabs: widget.tabs,
                      selectedIndex: widget.selectedTabIndex,
                      onSelected: widget.onTabSelected,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null || widget.textActions.isNotEmpty)
          _DuoHeader(title: widget.title, textActions: widget.textActions),
        Expanded(child: body),
      ],
    );

    final barSide = Directionality(textDirection: appDirection, child: bar);
    final contentSide = Expanded(
      child: Directionality(
        textDirection: appDirection,
        // The bar owns the inset on its edge; the content keeps the others.
        // The bottom inset stays in MediaQuery instead of clipping the content:
        // scroll views run to the edge and pad their own content, as on iOS.
        child: inSystemColumn
            ? SafeArea(
                left: edge != DuoBarEdge.left,
                right: edge != DuoBarEdge.right,
                bottom: false,
                child: content,
              )
            : content,
      ),
    );

    final row = Directionality(
      // Physical order: the bar is aligned to the hardware regardless of RTL.
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: edge == DuoBarEdge.left
            ? [barSide, contentSide]
            : [contentSide, barSide],
      ),
    );

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: inSystemColumn ? row : SafeArea(bottom: false, child: row),
    );
  }

  Widget _buildHorizontal(BuildContext context, Widget body) {
    final tabs = widget.tabs;
    final showTabs = tabs.length >= 2;
    final leading = widget.leading;
    final prominentAction = widget.prominentAction;

    // One bar at the bottom, never two. With tabs the bottom belongs to the tab
    // bar, so the bottom actions join the overflow menu of the top bar; without
    // tabs they keep their own toolbar row, as on iOS.
    final inline = <DuoBarAction>[];
    final overflow = <DuoBarAction>[];
    final ranked = [...widget.topActions]
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
    final kept = ranked.take(DuoAdaptiveScaffold.maxInlineActions).toSet();
    for (final action in widget.topActions) {
      (kept.contains(action) ? inline : overflow).add(action);
    }
    if (showTabs) overflow.addAll(widget.bottomActions);

    final bottomBar = showTabs || widget.bottomActions.isEmpty
        ? null
        : Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final action in widget.bottomActions)
                      _DuoBarButton(action: action),
                  ],
                ),
              ),
            ),
          );

    final Widget? bottomNavigation = showTabs
        ? NavigationBar(
            selectedIndex: widget.selectedTabIndex.clamp(0, tabs.length - 1),
            onDestinationSelected: widget.onTabSelected,
            destinations: [
              for (final tab in tabs)
                NavigationDestination(
                  icon: _withBadge(Icon(tab.icon), tab.badgeCount),
                  label: tab.label,
                ),
            ],
          )
        : bottomBar;

    return Scaffold(
      backgroundColor: widget.backgroundColor,
      appBar: AppBar(
        leading: leading == null ? null : _DuoBarButton(action: leading),
        title: widget.title == null ? null : Text(widget.title!),
        actions: [
          for (final action in widget.textActions)
            TextButton(onPressed: action.onPressed, child: Text(action.label)),
          for (final action in inline) _DuoBarButton(action: action),
          if (prominentAction != null && widget.floatingActionButton == null)
            _DuoBarButton(action: prominentAction, prominent: true),
          if (overflow.isNotEmpty) _DuoOverflowButton(actions: overflow),
          const SizedBox(width: 8),
        ],
      ),
      // Keep the content clear of the side insets (the Dynamic Island in
      // landscape); top and bottom stay with the bars and the scroll views.
      body: SafeArea(top: false, bottom: false, child: body),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: bottomNavigation,
    );
  }
}

Widget _withBadge(Widget icon, int? count) =>
    count == null || count <= 0 ? icon : Badge.count(count: count, child: icon);

class _DuoBarButton extends StatelessWidget {
  const _DuoBarButton({required this.action, this.prominent = false});

  final DuoBarAction action;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final icon = _withBadge(Icon(action.icon), action.badgeCount);
    return prominent
        ? IconButton.filled(
            onPressed: action.onPressed,
            tooltip: action.label,
            icon: icon,
          )
        : IconButton(
            onPressed: action.onPressed,
            tooltip: action.label,
            icon: icon,
          );
  }
}

class _DuoOverflowButton extends StatelessWidget {
  const _DuoOverflowButton({required this.actions});

  final List<DuoBarAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_horiz),
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: (index) => actions[index].onPressed?.call(),
      itemBuilder: (context) => [
        for (var i = 0; i < actions.length; i++)
          PopupMenuItem<int>(
            value: i,
            enabled: actions[i].onPressed != null,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _withBadge(Icon(actions[i].icon), actions[i].badgeCount),
              title: Text(actions[i].label),
            ),
          ),
      ],
    );
  }
}

class _DuoVerticalTabs extends StatelessWidget {
  const _DuoVerticalTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DuoTab> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(DuoAdaptiveScaffold.itemExtent / 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabs.length; i++)
            IconButton(
              isSelected: i == selectedIndex,
              tooltip: tabs[i].label,
              onPressed: onSelected == null ? null : () => onSelected!(i),
              icon: _withBadge(Icon(tabs[i].icon), tabs[i].badgeCount),
            ),
        ],
      ),
    );
  }
}

class _DuoCollapsedTabs extends StatelessWidget {
  const _DuoCollapsedTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<DuoTab> tabs;
  final int selectedIndex;
  final ValueChanged<int>? onSelected;

  @override
  Widget build(BuildContext context) {
    final current = tabs[selectedIndex.clamp(0, tabs.length - 1)];
    return PopupMenuButton<int>(
      tooltip: current.label,
      icon: _withBadge(Icon(current.icon), current.badgeCount),
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (var i = 0; i < tabs.length; i++)
          CheckedPopupMenuItem<int>(
            value: i,
            checked: i == selectedIndex,
            child: Text(tabs[i].label),
          ),
      ],
    );
  }
}

class _DuoHeader extends StatelessWidget {
  const _DuoHeader({required this.title, required this.textActions});

  final String? title;
  final List<DuoTextAction> textActions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Semantics(
                    header: true,
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          for (final action in textActions)
            TextButton(onPressed: action.onPressed, child: Text(action.label)),
        ],
      ),
    );
  }
}
