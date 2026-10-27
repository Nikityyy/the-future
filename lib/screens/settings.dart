import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../export.dart';
import '../format.dart';
import '../platform/bio.dart';
import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart' show Spinner;
import '../ui/chrome.dart';
import '../ui/lists.dart';
import '../version.dart';
import 'connect.dart';
import 'plan.dart' show Switch2;

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
                      Row2(
                        title: 'Refresh now',
                        subtitle: state.refreshing ? 'Checking for a newer snapshot' : state.checkedAt == null ? 'Looks for a newer snapshot' : 'Checked just now. GitHub updates it about every three hours.',
                        trailing: state.refreshing ? const Spinner() : null,
                        chevron: !state.refreshing,
                        onTap: () {
                          Haptics.selection();
                          state.refresh();
                        },
                      ),
                      Row2(
                        title: 'Disconnect and erase',
                        titleColor: C.loss,
                        onTap: () async {
                          final ok = await confirmSheet(context, title: 'Disconnect?', message: 'This erases your PIN, your plan and the sealed portfolio on this phone. Your GitHub copy keeps syncing.', action: 'Disconnect and erase');
                          if (ok) await state.disconnect();
                        },
                      ),
                    ] else ...[
                      Row2(title: 'Connect your Bitpanda', chevron: true, onTap: () => showPage<void>(context, (_) => ConnectSheet(state))),
                      Row2(title: 'Leave the demo', subtitle: 'Back to the start screen', onTap: state.disconnect),
                    ],
                  ],
                ),
              ),
              if (live)
                SliverToBoxAdapter(
                  child: Group(
                    header: 'SECURITY',
                    children: [
                      if (state.bioSupported)
                        Row2(
                          title: 'Unlock with ${Bio.label.toLowerCase() == 'biometrics' ? 'biometrics' : Bio.label}',
                          subtitle: state.hasBio ? 'On. The PIN still works.' : 'Skips the PIN. Needs iOS 18 or later on iPhone.',
                          trailing: _BioSwitch(state),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lock when away for', style: sans(16, weight: FontWeight.w500)),
                            const SizedBox(height: 10),
                            Segments(
                              labels: const ['Always', '2 min', '15 min', '1 hour'],
                              index: AppState.lockChoices.indexOf(state.lockMinutes).clamp(0, 3),
                              onChanged: (i) => state.setPlan(lockMinutes: AppState.lockChoices[i]),
                            ),
                          ],
                        ),
                      ),
                      Row2(title: 'Lock now', chevron: true, onTap: state.lock),
                    ],
                  ),
                ),
              if (state.snapshot != null)
                SliverToBoxAdapter(
                  child: Group(
                    header: 'YOUR DATA',
                    footer: 'One Markdown file with every holding, every transaction with its date and price, the money you added each month and your plan. Enough on its own for a spreadsheet or an AI to analyse.',
                    children: [
                      Row2(
                        title: 'Export as Markdown',
                        chevron: true,
                        onTap: () {
                          final now = DateTime.now();
                          saveFile('portfolio-${now.toIso8601String().split('T').first}.md', exportMarkdown(state, now));
                        },
                      ),
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
                  footer: 'Made by Nikita Berger. Not affiliated with Bitpanda. Projections are not financial advice.',
                  children: [
                    Row2(title: 'Version', trailing: Text(AppVersion.label, style: figures(sans(15, color: C.ink2)))),
                    Row2(title: 'Source code', subtitle: 'github.com/Nikityyy/the-future', chevron: true, onTap: () => launchUrl(Uri.parse('https://github.com/Nikityyy/the-future'), mode: LaunchMode.externalApplication)),
                  ],
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: Dock.clearance(context) + browserSafeArea().top)),
            ],
          );
        },
      );
}

class _BioSwitch extends StatefulWidget {
  const _BioSwitch(this.state);
  final AppState state;

  @override
  State<_BioSwitch> createState() => _BioSwitchState();
}

class _BioSwitchState extends State<_BioSwitch> {
  String? _error;

  Future<void> _toggle() async {
    if (widget.state.hasBio) return widget.state.disableBio();
    final e = await widget.state.enableBio();
    if (mounted) setState(() => _error = e);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Switch2(on: widget.state.hasBio, onChanged: (_) => _toggle()),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: SizedBox(width: 170, child: Text(_error!, textAlign: TextAlign.right, style: sans(12, color: C.loss)))),
        ],
      );
}
