import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/catalog.dart';
import '../../engine/floor_tree.dart';
import '../../engine/netrun_engine.dart';
import '../../models/architecture.dart';
import '../../models/deck.dart';
import '../../state/app_state.dart';
import '../../state/architectures_state.dart';
import '../../state/deck_state.dart';
import '../../state/run_controller.dart';
import '../../theme/app_theme.dart';
import '../widgets/combat_panel.dart';
import '../widgets/common.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/elevator_display.dart';
import '../widgets/ice_card.dart';
import '../widgets/known_map.dart';
import '../widgets/log_list.dart';
import '../widgets/result_panel.dart';
import 'qr_transfer_screens.dart';

/// Onglet Netrun (joueur ; aussi visible par le MJ avec le bouton « Passer la main »).
class PlayerNetrunScreen extends StatelessWidget {
  const PlayerNetrunScreen({super.key});

  Future<void> _handOver(BuildContext context) async {
    final app = context.read<AppState>();
    final rc = context.read<RunController>();
    if (rc.archi == null) {
      showToast(context, 'Propose d\'abord une architecture au joueur (onglet Architectures).');
      return;
    }
    context.read<ArchitecturesState>().flush();
    final code = await codeDialog(
      context,
      title: 'Passer la main au joueur',
      message:
          'L\'appli passe en mode joueur verrouillé (onglets Netrun et Cyberconsole). '
          'Choisis un code pour revenir en mode MJ, ou laisse vide.',
      confirmLabel: 'Passer la main',
      initial: app.gmPin,
    );
    if (code == null) return;
    app.lock(code);
  }

  Future<void> _backToGm(BuildContext context) async {
    final app = context.read<AppState>();
    if (!app.hasPin) {
      app.unlock('');
      return;
    }
    final code = await codeDialog(
      context,
      title: 'Retour MJ',
      message: 'Saisis le code du MJ.',
      confirmLabel: 'Déverrouiller',
      optional: false,
    );
    if (code == null || !context.mounted) return;
    if (!app.unlock(code)) showToast(context, 'Code incorrect.');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    context.watch<ArchitecturesState>();
    context.watch<DeckState>();
    final rc = context.watch<RunController>();
    final e = rc.engine();
    final children = <Widget>[];

    if (!app.locked) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.lock_outline),
            label: const Text('Passer la main au joueur'),
            onPressed: () => _handOver(context),
          ),
        ),
      );
    }

    if (e == null) {
      children.addAll([
        const ElevatorDisplay(
          code: '--',
          semanticLabel: 'Hors connexion',
          title: 'Aucune architecture',
          subtitle: 'Le MJ n\'a pas encore proposé d\'architecture',
        ),
        const SizedBox(height: 16),
        Text('Le MJ n\'a pas encore proposé d\'architecture.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scanner un QR code'),
          onPressed: () => scanArchitecture(context),
        ),
      ]);
    } else {
      children.addAll(_NetrunBody(engine: e).build(context));
    }

    if (app.locked) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Center(
            child: TextButton(
              onPressed: () => _backToGm(context),
              style: TextButton.styleFrom(foregroundColor: context.colors.muted),
              child: const Text('Retour MJ'),
            ),
          ),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: children);
  }
}

/// Contenu de l'écran pour une architecture proposée.
class _NetrunBody {
  _NetrunBody({required this.engine});
  final NetrunEngine engine;

