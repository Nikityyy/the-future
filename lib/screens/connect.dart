import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:url_launcher/url_launcher.dart';

import '../platform/haptics.dart';
import '../platform/web_glue.dart';
import '../state.dart';
import '../theme.dart';
import '../ui/basics.dart';
import '../ui/chrome.dart';
import '../ui/lists.dart';
import '../vault.dart';
import 'lock.dart';

const _repo = 'https://github.com/Nikityyy/the-future';

Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Three steps: a read-only key, two GitHub secrets, then the passphrase here.
class ConnectSheet extends StatefulWidget {
  const ConnectSheet(this.state, {super.key});

  final AppState state;

  @override
  State<ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends State<ConnectSheet> {
  final _field = TextEditingController();
  bool _busy = false;
  bool _entering = false;
  String? _error;
  String? _passphrase;
  String? _firstPin;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final p = _field.text;
    if (p.length < 12) {
      setState(() => _error = 'The passphrase has at least 12 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.state.checkPassphrase(p);
      if (mounted) setState(() => _passphrase = p);
    } on SnapshotMissing {
      _error = 'No snapshot is published yet. Run the workflow in step 2 once, wait for it to finish, then try again.';
    } on WrongSecret {
      _error = 'That passphrase does not open the snapshot. It has to be the same as SYNC_PASSPHRASE.';
    } catch (_) {
      _error = 'Could not reach the site. Check your connection.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<bool> _pin(String pin) async {
    if (_firstPin == null) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      setState(() => _firstPin = pin);
      return true;
    }
    if (_firstPin != pin) {
      setState(() => _firstPin = null);
      return false;
    }
    await widget.state.connect(_passphrase!, pin);
    Haptics.confirm();
    if (mounted) Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    return true;
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final t = data?.text?.trim();
    if (t == null || t.isEmpty) return;
    Haptics.selection();
    setState(() {
      _field.text = t;
      _error = null;
    });
  }

  /// The passphrase on a page of its own: the field sits at the top, well above the keyboard.
  Widget _entry() => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: BackBar(onBack: () => setState(() => _entering = false))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your passphrase', style: serif(40)),
                  const SizedBox(height: 10),
                  Text('The SYNC_PASSPHRASE you saved as a GitHub secret. It opens your sealed portfolio on this phone.', style: sans(15, color: C.ink2, height: 1.45)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: GlassPasswordField(
                          controller: _field,
                          autofocus: true,
                          placeholder: 'Passphrase',
                          placeholderStyle: sans(16, color: C.ink3),
                          textStyle: sans(16),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          shape: const LiquidRoundedSuperellipse(borderRadius: 22),
                          onSubmitted: (_) => _check(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      PillButton('Paste', onTap: _paste),
                    ],
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 0), child: Text(_error!, style: sans(13.5, color: C.loss, height: 1.4))),
                  const SizedBox(height: 18),
                  AppButton('Open my portfolio', busy: _busy, onTap: _check),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 40 + MediaQuery.viewInsetsOf(context).bottom)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (_passphrase != null) {
      return Column(
        children: [
          BackBar(onBack: () => setState(() {
            _passphrase = null;
            _firstPin = null;
          })),
          Expanded(
            child: PinPad(
              key: ValueKey(_firstPin == null),
              title: _firstPin == null ? 'Choose a PIN' : 'Once more',
              subtitle: _firstPin == null ? 'Six digits. It locks this phone; your passphrase stays sealed under it.' : 'Enter the same PIN again.',
              onDone: _pin,
            ),
          ),
        ],
      );
    }
    if (_entering) return _entry();
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: BackBar()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlurText('Connect Bitpanda', style: serif(40)),
                const SizedBox(height: 10),
                Text('GitHub reads your portfolio for you, seals it, and publishes only the sealed file. Your key never touches this phone.', style: sans(15, color: C.ink2, height: 1.45)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Group(
            header: 'STEP 1',
            footer: 'Give the key the Read scope only. Without Trade it cannot buy, sell or withdraw anything.',
            children: [
              Row2(title: 'Create a read-only API key', subtitle: 'In Bitpanda: Account, API keys', chevron: true, onTap: () => _open('https://app.bitpanda.com/my-account/apikey')),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Group(
            header: 'STEP 2',
            footer: 'Add two repository secrets: BITPANDA_API_KEY (the key) and SYNC_PASSPHRASE (a long passphrase of your own, 12 characters or more, such as four random words). Then run the workflow once.',
            children: [
              Row2(title: 'Open your repository secrets', subtitle: 'Settings, Secrets and variables, Actions', chevron: true, onTap: () => _open('$_repo/settings/secrets/actions')),
              Row2(title: 'Run the workflow', subtitle: 'Actions, Test and deploy, Run workflow', chevron: true, onTap: () => _open('$_repo/actions/workflows/pages.yml')),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              children: [
                AppButton('Continue', onTap: () => setState(() => _entering = true)),
                const SizedBox(height: 10),
                Text('Done steps 1 and 2? Next you enter your passphrase.', style: sans(13, color: C.ink2), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 40 + browserSafeArea().bottom)),
      ],
    );
  }
}
