// DuoAdaptiveScaffold's actions and tabs, drawn by UIKit: the official Liquid Glass of iOS 26 and later,
// through adaptive_platform_ui. On iPhone Duo the controls sit in the vertical bar as native glass
// capsules; the content below stays fold-aware through iphone_duo_ui_pro.

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:iphone_duo_ui_pro/iphone_duo_ui_pro.dart';

import 'duo_glass_host.dart';

/// Which way the bars run. adaptive_platform_ui decides it from the window's
/// safe area; [DuoGlassPose.forViewPadding] mirrors that rule so the order of
/// the actions matches the bar they end up in.
enum DuoGlassPose {
  /// A toolbar at the top and a tab bar at the bottom.
  horizontal,

  /// The iPhone Duo vertical bar: controls in the strip the system reserves
  /// on one side of the window.
  vertical;

  /// The pose for a window with this padding. On iPhone Duo the window has an
  /// inset on one side only and none at the top; every other configuration
  /// keeps horizontal bars.
  ///
  /// Pass the padding of the window. Inside a page it is no longer the same:
  /// adaptive_platform_ui adds the height of its title band to the top, so
  /// read the pose with [DuoGlassHost.poseOf] there.
  static DuoGlassPose forViewPadding(EdgeInsets viewPadding) {
    if (viewPadding.top != 0) return DuoGlassPose.horizontal;
    final oneSide = (viewPadding.left > 0) != (viewPadding.right > 0);
    return oneSide ? DuoGlassPose.vertical : DuoGlassPose.horizontal;
  }
}

/// A scaffold with the API of [DuoAdaptiveScaffold] and the chrome of
/// adaptive_platform_ui: the Liquid Glass mode, next to the custom navigation
/// mode [DuoAdaptiveScaffold] is.
///
/// On iOS 26 and later the toolbar, the tab bar and, on iPhone Duo, the
/// capsules of the vertical bar are real UIKit views, so the glass is the
/// system's own: it refracts the content behind it, follows light and dark
/// appearance, and picks up whatever Apple changes next. On older versions of
/// iOS the same scaffold renders Cupertino bars, and Material bars on Android.
///
/// The same [DuoBarAction] and [DuoTab] values feed both scaffolds. Give them
/// an `sfSymbol`: UIKit draws SF Symbols, not Flutter icons. Without one the
/// vertical bar shows the Flutter icon over the glass, and the horizontal
/// toolbar shows the label.
///
/// Requires a [DuoGlassHost] above the navigator.
class DuoGlassScaffold extends StatelessWidget {
  /// Creates a Liquid Glass scaffold.
  const DuoGlassScaffold({
    super.key,
    required this.body,
    this.title,
    this.subtitle,
    this.leading,
    this.prominentAction,
    this.topActions = const <DuoBarAction>[],
    this.bottomActions = const <DuoBarAction>[],
    this.textActions = const <DuoTextAction>[],
    this.tabs = const <DuoTab>[],
    this.selectedTabIndex = 0,
    this.onTabSelected,
    this.tintColor,
    this.backdrop,
    this.overflowLabel = 'More',
    this.cancelLabel = 'Cancel',
  });

  /// How many actions stay in the horizontal toolbar next to the prominent
  /// one; the rest move behind the overflow control. The vertical bar has its
  /// own, height-based overflow, handled by adaptive_platform_ui.
  static const int maxInlineActions = 3;

  /// The content of the screen.
  final Widget body;

  /// Title of the page.
  final String? title;

  /// A smaller line under the title.
  final String? subtitle;

  /// Close or Cancel, first in the bar. A page that can go back gets the
  /// system back button by itself, so leave this null for it.
  final DuoBarAction? leading;

  /// The prominent action (Done, Send, Add), in a tinted glass bubble.
  final DuoBarAction? prominentAction;

  /// Actions of the top bar.
  final List<DuoBarAction> topActions;

  /// Actions of the bottom bar. In the vertical bar they form the capsule
  /// above the tabs; in the horizontal layout they follow the top actions.
  final List<DuoBarAction> bottomActions;

  /// Text-only actions such as "Edit" or "Select". The system never puts a
  /// title-only item into the vertical bar, so on iPhone Duo they stay next to
  /// the title; in the horizontal toolbar they are ordinary bar buttons.
  final List<DuoTextAction> textActions;

  /// Tabs; a tab bar is shown for two or more.
  final List<DuoTab> tabs;

  /// Index of the selected tab.
  final int selectedTabIndex;

  /// Called when a tab is selected.
  final ValueChanged<int>? onTabSelected;

  /// Tint of the bar items and of the selected tab.
  final Color? tintColor;

  /// A background that fills the whole window, including the strip of the
  /// vertical bar, which the body itself stays out of. Apple's guidance is to
  /// extend a hero or a background image under the bar
  /// (`backgroundExtensionEffect`, `UIBackgroundExtensionView`); it is also
  /// what gives the glass something to refract. The scaffold turns transparent
  /// above it.
  final Widget? backdrop;

