import 'package:flutter/cupertino.dart';
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
  bool _show = false;
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

  /// Once the keyboard is up, scroll the sheet so the field sits above it.
  void _lift() {
    final c = SheetScroll.of(context);
    if (c == null) return;
    for (final ms in [320, 650]) {
      Future.delayed(Duration(milliseconds: ms), () {
        if (mounted && c.hasClients) c.animateTo(c.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_passphrase != null) {
      return Column(
        children: [
          SizedBox(height: 14 + browserSafeArea().top),
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
    return CustomScrollView(
      controller: SheetScroll.of(context),
      slivers: [
        SliverToBoxAdapter(child: SheetHeaderBar(top: browserSafeArea().top)),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text('STEP 3', style: sans(13, weight: FontWeight.w500, color: C.ink2, tracking: 0.1))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(color: C.raised, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.rule.withValues(alpha: 0.06))),
                  child: Row(
                    children: [
                      Expanded(
                        child: CupertinoTextField(
                          controller: _field,
                          placeholder: 'Your SYNC_PASSPHRASE',
                          placeholderStyle: sans(16, color: C.ink3),
                          style: sans(16),
                          obscureText: !_show,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: null,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          onSubmitted: (_) => _check(),
                          onTap: _lift,
                        ),
                      ),
                      Pressable(
                        onTap: () => setState(() => _show = !_show),
                        child: Padding(padding: const EdgeInsets.only(left: 10), child: Text(_show ? 'Hide' : 'Show', style: sans(14, color: C.ink2))),
                      ),
                    ],
                  ),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 0), child: Text(_error!, style: sans(13.5, color: C.loss, height: 1.4))),
                const SizedBox(height: 18),
                AppButton('Open my portfolio', busy: _busy, onTap: _check),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
        // Room for the keyboard, so the passphrase field can rise above it.
        SliverToBoxAdapter(child: SizedBox(height: 40 + browserSafeArea().bottom + MediaQuery.viewInsetsOf(context).bottom)),
      ],
    );
  }
}

/// A grabber and a close button at the top of a sheet.
class SheetHeaderBar extends StatelessWidget {
  const SheetHeaderBar({super.key, this.top = 0});
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 16 + top, 20, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Pressable(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: C.fill, borderRadius: BorderRadius.circular(20)),
                child: Text('Close', style: sans(15, weight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      );
}
