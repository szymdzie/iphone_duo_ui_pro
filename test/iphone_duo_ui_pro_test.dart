// Tests for the iPhone Duo widgets.
//
// Sizes in points: the App Store Connect screenshot spec divided by 3
// (outer 1398x2034 px -> 466x678 pt, inner 2007x2853 px -> 669x951 pt).
// The fold position (screen centre, 16 pt wide) is a test assumption; confirm it in Device Hub
// once Xcode 27.1 is available.
// See README.md for the full source list.

import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;

import 'package:iphone_duo_ui_pro/iphone_duo_ui_pro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size innerLandscape = Size(951, 669);
const Size innerPortrait = Size(669, 951);
const Size outerPortrait = Size(466, 678);
const Size outerLandscape = Size(678, 466);

/// Centre of the inner display and the assumed width of an active fold.
const double foldCenter = 475.5;
const double foldWidth = 16;
const double foldStart = foldCenter - foldWidth / 2; // 467.5
const double foldEnd = foldCenter + foldWidth / 2; // 483.5

/// Inner display in landscape: a vertical fold (book pose when [active]).
DuoEnvironment foldEnvironment({required bool active}) => DuoEnvironment(
  isAvailable: true,
  sdk271: true,
  size: innerLandscape,
  horizontalSizeClass: DuoSizeClass.regular,
  verticalSizeClass: DuoSizeClass.regular,
  divisions: [
    DuoRegion(
      rect: active
          ? const Rect.fromLTWH(foldStart, 0, foldWidth, 669)
          : const Rect.fromLTWH(foldCenter, 0, 0, 669),
      active: active,
    ),
  ],
  hinge: DuoHinge(
    status: active ? DuoHingeStatus.partiallyOpen : DuoHingeStatus.fullyOpen,
    angleDegrees: active ? 120 : 180,
  ),
);

/// Inner display in portrait: a horizontal fold (tabletop pose when [active]).
DuoEnvironment tabletopEnvironment({required bool active}) => DuoEnvironment(
  isAvailable: true,
  sdk271: true,
  size: innerPortrait,
  horizontalSizeClass: DuoSizeClass.regular,
  verticalSizeClass: DuoSizeClass.regular,
  divisions: [
    DuoRegion(
      rect: active
          ? const Rect.fromLTWH(0, foldStart, 669, foldWidth)
          : const Rect.fromLTWH(0, foldCenter, 669, 0),
      active: active,
    ),
  ],
  hinge: DuoHinge(
    status: active ? DuoHingeStatus.partiallyOpen : DuoHingeStatus.fullyOpen,
    angleDegrees: active ? 110 : 180,
  ),
);

void setLogicalSize(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3.0;
  addTearDown(tester.view.reset);
}

Widget duoApp(DuoEnvironment environment, {required Widget home}) =>
    MaterialApp(
      builder: (context, child) => DuoScope(
        environment: environment,
        child: DuoDisplayFeatures(child: child ?? const SizedBox.shrink()),
      ),
      home: home,
    );

class DialogLauncher extends StatelessWidget {
  const DialogLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => showDuoDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('Delete?')),
              ),
              child: const Text('open'),
            ),
            ElevatedButton(
              onPressed: () => showDuoModalBottomSheet<void>(
                context: context,
                builder: (_) => const SizedBox(
                  height: 120,
                  child: Center(child: Text('sheet')),
                ),
              ),
              child: const Text('sheet-open'),
            ),
          ],
        ),
      ),
    );
  }
}

List<DuoBarAction> mailBottomActions() => [
  DuoBarAction(
    icon: Icons.delete,
    label: 'Delete',
    onPressed: () {},
    priority: DuoVisibilityPriority.low,
  ),
  DuoBarAction(icon: Icons.folder, label: 'Move', onPressed: () {}),
  DuoBarAction(icon: Icons.reply, label: 'Reply', onPressed: () {}),
  DuoBarAction(
    icon: Icons.edit_square,
    label: 'Compose',
    onPressed: () {},
    priority: DuoVisibilityPriority.high,
  ),
];