  List<Widget> build(BuildContext context) {
    final e = engine;
    final s = e.s;
    final a = e.archi;
    final rc = context.read<RunController>();
    void act(bool Function(NetrunEngine) f) => showToast(context, rc.act(f));

    final cur = e.current;
    final String code;
    final String sem;
    if (!s.isOn) {
      code = '--';
      sem = s.isOut ? 'Déconnecté' : 'Pas connecté';
    } else if (cur == null) {
      code = 'AP';
      sem = 'Point d\'accès';
    } else {
      final d = e.tree.depth(cur.id);
      code = two(d);
      sem = 'Étage $d';
    }

    final out = <Widget>[
      ElevatorDisplay(
        code: code,
        semanticLabel: sem,
        title: a.name.trim().isEmpty ? 'Architecture' : a.name,
        subtitle: a.lieu,
        turn: s.isOn ? s.turn : null,
        actions: s.actions,
        spent: s.spent,
        ps: s.ps,
        psMax: e.deck.me.psMax,
        burning: s.burning,
      ),
      const SizedBox(height: 12),
    ];

    if (s.last != null) {
      out.addAll([ResultPanel(result: s.last!), const SizedBox(height: 12)]);
    }

    if (s.isOff) {
      out.add(_connectCard(context, act));
    } else if (s.isOut) {
      out.add(
        _card(
          context,
          title: 'Hors ligne',
          color: context.colors.muted,
          children: [
            const Text('Tu es déconnecté de l\'architecture.'),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => act((e) => e.reconnect()),
              child: const Text('Préparer une nouvelle connexion'),
            ),
          ],
        ),
      );
    } else {
      if (e.enemies().isNotEmpty) {
        out.addAll([
          CombatPanel(engine: e, onZap: (k, p) => act((e) => e.zap(k, p)), onSlide: (k) => act((e) => e.slide(k))),
          const SizedBox(height: 12),
        ]);
      }
      out.add(_currentDoor(context, act));
      out.add(const SectionTitle('Déplacements'));
      out.addAll(_moves(context, act));
      out.add(const SectionTitle('Actions'));
      out.add(_actions(context, act));
    }

