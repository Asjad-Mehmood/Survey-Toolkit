// The first screen: the Toolkit is used with an Excel to KML account. Once signed in, the account
// is remembered on this PC and the Toolkit opens at once, offline too.
import 'package:flutter/material.dart';

import '../account/account.dart';
import '../brand.dart';
import '../ui/settings.dart';
import '../ui/theme.dart';
import 'sign_in_card.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key, required this.account, required this.settings});
  final Account account;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/brand/icon-512.png',
                            width: 52,
                            height: 52,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        appName,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.ink, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, fontSize: 13.5),
                      ),
                      const SizedBox(height: 24),
                      if (account.checking)
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 14),
                              Text('Checking your sign-in…', style: TextStyle(color: c.muted)),
                            ],
                          ),
                        )
                      else
                        SignInCard(
                          account: account,
                          intro:
                              'Sign in with your Excel to KML account, or create one for free. One account works '
                              'on exceltokml.com and in all our programs, and the programs you open from here are '
                              'signed in for you.',
                        ),
                      const SizedBox(height: 18),
                      Text(
                        'Version $appVersion · $appPublisher',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, fontSize: 12, fontFeatures: tabular),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                tooltip: brightness == Brightness.light ? 'Dark mode' : 'Light mode',
                onPressed: () => settings.cycleTheme(brightness),
                icon: Icon(brightness == Brightness.light ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
