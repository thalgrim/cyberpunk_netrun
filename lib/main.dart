import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'state/app_state.dart';
import 'state/architectures_state.dart';
import 'state/deck_state.dart';
import 'state/run_controller.dart';
import 'storage/repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final repo = await Repository.open();
  final app = AppState(repo);
  final archis = ArchitecturesState(repo);
  final deck = DeckState(repo);
  final run = RunController(repo: repo, app: app, archis: archis, decks: deck);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app),
        ChangeNotifierProvider.value(value: archis),
        ChangeNotifierProvider.value(value: deck),
        ChangeNotifierProvider.value(value: run),
      ],
      child: const NetrunApp(),
    ),
  );
}
