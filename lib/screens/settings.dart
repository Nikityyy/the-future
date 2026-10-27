import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../platform/web_glue.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/chrome.dart';
import '../ui/lists.dart';
import '../version.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage(this.state, {super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final live = state.mode == Mode.live;
          return CustomScrollView(
            slivers: [
              const LargeTitle('You'),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              SliverToBoxAdapter(
                child: Group(
                  header: 'BITPANDA',
                  footer: live
                      ? 'GitHub reads your portfolio about every three hours with a read-only key and publishes it sealed. Only your passphrase opens it.'
                      : 'You are looking at made-up numbers. Connect to see your own.',
                  children: [
                    if (live) ...[
                      Row2(title: 'Connected', subtitle: state.snapshot == null ? null : 'Updated ${ago(state.snapshot!.generatedAt)}'),
                      Row2(title: 'Refresh now', chevron: true, onTap: state.refresh),
                      Row2(title: 'Lock now', chevron: true, onTap: state.lock),
                      Row2(title: 'Disconnect and erase', titleColor: C.loss, onTap: () => state.disconnect()),
                    ] else ...[
                      Row2(title: 'Leave the demo', subtitle: 'Back to the start, to connect Bitpanda', chevron: true, onTap: state.disconnect),
                    ],
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Group(
                  header: 'PRIVACY',
                  children: const [
                    Row2(title: 'No account, no tracking', subtitle: 'This app talks to no server but its own page. Plan and portfolio stay in this browser.'),
                    Row2(title: 'Your key stays on GitHub', subtitle: 'The read-only Bitpanda key sits in a GitHub secret and never reaches this phone.'),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Group(
                  header: 'ABOUT',
                  children: [
                    Row2(title: 'Version', trailing: Text(AppVersion.label, style: figures(sans(15, color: C.ink2)))),
                    Row2(title: 'Source code', subtitle: 'github.com/Nikityyy/the-future', chevron: true, onTap: () => launchUrl(Uri.parse('https://github.com/Nikityyy/the-future'), mode: LaunchMode.externalApplication)),
                  ],
                  footer: 'Made by Nikita Berger. Not affiliated with Bitpanda. Projections are not financial advice.',
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: Dock.clearance(context) + browserSafeArea().top)),
            ],
          );
        },
      );
}