    out.add(const SectionTitle('Ma cyberconsole'));
    out.add(s.isOn ? _consoleOnline(context, act) : _consoleOffline(context));
    out.add(const SectionTitle('Architecture connue'));
    out.add(KnownMap(archi: a, run: s));
    out.add(const SectionTitle('Journal'));
    out.add(LogList(entries: s.log));
    return out;
  }

  Widget _card(BuildContext context, {required String title, required Color color, required List<Widget> children}) {
    return AccentCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }

  Widget _connectCard(BuildContext context, void Function(bool Function(NetrunEngine)) act) {
    final hasRank = engine.deck.me.rank != null;
    return _card(
      context,
      title: 'Connexion',
      color: context.colors.net,
      children: [
        Text(
          hasRank
              ? 'Interface ${engine.rank} : ${apt(engine.rank)} action${apt(engine.rank) > 1 ? 's' : ''} virtuelle${apt(engine.rank) > 1 ? 's' : ''} par tour. '
                    'Se connecter coûte 1 action.'
              : 'Indique ton rang d\'Interface dans l\'onglet Cyberconsole avant de te connecter.',
        ),
        const SizedBox(height: 10),
        if (hasRank)
          FilledButton.icon(
            icon: const Icon(Icons.power),
            onPressed: () => act((e) => e.connect()),
            label: const Text('Se connecter (1 action)'),
          )
        else
          FilledButton.tonal(
            onPressed: () => context.read<AppState>().setTab(AppTab.console),
            child: const Text('Ouvrir l\'onglet Cyberconsole'),
          ),
      ],
    );
  }

  Widget _currentDoor(BuildContext context, void Function(bool Function(NetrunEngine)) act) {
    final e = engine;
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final f = e.current;
    if (f == null) {
      return _card(
        context,
        title: 'Point d\'accès',
        color: c.net,
        children: [const Text('La première porte est devant toi.')],
      );
    }
    final children = <Widget>[];
    if (f.label.trim().isNotEmpty) children.add(Text(f.label.trim(), style: t.bodyLarge));
    if (FloorTree.hasTest(f)) {
      final name = e.testNameOf(f);
      if (!e.s.done.contains(f.id)) {
        final bonus = f.kind == FloorKind.mdp ? e.bonus(Bonus.porte) : 0;
        children.addAll([
          const SizedBox(height: 6),
          Text('$name — ${e.sdText(e.sdOf(f))}', style: t.titleMedium),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => act((e) => e.test()),
            child: Text('Tenter : $name${bonus > 0 ? ' (+$bonus)' : ''} (1 action)'),
          ),
        ]);
      } else {
        children.addAll([
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.check_circle, color: c.ok, size: 20),
              const SizedBox(width: 6),
              Text(
                f.kind == FloorKind.mdp ? 'Mot de passe contourné' : 'Test réussi',
                style: t.titleSmall!.copyWith(color: c.ok),
              ),
            ],
          ),
          if (f.info.trim().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.netPale, borderRadius: BorderRadius.circular(10)),
              child: Text(f.info.trim(), style: t.bodyLarge),
            ),
        ]);
      }
    }
    if (f.kind == FloorKind.glace) {
      for (var i = 0; i < f.ice.length; i++) {
        final def = iceByName[f.ice[i]];
        if (def == null) continue;
        final st = e.iceState(f.id, i);
        children.addAll([
          const SizedBox(height: 8),
          IceCard(
            ice: def,
            state: st.down ? 'Dérezzé' : (st.chasing ? 'En chasse' : 'En attente'),
            rez: st.rez,
            note: st.chasing ? 'Il te poursuit : vois le Combat.' : null,
          ),
        ]);
      }
    }
    if (f.kind == FloorKind.demon) {
      final def = demonByName[f.demon];
      if (def != null) {
        final st = e.demonState(f.id);
        children.addAll([
          const SizedBox(height: 8),
          IceCard(
            demon: def,
            state: st.down ? 'Dérezzé' : (st.active ? 'Actif' : 'En attente'),
            rez: st.rez,
            note: st.active ? 'Il t\'a repéré : vois le Combat.' : null,
          ),
        ]);
      }
    }
    if (e.atVirusSpot()) {
      children.addAll([
        const SizedBox(height: 10),
        Text('Fond de l\'architecture : Virus — ${e.sdText(e.archi.virusSD!)}', style: t.titleSmall),
        if (e.s.virus != null)
          Text('Ton Virus est en place (SD ${e.s.virus} pour le détruire).', style: t.bodyMedium)
        else ...[
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: () => act((e) => e.virus()), child: const Text('Larguer un Virus (1 action)')),
        ],
      ]);
    }
    if (children.isEmpty) children.add(const Text('La porte s\'ouvre.'));
    return _card(context, title: kindName(f.kind), color: c.floorColor(f.kind), children: children);
  }

  List<Widget> _moves(BuildContext context, void Function(bool Function(NetrunEngine)) act) {
    final e = engine;
    final c = context.colors;
    final kids = e.tree.kids(e.s.pos);
    final block = e.descendBlock();
    final out = <Widget>[];
    if (kids.isEmpty) {
      out.add(
        Text(
          e.current == null ? 'Aucune porte.' : 'Aucune porte vers le bas.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    for (var i = 0; i < kids.length; i++) {
      final k = kids[i];
      final d = e.tree.depth(k.id);
      final known = e.s.seen.contains(k.id) || e.s.carto.contains(k.id);
      final prefix = kids.length == 1
          ? 'Descendre vers l\'étage $d'
          : (i == 0 ? 'Branche principale vers l\'étage $d' : 'Embranchement $i vers l\'étage $d');
      final summary = !known ? '' : ' (${e.s.seen.contains(k.id) ? floorSummary(k) : kindName(k.kind)})';
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.south),
            style: FilledButton.styleFrom(alignment: Alignment.centerLeft),
            onPressed: block == null ? () => act((e) => e.move(k.id)) : null,
            label: Text('$prefix$summary'),
          ),
        ),
      );
    }
    if (block != null && kids.isNotEmpty) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: c.warn),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  block,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: c.warn, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (e.current != null) {
      final up = e.tree.parent(e.current!.id);
      out.add(
        OutlinedButton.icon(
          icon: const Icon(Icons.north),
          style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft),
          onPressed: () => act((e) => e.move(up?.id)),
          label: Text(up == null ? 'Remonter au point d\'accès' : 'Remonter à l\'étage ${e.tree.depth(up.id)}'),
        ),
      );
    }
    return out;
  }

  Widget _actions(BuildContext context, void Function(bool Function(NetrunEngine)) act) {
    final e = engine;
    final s = e.s;
    final carto = e.bonus(Bonus.cartographie);
    final masq = e.bonus(Bonus.masquage);
    final pursued = e.enemies().isNotEmpty || s.burning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => act((e) => e.carto()),
              child: Text('Cartographie${carto > 0 ? ' (+$carto)' : ''}'),
            ),
            OutlinedButton(
              onPressed: () => act((e) => e.masq()),
              child: Text('Masquage${masq > 0 ? ' (+$masq)' : ''}'),
            ),
            OutlinedButton(onPressed: () => act((e) => e.jackout()), child: const Text('Se déconnecter')),
            if (s.burning)
              OutlinedButton.icon(
                icon: const Icon(Icons.local_fire_department),
                style: OutlinedButton.styleFrom(foregroundColor: context.colors.warn),
                onPressed: () => act((e) => e.extinguish()),
                label: const Text('Éteindre les flammes'),
              ),
          ],
        ),
        if (s.masq != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Masquage en place : ${s.masq}.', style: Theme.of(context).textTheme.bodySmall),
          ),
        const SizedBox(height: 10),
        FilledButton.icon(
          icon: const Icon(Icons.skip_next),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => act((e) => e.endTurn()),
          label: Text(pursued ? 'Fin du tour : les adversaires attaquent' : 'Fin du tour'),
        ),
      ],
    );
  }

  Widget _consoleOnline(BuildContext context, void Function(bool Function(NetrunEngine)) act) {
    final e = engine;
    final d = e.deck;
    final t = Theme.of(context).textTheme;
    final bonuses = e.activeBonusLabels();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${d.type} · ${d.used}/${d.total} emplacements', style: t.titleSmall),
        Text('Bonus actifs : ${bonuses.isEmpty ? 'aucun' : bonuses.join(', ')}', style: t.bodyMedium),
        const SizedBox(height: 8),
        if (d.items.isEmpty) Text('Console vide.', style: t.bodySmall),
        for (final item in d.items) ...[_OnlineItem(engine: e, item: item, act: act), const SizedBox(height: 6)],
        if (d.saved.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Sur le disque dur : ${d.saved.map((i) => i.n).join(', ')}', style: t.bodyMedium),
          const SizedBox(height: 6),
          OutlinedButton(onPressed: () => act((e) => e.restore()), child: const Text('Réinstaller (action réelle)')),
        ],
      ],
    );
  }

  Widget _consoleOffline(BuildContext context) {
    final d = engine.deck;
    final t = Theme.of(context).textTheme;
    return _card(
      context,
      title: '${d.type} · ${d.used}/${d.total} emplacements',
      color: context.colors.net,
      children: [
        Text(d.items.isEmpty ? 'Console vide.' : d.items.map((i) => i.n).join(', '), style: t.bodyMedium),
        Text(d.me.rank == null ? 'Rang d\'Interface non renseigné.' : 'Interface ${d.me.rank}', style: t.bodyMedium),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.read<AppState>().setTab(AppTab.console),
          child: const Text('Configurer la console'),
        ),
      ],
    );
  }
}

