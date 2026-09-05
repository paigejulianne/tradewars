import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

import '../theme.dart';

class DocEntry {
  final String title;
  final String asset;
  final IconData icon;
  const DocEntry(this.title, this.asset, this.icon);
}

const List<DocEntry> kDocs = [
  DocEntry('Getting Started', 'assets/docs/01_getting_started.md', Icons.rocket_launch),
  DocEntry('Trading & the Economy', 'assets/docs/02_trading.md', Icons.storefront),
  DocEntry('Combat & Mines', 'assets/docs/03_combat.md', Icons.gps_fixed),
  DocEntry('Planets & Colonization', 'assets/docs/04_planets.md', Icons.public),
  DocEntry('Corporations', 'assets/docs/05_corporations.md', Icons.groups),
  DocEntry('Random Events', 'assets/docs/06_events.md', Icons.bolt),
  DocEntry('Ships & the Shipyard', 'assets/docs/07_ships.md', Icons.rocket),
  DocEntry('Frequently Asked Questions', 'assets/docs/08_faq.md', Icons.help_outline),
];

/// Standalone manual page with its own AppBar — used when reached outside
/// the authenticated game shell (e.g. the "Read the manual" link on the
/// login screen). Inside the shell, use [DocsBody] instead so it doesn't
/// nest a second AppBar under the shell's HUD.
///
/// Docs are bundled as Flutter assets (not fetched over the network), so the
/// manual is fully readable offline — including when the PWA has no
/// connection to the backend at all.
class DocsScreen extends StatelessWidget {
  const DocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual & Documentation')),
      body: const DocsBody(),
    );
  }
}

/// The manual's content only, with no Scaffold/AppBar of its own — safe to
/// embed as a tab body inside another Scaffold (the game shell).
class DocsBody extends StatefulWidget {
  const DocsBody({super.key});

  @override
  State<DocsBody> createState() => _DocsBodyState();
}

class _DocsBodyState extends State<DocsBody> {
  DocEntry _selected = kDocs.first;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 700;

    if (!wide) {
      return ListView(
        children: [for (final d in kDocs) _tile(context, d, wide: false)],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 280,
          child: ListView(
            children: [for (final d in kDocs) _tile(context, d, wide: true)],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: DocViewer(doc: _selected)),
      ],
    );
  }

  Widget _tile(BuildContext context, DocEntry d, {required bool wide}) {
    final selected = wide && d.asset == _selected.asset;
    return ListTile(
      selected: selected,
      selectedTileColor: TWColors.panelAlt,
      leading: Icon(d.icon, color: TWColors.accent),
      title: Text(d.title),
      onTap: () {
        if (wide) {
          setState(() => _selected = d);
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocPage(doc: d)));
        }
      },
    );
  }
}

class DocPage extends StatelessWidget {
  final DocEntry doc;
  const DocPage({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: DocViewer(doc: doc),
    );
  }
}

class DocViewer extends StatelessWidget {
  final DocEntry doc;
  const DocViewer({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      key: ValueKey(doc.asset),
      future: rootBundle.loadString(doc.asset),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: MarkdownBody(
            data: snap.data!,
            styleSheet: MarkdownStyleSheet(
              h1: const TextStyle(color: TWColors.accent, fontWeight: FontWeight.bold, fontSize: 26),
              h2: const TextStyle(color: TWColors.accent2, fontWeight: FontWeight.bold, fontSize: 20),
              h3: const TextStyle(color: TWColors.text, fontWeight: FontWeight.bold, fontSize: 16),
              p: const TextStyle(color: TWColors.text, fontSize: 14, height: 1.5),
              listBullet: const TextStyle(color: TWColors.text),
              code: const TextStyle(backgroundColor: TWColors.panelAlt, color: TWColors.accent),
              blockquoteDecoration: const BoxDecoration(
                color: TWColors.panelAlt,
                border: Border(left: BorderSide(color: TWColors.accent, width: 3)),
              ),
            ),
          ),
        );
      },
    );
  }
}