  /// Name of the overflow control of the horizontal toolbar.
  final String overflowLabel;

  /// Label of the button that dismisses the overflow sheet.
  final String cancelLabel;

  /// Maps the actions of a [DuoAdaptiveScaffold] to the toolbar items of
  /// adaptive_platform_ui, in the order Apple gives them in [pose].
  ///
  /// * Vertical: close, the prominent action, top actions, bottom actions.
  ///   Each group ends with a spacer, which is what starts a new glass capsule
  ///   in the bar. [textActions] are left out: a title-only item does not go
  ///   into a vertical bar, the scaffold shows them next to the title.
  /// * Horizontal: close on the leading side; on the trailing side the text
  ///   actions, up to [maxInlineActions] actions by priority, the overflow
  ///   control for the rest ([onOverflow] receives them), and the prominent
  ///   action last.
  static List<AdaptiveAppBarAction> actionsFor({
    required DuoGlassPose pose,
    DuoBarAction? leading,
    DuoBarAction? prominentAction,
    List<DuoBarAction> topActions = const <DuoBarAction>[],
    List<DuoBarAction> bottomActions = const <DuoBarAction>[],
    List<DuoTextAction> textActions = const <DuoTextAction>[],
    String overflowLabel = 'More',
    void Function(List<DuoBarAction> overflow)? onOverflow,
  }) {
    final groups = <List<AdaptiveAppBarAction>>[];
    AdaptiveAppBarAction item(DuoBarAction action, {bool prominent = false}) =>
        _item(action, pose: pose, prominent: prominent);

    if (pose == DuoGlassPose.vertical) {
      if (prominentAction != null) {
        groups.add([item(prominentAction, prominent: true)]);
      }
      groups.add(topActions.map(item).toList());
      groups.add(bottomActions.map(item).toList());
    } else {
      final texts = <AdaptiveAppBarAction>[
        for (final action in textActions)
          AdaptiveAppBarAction(
            title: action.label,
            onPressed: action.onPressed ?? _ignore,
          ),
      ];
      final all = <DuoBarAction>[...topActions, ...bottomActions];
      final ranked = [...all]
        ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
      final kept = ranked.take(maxInlineActions).toSet();
      final overflow = [
        for (final action in all)
          if (!kept.contains(action)) action,
      ];
      groups.add([
        ...texts,
        for (final action in all)
          if (kept.contains(action)) item(action),
        if (overflow.isNotEmpty)
          AdaptiveAppBarAction(
            iosSymbol: 'ellipsis',
            icon: CupertinoIcons.ellipsis,
            label: overflowLabel,
            onPressed: () => onOverflow?.call(overflow),
          ),
      ]);
      if (prominentAction != null) {
        groups.add([item(prominentAction, prominent: true)]);
      }
    }

    final trailing = _join(groups, ToolbarSpacerType.fixed);
    if (leading == null) return trailing;
    // A flexible spacer splits the horizontal toolbar into a leading and a
    // trailing side, and starts a new capsule in the vertical bar.
    return [
      _item(leading, pose: pose, spacerAfter: ToolbarSpacerType.flexible),
      ...trailing,
    ];
  }

  /// Maps [tabs] to the destinations of adaptive_platform_ui.
  static List<AdaptiveNavigationDestination> destinationsFor(
    List<DuoTab> tabs,
  ) => [
    for (final tab in tabs)
      AdaptiveNavigationDestination(
        icon: tab.sfSymbol ?? tab.icon,
        selectedIcon: tab.selectedSfSymbol,
        label: tab.label,
        badgeCount: tab.badgeCount,
      ),
  ];

  static void _ignore() {}

  static AdaptiveAppBarAction _item(
    DuoBarAction action, {
    required DuoGlassPose pose,
    bool prominent = false,
    ToolbarSpacerType spacerAfter = ToolbarSpacerType.none,
  }) {
    // Without an SF Symbol: a UIKit bar button cannot draw a Flutter icon, so
    // the horizontal toolbar shows the action by its name. In the vertical bar
    // adaptive_platform_ui lays the Flutter icon over the native glass, and a
    // title would only get in its way.
    final named = action.sfSymbol == null && pose == DuoGlassPose.horizontal;
    return AdaptiveAppBarAction(
      iosSymbol: action.sfSymbol,
      icon: action.icon,
      title: named ? action.label : null,
      label: action.label,
      prominent: prominent,
      spacerAfter: spacerAfter,
      onPressed: action.onPressed ?? _ignore,
    );
  }

  /// Flattens [groups], ending every group but the last with [spacer].
  static List<AdaptiveAppBarAction> _join(
    List<List<AdaptiveAppBarAction>> groups,
    ToolbarSpacerType spacer,
  ) {
    final filled = groups.where((group) => group.isNotEmpty).toList();
    return [
      for (var g = 0; g < filled.length; g++)
        for (var i = 0; i < filled[g].length; i++)
          i == filled[g].length - 1 && g < filled.length - 1
              ? _withSpacer(filled[g][i], spacer)
              : filled[g][i],
    ];
  }

