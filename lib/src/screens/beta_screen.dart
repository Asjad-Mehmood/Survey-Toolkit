// Signed in, but the website hasn't (yet) said this account may use the Toolkit: while it is open to
// everyone that is only the first check, or no connection; when an admin closes it, the reason.
import 'package:flutter/material.dart';

import '../account/account.dart';
import '../brand.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class BetaScreen extends StatelessWidget {
  const BetaScreen({super.key, required this.account});
  final Account account;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final waiting = account.beta == BetaAccess.unknown && !account.offline;
    final text = switch (account.beta) {
      BetaAccess.closed =>
        account.closedMessage ?? 'The $appName isn\'t open to this account just now. Please try again later.',
      _ when account.offline =>
        'No connection to exceltokml.com, so your account can\'t be checked. Connect and press Check again.',
      _ => 'Checking your account…',
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SectionCard(
                title: appName,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Signed in as ${account.user?.display ?? ''}', style: TextStyle(color: c.muted)),
                    const SizedBox(height: 14),
                    if (waiting)
                      const Center(
                        child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
                      )
                    else
                      Notice(text, kind: account.beta == BetaAccess.closed ? NoticeKind.warning : NoticeKind.problem),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton(onPressed: account.signOut, child: const Text('Sign out')),
                        FilledButton(onPressed: waiting ? null : account.checkBeta, child: const Text('Check again')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
