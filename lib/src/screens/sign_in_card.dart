// Sign in, create an account, or sign in through the browser: the same account as exceltokml.com.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/account.dart';
import '../account/api.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Sign in, create an account, or sign in through the browser.
class SignInCard extends StatefulWidget {
  const SignInCard({super.key, required this.account, this.intro});
  final Account account;

  /// The line above the form
  final String? intro;

  @override
  State<SignInCard> createState() => _SignInCardState();
}

enum _Step { signIn, register, code, browser }

class _SignInCardState extends State<SignInCard> {
  _Step _step = _Step.signIn;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _company = TextEditingController();
  final _code = TextEditingController();
  EmailCode? _challenge;
  BrowserSignIn? _browser;
  Timer? _poll;
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in [_name, _email, _password, _company, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await work();
    } on ApiError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _needCode(EmailCode? c) {
    if (c == null) return;
    _challenge = c;
    _code.clear();
    setState(() => _step = _Step.code);
  }

  Future<void> _startBrowser() => _run(() async {
    final s = await widget.account.startBrowserSignIn();
    setState(() {
      _browser = s;
      _step = _Step.browser;
    });
    await launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication);
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        if (await widget.account.checkBrowserSignIn(s)) _poll?.cancel();
      } on ApiError catch (e) {
        _poll?.cancel();
        if (mounted) setState(() => _error = e.message);
      }
    });
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = widget.account;
    Widget field(TextEditingController ctl, String label, {bool secret = false, TextInputType? type, String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          // its own node, so a screen reader names it by its label alone, not with the card's text
          child: Semantics(
            container: true,
            child: TextField(
              controller: ctl,
              obscureText: secret,
              keyboardType: type,
              autocorrect: false,
              enableSuggestions: !secret,
              decoration: InputDecoration(labelText: label, hintText: hint),
            ),
          ),
        );

    final body = switch (_step) {
      _Step.signIn || _Step.register => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Step>(
            segments: const [
              ButtonSegment(value: _Step.signIn, label: Text('Sign in')),
              ButtonSegment(value: _Step.register, label: Text('Create an account')),
            ],
            selected: {_step},
            onSelectionChanged: (v) => setState(() {
              _step = v.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 16),
          if (_step == _Step.register) field(_name, 'Your name'),
          field(_email, 'Email', type: TextInputType.emailAddress, hint: 'name@company.com'),
          field(_password, 'Password', secret: true, hint: _step == _Step.register ? 'At least 8 characters' : null),
          if (_step == _Step.register) field(_company, 'Company (optional)'),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    final code = _step == _Step.signIn
                        ? await a.signIn(_email.text, _password.text)
                        : await a.register(
                            name: _name.text,
                            email: _email.text,
                            password: _password.text,
                            company: _company.text,
                          );
                    _needCode(code);
                  }),
            child: Text(_step == _Step.signIn ? 'Sign in' : 'Create the account'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _startBrowser,
            icon: const Icon(Icons.open_in_browser_rounded),
            label: const Text('Sign in with the browser (Google)'),
          ),
          if (_step == _Step.signIn)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        if (_email.text.trim().isEmpty) throw ApiError('Type your email first.');
                        await a.forgotPassword(_email.text);
                        setState(
                          () => _info = 'If that email has an account, a link to set a new password is on its way.',
                        );
                      }),
                child: const Text('Forgot the password?'),
              ),
            ),
        ],
      ),
      _Step.code => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'We sent a 6-digit code to ${_challenge?.sentTo}. Type it here to confirm your email. '
            'Not there? Look in Spam.',
            style: TextStyle(color: c.ink, height: 1.45),
          ),
          const SizedBox(height: 14),
          field(_code, 'Code', type: TextInputType.number, hint: '123456'),
          FilledButton(
            onPressed: _busy ? null : () => _run(() => a.confirmEmail(_challenge!, _code.text)),
            child: const Text('Confirm'),
          ),
          Row(
            children: [
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        _challenge = await a.resendCode(_challenge!);
                        setState(() => _info = 'A new code is on its way to ${_challenge!.sentTo}.');
                      }),
                child: const Text('Send a new code'),
              ),
              TextButton(onPressed: () => setState(() => _step = _Step.signIn), child: const Text('Back')),
            ],
          ),
        ],
      ),
      _Step.browser => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your browser is open at exceltokml.com. Sign in there (Google works), then confirm this code:',
            style: TextStyle(color: c.ink, height: 1.45),
          ),
          const SizedBox(height: 14),
          Center(
            child: SelectableText(
              _browser?.code ?? '',
              style: TextStyle(
                fontFamily: readingFont,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
                color: c.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
          const SizedBox(height: 8),
          Center(
            child: Text('Waiting for the browser…', style: TextStyle(color: c.muted)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _browser == null
                    ? null
                    : () => launchUrl(Uri.parse(_browser!.url), mode: LaunchMode.externalApplication),
                child: const Text('Open the browser again'),
              ),
              TextButton(
                onPressed: () {
                  _poll?.cancel();
                  setState(() => _step = _Step.signIn);
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SectionCard(
        title: 'Your Excel to KML account',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.intro ?? 'Sign in with your Excel to KML account.',
              style: TextStyle(color: c.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            body,
            if (_error != null) ...[const SizedBox(height: 12), Notice(_error!, kind: NoticeKind.problem)],
            if (_info != null) ...[const SizedBox(height: 12), Notice(_info!, kind: NoticeKind.success)],
          ],
        ),
      ),
    );
  }
}