  static AdaptiveAppBarAction _withSpacer(
    AdaptiveAppBarAction action,
    ToolbarSpacerType spacer,
  ) => AdaptiveAppBarAction(
    iosSymbol: action.iosSymbol,
    icon: action.icon,
    iconWidget: action.iconWidget,
    title: action.title,
    label: action.label,
    prominent: action.prominent,
    tintColor: action.tintColor,
    spacerAfter: spacer,
    onPressed: action.onPressed,
  );

  void _showOverflow(BuildContext context, List<DuoBarAction> actions) {
    showCupertinoModalPopup<void>(
      context: context,
      // The sheet carries controls: the lower region in the tabletop pose.
      anchorPoint: duoAnchorPoint(context, purpose: DuoAnchorPurpose.controls),
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          for (final action in actions)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                action.onPressed?.call();
              },
              child: Text(action.label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(cancelLabel),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pose = DuoGlassHost.poseOf(context);
    final showTabs = tabs.length >= 2;
    final textsByTitle =
        pose == DuoGlassPose.vertical && textActions.isNotEmpty;
    final scaffold = AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: title,
        subtitle: subtitle,
        titleWidget: textsByTitle
            ? _TitleWithTextActions(
                title: title,
                subtitle: subtitle,
                actions: textActions,
                tintColor: tintColor,
              )
            : null,
        useNativeToolbar: true,
        tintColor: tintColor,
        actions: actionsFor(
          pose: pose,
          leading: leading,
          prominentAction: prominentAction,
          topActions: topActions,
          bottomActions: bottomActions,
          textActions: textActions,
          overflowLabel: overflowLabel,
          onOverflow: (overflow) => _showOverflow(context, overflow),
        ),
      ),
      bottomNavigationBar: showTabs
          ? AdaptiveBottomNavigationBar(
              items: destinationsFor(tabs),
              selectedIndex: selectedTabIndex.clamp(0, tabs.length - 1),
              onTap: onTabSelected ?? (_) {},
              selectedItemColor: tintColor,
            )
          : null,
      // Keep the content clear of the side insets (the Dynamic Island in
      // landscape). In the vertical pose adaptive_platform_ui has already
      // taken the strip out of the padding, so nothing is inset twice. Top and
      // bottom stay in MediaQuery: scroll views run under the glass and pad
      // their own content, as on iOS.
      body: _ActiveTabOnly(
        child: SafeArea(top: false, bottom: false, child: body),
      ),
    );

    final backdrop = this.backdrop;
    if (backdrop == null) return scaffold;
    // adaptive_platform_ui keeps the body out of the strip and paints the page
    // in the scaffold colour of the theme. Clear that colour and the backdrop
    // shows through everywhere the body is not, the strip included.
    //
    // Both themes are needed: the Cupertino one for the iOS paths, the
    // Material one for the bars Android gets. The Cupertino theme is copied
    // from the one in scope and placed innermost, so an app built on
    // CupertinoApp keeps its own colours (a Theme on its own would replace
    // them with ones derived from Material).
    const clear = Color(0x00000000);
    return Stack(
      fit: StackFit.expand,
      children: [
        backdrop,
        Theme(
          data: Theme.of(context).copyWith(scaffoldBackgroundColor: clear),
          child: CupertinoTheme(
            data: CupertinoTheme.of(
              context,
            ).copyWith(scaffoldBackgroundColor: clear),
            child: scaffold,
          ),
        ),
      ],
    );
  }
}

/// Builds [child] only where it can be seen.
///
/// With a tab bar, adaptive_platform_ui puts one copy of the body per tab into
/// an `IndexedStack` and shows the selected one. The copies behind it would be
/// built and laid out for nothing, each with its own state and scroll
/// position. The scaffold is re-created on every tab change, so the hidden
/// copies never become visible and there is no state to keep in them.
class _ActiveTabOnly extends StatelessWidget {
  const _ActiveTabOnly({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Visibility.of(context) ? child : const SizedBox.shrink();
}

/// The title band of iPhone Duo with the text-only actions at its trailing
/// end: the system keeps title-only items out of the vertical bar.
///
/// adaptive_platform_ui builds the title above the navigator, so everything
/// here resolves colours from its own context.
class _TitleWithTextActions extends StatelessWidget {
  const _TitleWithTextActions({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.tintColor,
  });

  final String? title;
  final String? subtitle;
  final List<DuoTextAction> actions;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final row = Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // The metrics adaptive_platform_ui uses for a plain title.
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
            ],
          ),
        ),
        for (final action in actions)
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: action.onPressed,
            child: Text(action.label),
          ),
      ],
    );
    final tint = tintColor;
    if (tint == null) return row;
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(primaryColor: tint),
      child: row,
    );
  }
}
