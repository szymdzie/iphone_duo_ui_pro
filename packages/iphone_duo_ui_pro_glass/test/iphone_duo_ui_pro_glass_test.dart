import 'dart:ui' show DisplayFeatureType;

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/cupertino.dart' show CupertinoTheme, CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iphone_duo_ui_pro_glass/iphone_duo_ui_pro_glass.dart';

// Geometry measured on the iPhone Duo simulator (iOS 27.1), see the core package.
const EdgeInsets coverDisplay = EdgeInsets.only(right: 84, bottom: 34);
const EdgeInsets innerLandscape = EdgeInsets.only(right: 84, bottom: 34);
const EdgeInsets innerLandscapeFlipped = EdgeInsets.only(left: 84, bottom: 34);
const EdgeInsets innerPortrait = EdgeInsets.only(top: 82, bottom: 34);
const EdgeInsets iPhonePortrait = EdgeInsets.only(top: 62, bottom: 34);
const EdgeInsets iPhoneLandscape = EdgeInsets.only(
  left: 62,
  right: 62,
  bottom: 20,
);

DuoBarAction action(
  String label, {
  String? sfSymbol,
  DuoVisibilityPriority priority = DuoVisibilityPriority.automatic,
  VoidCallback? onPressed,
}) => DuoBarAction(
  icon: Icons.circle,
  label: label,
  sfSymbol: sfSymbol,
  priority: priority,
  onPressed: onPressed ?? () {},
);

List<String?> labels(List<AdaptiveAppBarAction> actions) => [
  for (final a in actions) a.effectiveLabel,
];

