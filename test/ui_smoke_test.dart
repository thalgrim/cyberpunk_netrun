import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cyberpunk_netrun/app.dart';
import 'package:cyberpunk_netrun/engine/dice.dart';
import 'package:cyberpunk_netrun/models/architecture.dart';
import 'package:cyberpunk_netrun/state/app_state.dart';
import 'package:cyberpunk_netrun/state/architectures_state.dart';
import 'package:cyberpunk_netrun/state/deck_state.dart';
import 'package:cyberpunk_netrun/state/run_controller.dart';
import 'package:cyberpunk_netrun/storage/repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test de fumée de l'interface : chaque écran s'affiche sans erreur ni débordement
/// sur un petit téléphone (360 dp), en thème clair et sombre.
/// Avec la variable d'environnement NETRUN_SHOTS (un dossier), enregistre des captures PNG.
void main() {
  final shots = Platform.environment['NETRUN_SHOTS'];
  final shotKey = GlobalKey();

  // Vraies polices (sinon la police de test, plus large, fausse la mise en page).
  setUpAll(() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
      }
      await loader.load();
    }

    await load('ChakraPetch', ['assets/fonts/ChakraPetch-SemiBold.ttf', 'assets/fonts/ChakraPetch-Bold.ttf']);
    await load('Barlow', [
      'assets/fonts/Barlow-Regular.ttf',
      'assets/fonts/Barlow-Medium.ttf',
      'assets/fonts/Barlow-SemiBold.ttf',
    ]);
    final icons = Platform.environment['MATERIAL_ICONS'];
    if (icons != null) await load('MaterialIcons', [icons]);
  });

  Future<({AppState app, ArchitecturesState archis, DeckState deck, RunController run})> setup() async {
    SharedPreferences.setMockInitialValues({});
    final repo = await Repository.open();
    final app = AppState(repo);
    final archis = ArchitecturesState(repo, dice: Dice(Random(5)));
    final deck = DeckState(repo);
    final run = RunController(repo: repo, app: app, archis: archis, decks: deck, dice: Dice(Random(2)));
    return (app: app, archis: archis, deck: deck, run: run);
  }

  Future<void> pump(WidgetTester tester, dynamic s, {required bool dark, double height = 800}) async {
    tester.view.physicalSize = Size(360 * 3, height * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = dark ? Brightness.dark : Brightness.light;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: shotKey,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: s.app),
            ChangeNotifierProvider<ArchitecturesState>.value(value: s.archis),
            ChangeNotifierProvider<DeckState>.value(value: s.deck),
            ChangeNotifierProvider<RunController>.value(value: s.run),
          ],
          child: const NetrunApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (shots == null) return;
    final render = tester.renderObject<RenderRepaintBoundary>(find.byKey(shotKey));
    final ui.Image image = (await tester.runAsync(() => render.toImage(pixelRatio: 1.5)))!;
    final bytes = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png));
    Directory(shots).createSync(recursive: true);
    File('$shots/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'sombre' : 'clair';

    testWidgets('MJ : architectures et éditeur ($theme)', (tester) async {
      final s = await setup();
      final a = s.archis.create(generated: true);
      a.lieu = 'Tour Arasaka, Night City';
      await pump(tester, s, dark: dark, height: 1600);
      expect(find.text('Générer au dé'), findsOneWidget);
      await shot(tester, 'architectures_$theme');
      // Dépliage du premier étage.
      await tester.tap(find.text('É.01').first);
      await tester.pumpAndSettle();
      expect(find.text('Insérer au-dessus'), findsOneWidget);
      await shot(tester, 'editeur_$theme');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Joueur : Netrun en combat ($theme)', (tester) async {
      final s = await setup();
      final a = Architecture(
        id: 'A',
        name: 'Biotechnica — labo 3',
        lieu: 'Watson, Night City',
        floors: [
          Floor(id: 'f1', kind: FloorKind.mdp, sd: 6, label: 'Accès au hall', info: 'Code du hall : 4471.'),
          Floor(id: 'f2', parent: 'f1', kind: FloorKind.glace, ice: ['Cerbère', 'Tueur']),
          Floor(id: 'f3', parent: 'f2', kind: FloorKind.fichier, label: 'Registre des livraisons'),
          Floor(id: 'b1', parent: 'f2', ord: 1, kind: FloorKind.noeud, label: 'Caméras'),
        ],
      );
      s.archis.add(a);
      s.app.propose('A');
      s.deck.deck.me
        ..rank = 6
        ..psMax = 40;
      s.deck.install('prog', 'Ver');
      s.deck.install('prog', 'Armure');
      s.deck.install('prog', 'Sabre');
      s.deck.install('hw', 'Disque dur de sauvegarde');
      s.app.lock('1234');
      s.run.act((e) => e.connect());
      s.run.act((e) => e.move('f1'));
      s.run.run!.done.add('f1');
      s.run.act((e) => e.rez(s.deck.deck.items.first.id));
      s.run.act((e) => e.move('f2'));
      await pump(tester, s, dark: dark, height: 3200);
      expect(find.text('Netrun'), findsWidgets);
      expect(find.text('Architectures'), findsNothing);
      await shot(tester, 'netrun_$theme');
      await tester.scrollUntilVisible(find.text('Retour MJ'), 400);
      await shot(tester, 'netrun_bas_$theme');
      await tester.tap(find.text('Cyberconsole'));
      await tester.pumpAndSettle();
      await shot(tester, 'console_$theme');
      expect(tester.takeException(), isNull);
    });

    testWidgets('MJ : suivi et Netrun hors connexion ($theme)', (tester) async {
      final s = await setup();
      final a = s.archis.create(generated: true);
      s.app.propose(a.id);
      await pump(tester, s, dark: dark, height: 1600);
      await tester.tap(find.text('Netrun'));
      await tester.pumpAndSettle();
      expect(find.text('Passer la main au joueur'), findsOneWidget);
      await shot(tester, 'netrun_off_$theme');
      await tester.tap(find.text('Suivi'));
      await tester.pumpAndSettle();
      expect(find.text('Réinitialiser la run'), findsOneWidget);
      await shot(tester, 'suivi_$theme');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Passer la main puis revenir en MJ avec le code', (tester) async {
    final s = await setup();
    final a = s.archis.create(generated: true);
    s.app.propose(a.id);
    s.app.setTab(AppTab.netrun);
    await pump(tester, s, dark: false);
    await tester.tap(find.text('Passer la main au joueur'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Passer la main'));
    await tester.pumpAndSettle();
    expect(s.app.locked, isTrue);
    expect(find.text('Architectures'), findsNothing);
    await tester.scrollUntilVisible(find.text('Retour MJ'), 400);
    await tester.tap(find.text('Retour MJ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '41');
    await tester.tap(find.text('Déverrouiller'));
    await tester.pumpAndSettle();
    expect(s.app.locked, isTrue);
    expect(find.text('Code incorrect.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retour MJ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '42');
    await tester.tap(find.text('Déverrouiller'));
    await tester.pumpAndSettle();
    expect(s.app.locked, isFalse);
    expect(find.text('Architectures'), findsOneWidget);
  });
}