class _OnlineItem extends StatelessWidget {
  const _OnlineItem({required this.engine, required this.item, required this.act});
  final NetrunEngine engine;
  final DeckItem item;
  final void Function(bool Function(NetrunEngine)) act;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Theme.of(context).textTheme;
    final on = engine.isOn(item);
    final st = engine.s.prog[item.id];
    final prog = item.prog;
    final ice = item.ice;
    final offensive = prog?.type == ProgType.offensif;
    final stats = <String>[];
    if (prog != null && prog.type != ProgType.offensif) stats.add('REZ ${st?.rez ?? prog.rez}/${prog.rez}');
    if (prog != null && offensive) {
      stats.add('ATT ${prog.att}${prog.iceDmg != null ? ', ${prog.iceDmg} aux GLACE' : ''}');
    }
    if (ice != null) stats.add('ATT ${ice.att} · DÉF ${ice.def} · REZ ${st?.rez ?? ice.rez}/${ice.rez}');
    if (item.isHw) stats.add(item.hw?.effect ?? '');
    Widget? button;
    if (!item.isHw && !offensive) {
      final usedUp = prog != null && prog.once && (st?.used ?? false) && !on;
      if (on) {
        button = OutlinedButton(onPressed: () => act((e) => e.derez(item.id)), child: const Text('Dérezzer'));
      } else if (usedUp) {
        button = const OutlinedButton(onPressed: null, child: Text('Utilisé'));
      } else {
        button = FilledButton.tonal(onPressed: () => act((e) => e.rez(item.id)), child: const Text('Rezzer'));
      }
    }
    return AccentCard(
      color: itemColor(c, item),
      background: on ? c.netPale : null,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(item.n, style: t.titleSmall),
                    Tag(item.typeLabel, color: itemColor(c, item)),
                    if (on) Tag('rezzé', color: c.net, filled: true),
                  ],
                ),
                if (stats.isNotEmpty) Text(stats.join(' · '), style: t.bodySmall),
                if (offensive) Text('S\'utilise dans le Combat.', style: t.bodySmall),
              ],
            ),
          ),
          ?button,
        ],
      ),
    );
  }
}