void main() {
  group('DuoGlassPose.forViewPadding', () {
    test('iPhone Duo: a strip on one side and no top inset is vertical', () {
      expect(DuoGlassPose.forViewPadding(coverDisplay), DuoGlassPose.vertical);
      expect(
        DuoGlassPose.forViewPadding(innerLandscape),
        DuoGlassPose.vertical,
      );
      expect(
        DuoGlassPose.forViewPadding(innerLandscapeFlipped),
        DuoGlassPose.vertical,
      );
    });

    test('everything else keeps horizontal bars', () {
      expect(
        DuoGlassPose.forViewPadding(innerPortrait),
        DuoGlassPose.horizontal,
      );
      expect(
        DuoGlassPose.forViewPadding(iPhonePortrait),
        DuoGlassPose.horizontal,
      );
      expect(
        DuoGlassPose.forViewPadding(iPhoneLandscape),
        DuoGlassPose.horizontal,
      );
      expect(
        DuoGlassPose.forViewPadding(EdgeInsets.zero),
        DuoGlassPose.horizontal,
      );
    });
  });

  group('DuoGlassScaffold.actionsFor, vertical bar', () {
    test('order is close, prominent, top, bottom; text actions stay out', () {
      final actions = DuoGlassScaffold.actionsFor(
        pose: DuoGlassPose.vertical,
        leading: action('Close', sfSymbol: 'xmark'),
        prominentAction: action('Add', sfSymbol: 'plus'),
        textActions: [DuoTextAction(label: 'Select', onPressed: () {})],
        topActions: [action('Compose'), action('Inbox')],
        bottomActions: [action('Filters')],
      );
      // A title-only item never goes into a vertical bar.
      expect(labels(actions), ['Close', 'Add', 'Compose', 'Inbox', 'Filters']);
    });

    test('every group ends with a spacer, so each gets its own capsule', () {
      final actions = DuoGlassScaffold.actionsFor(
        pose: DuoGlassPose.vertical,
        leading: action('Close'),
        prominentAction: action('Add'),
        topActions: [action('Compose'), action('Inbox')],
        bottomActions: [action('Filters')],
      );
      expect(
        [for (final a in actions) a.spacerAfter],
        [
          ToolbarSpacerType.flexible, // Close
          ToolbarSpacerType.fixed, // Add
          ToolbarSpacerType.none, // Compose
          ToolbarSpacerType.fixed, // Inbox
          ToolbarSpacerType.none, // Filters: the last group
        ],
      );
      expect(actions[1].prominent, isTrue);
      expect(actions.where((a) => a.prominent), hasLength(1));
    });

    test('nothing is dropped: overflow in the bar is up to the chrome', () {
      final actions = DuoGlassScaffold.actionsFor(
        pose: DuoGlassPose.vertical,
        topActions: [for (var i = 0; i < 8; i++) action('Top $i')],
      );
      expect(actions, hasLength(8));
      expect(actions.last.spacerAfter, ToolbarSpacerType.none);
    });
  });

  group('DuoGlassScaffold.actionsFor, horizontal toolbar', () {
    test('keeps three actions by priority and puts the prominent one last', () {
      List<DuoBarAction>? overflowed;
      final actions = DuoGlassScaffold.actionsFor(
        pose: DuoGlassPose.horizontal,
        prominentAction: action('Add'),
        topActions: [
          action('Compose', priority: DuoVisibilityPriority.high),
          action('Inbox'),
          action('Delete', priority: DuoVisibilityPriority.low),
        ],
        bottomActions: [action('Filters')],
        onOverflow: (overflow) => overflowed = overflow,
      );
      expect(labels(actions), ['Compose', 'Inbox', 'Filters', 'More', 'Add']);
      expect(actions.last.prominent, isTrue);
      // The overflow control ends its group; the prominent action follows.
      expect(actions[3].spacerAfter, ToolbarSpacerType.fixed);
      expect(actions[3].iosSymbol, 'ellipsis');

      actions[3].onPressed();
      expect(overflowed!.map((a) => a.label), ['Delete']);
    });

    test('no overflow control when everything fits', () {
      final actions = DuoGlassScaffold.actionsFor(
        pose: DuoGlassPose.horizontal,
        topActions: [action('Compose'), action('Inbox')],
        overflowLabel: 'Więcej',
      );
      expect(labels(actions), ['Compose', 'Inbox']);
      expect(
        actions.every((a) => a.spacerAfter == ToolbarSpacerType.none),
        isTrue,
      );
    });

    test('close sits on the leading side, behind a flexible spacer', () {
      final actions = DuoGlassScaffold.actionsFor(
        pose: DuoGlassPose.horizontal,
        leading: action('Close', sfSymbol: 'xmark'),
        topActions: [action('Share')],
      );
      expect(labels(actions), ['Close', 'Share']);
      expect(actions.first.spacerAfter, ToolbarSpacerType.flexible);
    });
  });

  group('mapping', () {
    test('an SF Symbol draws the action in both bars', () {
      for (final pose in DuoGlassPose.values) {
        final item = DuoGlassScaffold.actionsFor(
          pose: pose,
          topActions: [action('Compose', sfSymbol: 'square.and.pencil')],
        ).single;
        expect(item.iosSymbol, 'square.and.pencil');
        expect(item.title, isNull);
        expect(item.label, 'Compose');
        expect(item.icon, Icons.circle);
      }
    });

    test(
      'without one: a name in the toolbar, the Flutter icon on the glass',
      () {
        final horizontal = DuoGlassScaffold.actionsFor(
          pose: DuoGlassPose.horizontal,
          topActions: [action('Compose')],
        ).single;
        expect(horizontal.title, 'Compose');

        final vertical = DuoGlassScaffold.actionsFor(
          pose: DuoGlassPose.vertical,
          topActions: [action('Compose')],
        ).single;
        expect(vertical.title, isNull);
        expect(vertical.icon, Icons.circle);
        expect(vertical.label, 'Compose');
      },
    );

    test('text actions are bar buttons in the horizontal toolbar', () {
      var selected = 0;
      final actions = DuoGlassScaffold.actionsFor(
        pose: DuoGlassPose.horizontal,
        textActions: [
          DuoTextAction(label: 'Select', onPressed: () => selected++),
        ],
        topActions: [action('Compose')],
      );
      expect(labels(actions), ['Select', 'Compose']);
      actions.first.onPressed();
      expect(selected, 1);
    });

    test('a disabled action stays in the bar and does nothing', () {
      final item = DuoGlassScaffold.actionsFor(
        pose: DuoGlassPose.vertical,
        topActions: const [
          DuoBarAction(icon: Icons.circle, label: 'Off', onPressed: null),
        ],
      ).single;
      expect(item.onPressed, returnsNormally);
    });

    test('tabs become destinations, with SF Symbols when given', () {
      final destinations = DuoGlassScaffold.destinationsFor(const [
        DuoTab(
          icon: Icons.photo_library_outlined,
          sfSymbol: 'photo.on.rectangle',
          selectedSfSymbol: 'photo.fill.on.rectangle.fill',
          label: 'Library',
          badgeCount: 3,
        ),
        DuoTab(icon: Icons.grid_view, label: 'Grid'),
      ]);
      expect(destinations[0].icon, 'photo.on.rectangle');
      expect(destinations[0].selectedIcon, 'photo.fill.on.rectangle.fill');
      expect(destinations[0].label, 'Library');
      expect(destinations[0].badgeCount, 3);
      // No symbol: adaptive_platform_ui draws the Flutter icon over the glass.
      expect(destinations[1].icon, Icons.grid_view);
    });
  });

  group('DuoGlassHost', () {
    const fold = DuoRegion(rect: Rect.fromLTWH(456, 0, 40, 669), active: true);
    const environment = DuoEnvironment(
      isAvailable: true,
      sdk271: true,
      size: Size(951, 669),
      horizontalSizeClass: DuoSizeClass.regular,
      verticalSizeClass: DuoSizeClass.regular,
      divisions: <DuoRegion>[fold],
      hinge: DuoHinge(status: DuoHingeStatus.partiallyOpen, angleDegrees: 128),
    );

    testWidgets('publishes the bridge and the fold below the toolbar host', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(951, 669);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      late DuoEnvironment seen;
      late MediaQueryData media;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              DuoGlassHost(environment: environment, child: child!),
          home: Builder(
            builder: (context) {
              seen = DuoScope.of(context);
              media = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(seen.isBookPose, isTrue);
      expect(find.byType(AdaptiveToolbarHost), findsOneWidget);
      final folds = media.displayFeatures.where(
        (f) => f.type == DisplayFeatureType.fold,
      );
      expect(folds.single.bounds, fold.rect);
    });

    testWidgets('decides the pose once, above the pages', (tester) async {
      late DuoGlassPose fromHost;
      late DuoGlassPose fromPage;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: coverDisplay, viewPadding: coverDisplay),
            child: DuoGlassHost(environment: environment, child: child!),
          ),
          // What adaptive_platform_ui does to the body of a page with a
          // title: the band is added to the top of the padding.
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(viewPadding: coverDisplay.copyWith(top: 70)),
              child: Builder(
                builder: (context) {
                  fromHost = DuoGlassHost.poseOf(context);
                  fromPage = DuoGlassPose.forViewPadding(
                    MediaQuery.viewPaddingOf(context),
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      expect(fromHost, DuoGlassPose.vertical);
      expect(fromPage, DuoGlassPose.horizontal);
    });

    testWidgets('leaves the toolbar host to AdaptiveApp when asked to', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => DuoGlassHost(
            installToolbarHost: false,
            environment: environment,
            child: child!,
          ),
          home: const SizedBox.shrink(),
        ),
      );
      expect(find.byType(AdaptiveToolbarHost), findsNothing);
    });
  });

  group('DuoGlassScaffold', () {
    Widget app({required Widget home, EdgeInsets padding = EdgeInsets.zero}) {
      return MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: padding, viewPadding: padding),
          child: DuoGlassHost(
            environment: DuoEnvironment.unavailable,
            child: child!,
          ),
        ),
        home: home,
      );
    }

    // The test host is neither iOS nor Android, so adaptive_platform_ui draws
    // its Material bars: the same fallback an Android build gets.
    testWidgets('falls back to platform bars with the same actions and tabs', (
      tester,
    ) async {
      var tab = 0;
      var composed = 0;
      await tester.pumpWidget(
        app(
          home: StatefulBuilder(
            builder: (context, setState) => DuoGlassScaffold(
              title: 'Library',
              topActions: [
                action(
                  'Compose',
                  sfSymbol: 'square.and.pencil',
                  onPressed: () => composed++,
                ),
              ],
              tabs: const [
                DuoTab(icon: Icons.photo_library_outlined, label: 'Library'),
                DuoTab(icon: Icons.grid_view_outlined, label: 'Grid'),
              ],
              selectedTabIndex: tab,
              onTabSelected: (index) => setState(() => tab = index),
              body: Text('tab $tab'),
            ),
          ),
        ),
      );

      expect(find.text('Library'), findsWidgets);
      expect(find.text('tab 0'), findsOneWidget);

      await tester.tap(find.text('Grid'));
      await tester.pumpAndSettle();
      expect(tab, 1);
      expect(find.text('tab 1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.circle));
      expect(composed, 1);
    });

    testWidgets('a single tab shows no tab bar', (tester) async {
      await tester.pumpWidget(
        app(
          home: const DuoGlassScaffold(
            title: 'Solo',
            tabs: [DuoTab(icon: Icons.home, label: 'Home')],
            body: SizedBox.expand(),
          ),
        ),
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Home'), findsNothing);
    });

    testWidgets('iPhone Duo: text actions sit next to the title', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(466, 678);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selected = 0;
      await tester.pumpWidget(
        app(
          padding: coverDisplay,
          home: DuoGlassScaffold(
            title: 'Library',
            textActions: [
              DuoTextAction(label: 'Select', onPressed: () => selected++),
            ],
            topActions: [action('Compose', sfSymbol: 'square.and.pencil')],
            body: const SizedBox.expand(),
          ),
        ),
      );
      expect(find.text('Library'), findsOneWidget);
      await tester.tap(find.text('Select'));
      expect(selected, 1);
    });

    testWidgets('a backdrop fills the window behind a transparent scaffold', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(466, 678);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const backdropKey = Key('backdrop');
      await tester.pumpWidget(
        app(
          padding: coverDisplay,
          home: const DuoGlassScaffold(
            title: 'Library',
            backdrop: ColoredBox(key: backdropKey, color: Color(0xFF0F6079)),
            body: SizedBox.expand(),
          ),
        ),
      );
      expect(
        tester.getRect(find.byKey(backdropKey)),
        const Rect.fromLTWH(0, 0, 466, 678),
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final background =
          scaffold.backgroundColor ??
          Theme.of(
            tester.element(find.byType(Scaffold).first),
          ).scaffoldBackgroundColor;
      expect(background.a, 0);
    });

    testWidgets('the backdrop clears the Cupertino scaffold colour too, and '
        'keeps the rest of the theme', (tester) async {
      late CupertinoThemeData inside;
      late CupertinoThemeData outside;
      await tester.pumpWidget(
        app(
          home: Builder(
            builder: (context) {
              outside = CupertinoTheme.of(context);
              return DuoGlassScaffold(
                title: 'Library',
                backdrop: const ColoredBox(color: Color(0xFF0F6079)),
                body: Builder(
                  builder: (context) {
                    inside = CupertinoTheme.of(context);
                    return const SizedBox.expand();
                  },
                ),
              );
            },
          ),
        ),
      );
      // Passing a Material-based Cupertino theme as `cupertinoOverrideTheme`
      // silently drops the colour, so the scaffold nests a CupertinoTheme.
      expect(inside.scaffoldBackgroundColor.a, 0);
      expect(inside.primaryColor, outside.primaryColor);
    });

    testWidgets('the body keeps clear of the side insets', (tester) async {
      tester.view.physicalSize = const Size(874, 402);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const bodyKey = Key('body');
      await tester.pumpWidget(
        app(
          padding: iPhoneLandscape,
          home: const DuoGlassScaffold(
            title: 'Grid',
            body: SizedBox.expand(key: bodyKey),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(bodyKey));
      expect(rect.left, 62);
      expect(rect.right, 874 - 62);
    });
  });
}