void main() {
  group('DuoEnvironment', () {
    test('fromMap: book pose, hinge, bar edge', () {
      final environment = DuoEnvironment.fromMap(<Object?, Object?>{
        'sdk271': true,
        'width': 951.0,
        'height': 669.0,
        'horizontalSizeClass': 'regular',
        'verticalSizeClass': 'regular',
        'toolbarVerticalEdge': 'Optional(SwiftUI.HorizontalEdge.trailing)',
        'uikitVerticalBarEdge': 'unavailable',
        'divisions': <Object?>[
          <Object?, Object?>{
            'x': foldStart,
            'y': 0.0,
            'width': foldWidth,
            'height': 669.0,
            'active': true,
          },
        ],
        'occlusions': <Object?>[],
        'hinge': <Object?, Object?>{
          'status': 'partiallyOpen',
          'angleDegrees': 120.0,
        },
      });
      expect(environment.isBookPose, isTrue);
      expect(environment.isTabletopPose, isFalse);
      expect(environment.hinge?.status, DuoHingeStatus.partiallyOpen);
      expect(environment.verticalBarEdgeKnown, isTrue);
      expect(environment.barEdgeFor(TextDirection.ltr), DuoBarEdge.right);
      expect(environment.barEdgeFor(TextDirection.rtl), DuoBarEdge.left);
      expect(duoEvenColumns(3, environment), 2);
    });

    test('no edge information: nil/unavailable', () {
      const environment = DuoEnvironment(
        toolbarVerticalEdgeRaw: 'nil',
        uikitVerticalBarEdgeRaw: 'unavailable',
      );
      expect(environment.verticalBarEdgeKnown, isFalse);
      expect(environment.barEdgeFor(TextDirection.ltr), DuoBarEdge.none);
      expect(duoEvenColumns(3, environment), 3);
    });

    test(
      'duoEvenColumns: hinge without a fold region in view (outer display) -> unchanged',
      () {
        const environment = DuoEnvironment(
          isAvailable: true,
          hinge: DuoHinge(status: DuoHingeStatus.closed),
        );
        expect(environment.hasFoldHardware, isTrue);
        expect(environment.hasDivisionInView, isFalse);
        expect(duoEvenColumns(3, environment), 3);
      },
    );

    test('DuoSizeClasses.estimate for the iPhone Duo configurations', () {
      expect(
        DuoSizeClasses.estimate(outerPortrait),
        const DuoSizeClasses(DuoSizeClass.compact, DuoSizeClass.regular),
      );
      expect(
        DuoSizeClasses.estimate(outerLandscape),
        const DuoSizeClasses(DuoSizeClass.compact, DuoSizeClass.compact),
      );
      expect(
        DuoSizeClasses.estimate(innerPortrait),
        const DuoSizeClasses(DuoSizeClass.regular, DuoSizeClass.regular),
      );
      expect(
        DuoSizeClasses.estimate(innerLandscape),
        const DuoSizeClasses(DuoSizeClass.regular, DuoSizeClass.regular),
      );
      // Half of the inner display in Split View.
      expect(
        DuoSizeClasses.estimate(const Size(475, 669)),
        const DuoSizeClasses(DuoSizeClass.compact, DuoSizeClass.regular),
      );
    });
  });

  group('duoDisplayFeaturesFor', () {
    test('active fold -> fold + postureHalfOpened', () {
      final feature = duoDisplayFeaturesFor(
        foldEnvironment(active: true),
        innerLandscape,
      ).single;
      expect(feature.type, DisplayFeatureType.fold);
      expect(feature.state, DisplayFeatureState.postureHalfOpened);
      expect(feature.bounds, const Rect.fromLTWH(foldStart, 0, foldWidth, 669));
    });

    test('inactive fold -> zero-width line + postureFlat', () {
      final feature = duoDisplayFeaturesFor(
        foldEnvironment(active: false),
        innerLandscape,
      ).single;
      expect(feature.state, DisplayFeatureState.postureFlat);
      expect(feature.bounds.width, 0);
    });

    test('an active but degenerate fold does not create a silent half', () {
      const environment = DuoEnvironment(
        divisions: [
          DuoRegion(rect: Rect.fromLTWH(foldCenter, 0, 0, 669), active: true),
        ],
      );
      final feature = duoDisplayFeaturesFor(environment, innerLandscape).single;
      expect(feature.state, DisplayFeatureState.postureFlat);
    });

    test('camera -> cutout with an unknown state', () {
      const environment = DuoEnvironment(
        occlusions: [
          DuoRegion(rect: Rect.fromLTWH(640, 20, 40, 40), active: true),
        ],
      );
      final feature = duoDisplayFeaturesFor(environment, innerLandscape).single;
      expect(feature.type, DisplayFeatureType.cutout);
      expect(feature.state, DisplayFeatureState.unknown);
    });
  });

  group('dialogs and sheets at the fold', () {
    testWidgets('book pose: dialog on the trailing side', (tester) async {
      setLogicalSize(tester, innerLandscape);
      await tester.pumpWidget(
        duoApp(foldEnvironment(active: true), home: const DialogLauncher()),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(AlertDialog)).left,
        greaterThanOrEqualTo(foldEnd),
      );
    });

    testWidgets('flat: dialog centred on the whole screen', (tester) async {
      setLogicalSize(tester, innerLandscape);
      await tester.pumpWidget(
        duoApp(foldEnvironment(active: false), home: const DialogLauncher()),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(AlertDialog)).center.dx,
        closeTo(foldCenter, 1),
      );
    });

    testWidgets(
      'a dialog opened flat moves to the trailing side after folding',
      (tester) async {
        setLogicalSize(tester, innerLandscape);
        await tester.pumpWidget(
          duoApp(foldEnvironment(active: false), home: const DialogLauncher()),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(AlertDialog)).center.dx,
          closeTo(foldCenter, 1),
        );

        await tester.pumpWidget(
          duoApp(foldEnvironment(active: true), home: const DialogLauncher()),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(AlertDialog)).left,
          greaterThanOrEqualTo(foldEnd),
        );
      },
    );

    testWidgets('tabletop: alert in the upper region', (tester) async {
      setLogicalSize(tester, innerPortrait);
      await tester.pumpWidget(
        duoApp(tabletopEnvironment(active: true), home: const DialogLauncher()),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(AlertDialog)).bottom,
        lessThanOrEqualTo(foldStart),
      );
    });

    testWidgets('tabletop: a sheet with controls in the lower region', (
      tester,
    ) async {
      setLogicalSize(tester, innerPortrait);
      await tester.pumpWidget(
        duoApp(tabletopEnvironment(active: true), home: const DialogLauncher()),
      );
      await tester.tap(find.text('sheet-open'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('sheet')).top,
        greaterThanOrEqualTo(foldEnd),
      );
    });
  });

  group('FoldAwareTwoPane', () {
    const start = ColoredBox(key: Key('start'), color: Colors.red);
    const end = ColoredBox(key: Key('end'), color: Colors.blue);

    testWidgets('active fold: panes on either side', (tester) async {
      setLogicalSize(tester, innerLandscape);
      await tester.pumpWidget(
        duoApp(
          foldEnvironment(active: true),
          home: const FoldAwareTwoPane(startPane: start, endPane: end),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('start'))).right,
        closeTo(foldStart, 0.5),
      );
      expect(
        tester.getRect(find.byKey(const Key('end'))).left,
        closeTo(foldEnd, 0.5),
      );
    });

    testWidgets('flat, regular: a narrower start pane', (tester) async {
      setLogicalSize(tester, innerLandscape);
      await tester.pumpWidget(
        duoApp(
          foldEnvironment(active: false),
          home: const FoldAwareTwoPane(startPane: start, endPane: end),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const Key('start'))).width,
        closeTo(951 * 0.38, 0.5),
      );
    });

    testWidgets('compact: a single pane', (tester) async {
      setLogicalSize(tester, outerPortrait);
      const environment = DuoEnvironment(
        isAvailable: true,
        horizontalSizeClass: DuoSizeClass.compact,
        verticalSizeClass: DuoSizeClass.regular,
      );
      await tester.pumpWidget(
        duoApp(
          environment,
          home: const FoldAwareTwoPane(startPane: start, endPane: end),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('start')), findsNothing);
      expect(find.byKey(const Key('end')), findsOneWidget);
    });
  });

  group('FoldAlignedGrid', () {
    test('no fold: columns from width (iPhone in portrait: 3)', () {
      final columns = planFoldAlignedColumns(width: 390, minTileWidth: 104);
      expect(columns.count, 3);
      expect(columns.offsets.first, 16);
      expect(
        columns.offsets.last + columns.tileWidth,
        closeTo(390 - 16, 0.001),
      );
    });

    test('fold in view: an even column count', () {
      expect(planFoldAlignedColumns(width: 669, minTileWidth: 104).count, 5);
      expect(
        planFoldAlignedColumns(
          width: 669,
          minTileWidth: 104,
          evenColumns: true,
        ).count,
        4,
      );
    });

    test(
      'vertical bar on the side: columns stay symmetric around the fold when folding',
      () {
        const width =
            951.0 -
            DuoAdaptiveScaffold
                .barWidth; // content beside the vertical bar on the right
        final flat = planFoldAlignedColumns(
          width: width,
          minTileWidth: 104,
          fold: const GridFold(start: foldCenter, end: foldCenter),
          evenColumns: true,
        );
        final folded = planFoldAlignedColumns(
          width: width,
          minTileWidth: 104,
          fold: const GridFold(start: foldStart, end: foldEnd),
          evenColumns: true,
        );
        expect(flat.count.isEven, isTrue);
        expect(folded.count, flat.count);
        final half = folded.count ~/ 2;
        expect(
          flat.offsets[half - 1] + flat.tileWidth,
          lessThanOrEqualTo(foldCenter),
        );
        expect(flat.offsets[half], greaterThanOrEqualTo(foldCenter));
        expect(
          folded.offsets[half - 1] + folded.tileWidth,
          lessThanOrEqualTo(foldStart),
        );
        expect(folded.offsets[half], greaterThanOrEqualTo(foldEnd));
        expect(folded.offsets.first, closeTo(flat.offsets.first, 0.001));
        expect(
          folded.offsets.last + folded.tileWidth,
          closeTo(flat.offsets.last + flat.tileWidth, 0.001),
        );
      },
    );

    test('fold at the grid edge (Split View): a plain even grid', () {
      final columns = planFoldAlignedColumns(
        width: 475,
        minTileWidth: 104,
        fold: const GridFold(start: foldStart, end: foldEnd),
        evenColumns: true,
      );
      expect(columns.count, 2);
      expect(columns.offsets.first, 16);
    });

    testWidgets(
      'DuoAdaptiveScaffold + FoldAlignedGrid in book pose: no tile crosses the fold',
      (tester) async {
        setLogicalSize(tester, innerLandscape);
        await tester.pumpWidget(
          duoApp(
            foldEnvironment(active: true),
            home: DuoAdaptiveScaffold(
              title: 'Produkty',
              body: FoldAlignedGrid(
                itemCount: 12,
                tileHeight: 80,
                itemBuilder: (context, index) =>
                    ColoredBox(key: ValueKey<int>(index), color: Colors.teal),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(AppBar),
          findsNothing,
        ); // the vertical bar is on the right

        final lefts = <int>{};
        for (var i = 0; i < 12; i++) {
          final finder = find.byKey(ValueKey<int>(i));
          if (finder.evaluate().isEmpty) continue;
          final rect = tester.getRect(finder);
          lefts.add(rect.left.round());
          expect(
            rect.right <= foldStart + 0.5 || rect.left >= foldEnd - 0.5,
            isTrue,
            reason: 'tile \$i (\${rect.left}-\${rect.right}) sits in the fold',
          );
        }
        expect(lefts.length.isEven, isTrue);
      },
    );
  });

  group('DuoAdaptiveScaffold', () {
    test(
      'planVerticalBar: tabBarFirst collapses the tab bar before the actions',
      () {
        final actions = [
          for (var i = 0; i < 3; i++)
            DuoBarAction(icon: Icons.star, label: 'A$i', onPressed: () {}),
        ];
        final plan = DuoAdaptiveScaffold.planVerticalBar(
          availableHeight: 360,
          fixedTopCount: 1,
          topActions: actions,
          bottomActions: const [],
          tabCount: 4,
          compression: DuoBarCompression.tabBarFirst,
        );
        expect(plan.tabsCollapsed, isTrue);
        expect(plan.overflow, isEmpty);
      },
    );

    test(
      'planVerticalBar: toolbarFirst moves actions to overflow and keeps the tab bar',
      () {
        final actions = [
          for (var i = 0; i < 3; i++)
            DuoBarAction(icon: Icons.star, label: 'A$i', onPressed: () {}),
        ];
        final plan = DuoAdaptiveScaffold.planVerticalBar(
          availableHeight: 360,
          fixedTopCount: 1,
          topActions: actions,
          bottomActions: const [],
          tabCount: 4,
          compression: DuoBarCompression.toolbarFirst,
        );
        expect(plan.tabsCollapsed, isFalse);
        expect(plan.overflow.map((a) => a.label), ['A0', 'A1', 'A2']);
      },
    );

    testWidgets(
      'short screen in landscape: vertical bar on the right, overflow from the bottom',
      (tester) async {
        setLogicalSize(tester, const Size(678, 300));
        const environment = DuoEnvironment(
          isAvailable: true,
          sdk271: true,
          toolbarVerticalEdgeRaw: 'Optional(SwiftUI.HorizontalEdge.trailing)',
          divisions: [
            DuoRegion(rect: Rect.fromLTWH(339, 0, 0, 300), active: false),
          ],
        );
        await tester.pumpWidget(
          duoApp(
            environment,
            home: DuoAdaptiveScaffold(
              title: 'Mail',
              leading: DuoBarAction(
                icon: Icons.arrow_back,
                label: 'Back',
                onPressed: () {},
              ),
              topActions: [
                DuoBarAction(
                  icon: Icons.keyboard_arrow_up,
                  label: 'Previous',
                  onPressed: () {},
                ),
                DuoBarAction(
                  icon: Icons.keyboard_arrow_down,
                  label: 'Next',
                  onPressed: () {},
                ),
              ],
              bottomActions: mailBottomActions(),
              textActions: [DuoTextAction(label: 'Select', onPressed: () {})],
              body: const SizedBox.expand(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppBar), findsNothing);
        expect(find.text('Select'), findsOneWidget);
        expect(tester.getCenter(find.byTooltip('Back')).dx, greaterThan(600));
        expect(
          find.byTooltip('Compose'),
          findsOneWidget,
        ); // high priority stays
        expect(
          find.byTooltip('Delete'),
          findsNothing,
        ); // low priority goes to overflow first

        await tester.tap(find.byIcon(Icons.more_horiz));
        await tester.pumpAndSettle();
        expect(find.text('Delete'), findsOneWidget);
        expect(find.text('Move'), findsOneWidget);
        expect(find.text('Reply'), findsOneWidget);
      },
    );

    testWidgets('inner display in portrait: horizontal bars', (tester) async {
      setLogicalSize(tester, innerPortrait);
      const environment = DuoEnvironment(
        isAvailable: true,
        divisions: [
          DuoRegion(rect: Rect.fromLTWH(0, foldCenter, 669, 0), active: false),
        ],
      );
      await tester.pumpWidget(
        duoApp(
          environment,
          home: DuoAdaptiveScaffold(
            title: 'Notes',
            topActions: [
              DuoBarAction(icon: Icons.share, label: 'Share', onPressed: () {}),
            ],
            tabs: const [
              DuoTab(icon: Icons.note, label: 'Notes'),
              DuoTab(icon: Icons.folder, label: 'Folders'),
            ],
            body: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('device without a hinge: unchanged (horizontal bars)', (
      tester,
    ) async {
      setLogicalSize(tester, outerLandscape);
      await tester.pumpWidget(
        duoApp(
          DuoEnvironment.unavailable,
          home: DuoAdaptiveScaffold(
            title: 'Inbox',
            topActions: [
              DuoBarAction(
                icon: Icons.search,
                label: 'Search',
                onPressed: () {},
              ),
            ],
            body: const SizedBox.expand(),
          ),
        ),
      );
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets(
      'switching layouts (vertical <-> horizontal bar) keeps content state',
      (tester) async {
        Widget screen(DuoEnvironment environment) => duoApp(
          environment,
          home: DuoAdaptiveScaffold(
            title: 'Lista',
            tabs: const [
              DuoTab(icon: Icons.list, label: 'Listy'),
              DuoTab(icon: Icons.store, label: 'Sklepy'),
            ],
            body: ListView.builder(
              itemCount: 100,
              itemBuilder: (context, index) =>
                  SizedBox(height: 50, child: Text('Wiersz $index')),
            ),
          ),
        );
        final scrollable = find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        );

        setLogicalSize(tester, innerLandscape);
        await tester.pumpWidget(screen(foldEnvironment(active: false)));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsNothing); // vertical bar
        final before = tester.state<ScrollableState>(scrollable);
        before.position.jumpTo(400);
        await tester.pump();

        tester.view.physicalSize = innerPortrait * 3.0;
        await tester.pumpWidget(screen(tabletopEnvironment(active: false)));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget); // horizontal bars
        final after = tester.state<ScrollableState>(scrollable);
        expect(identical(after, before), isTrue);
        expect(after.position.pixels, 400);
      },
    );

    testWidgets(
      'fab only in the horizontal layout; vertically the same action is prominent',
      (tester) async {
        Widget screen(DuoEnvironment environment) => duoApp(
          environment,
          home: DuoAdaptiveScaffold(
            title: 'Zakupy',
            prominentAction: DuoBarAction(
              icon: Icons.add,
              label: 'Add',
              onPressed: () {},
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              tooltip: 'Add',
              child: const Icon(Icons.add),
            ),
            body: const SizedBox.expand(),
          ),
        );

        setLogicalSize(tester, innerPortrait);
        await tester.pumpWidget(screen(tabletopEnvironment(active: false)));
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(
          find.byTooltip('Add'),
          findsOneWidget,
        ); // no duplicate in the AppBar

        tester.view.physicalSize = innerLandscape * 3.0;
        await tester.pumpWidget(screen(foldEnvironment(active: false)));
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(
          find.byTooltip('Add'),
          findsOneWidget,
        ); // the prominent action in the vertical bar
      },
    );
  });
}
