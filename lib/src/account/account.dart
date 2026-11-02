// The Excel to KML account in the Toolkit: the same sign-in as exceltokml.com, Slope Calculator
// and Traverse & Level. Sign in or create an account (with the 6-digit code the website emails),
// or sign in through the browser (Google and saved passwords work there). The session is
// remembered on this PC, so the Toolkit opens at once next time, offline too.
//
// The Toolkit is a beta test: after sign-in it asks the website whether this account is on the
// beta list (/api/toolkit/me). The answer is remembered for offline use.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/store.dart';
import 'api.dart';

class AccountUser {
  const AccountUser({required this.id, required this.email, required this.name});
  final String id;
  final String email;
  final String name;

  static AccountUser? from(Object? j) {
    if (j is! Map<String, Object?>) return null;
    final id = j['id'], email = j['email'];
    if (id is! String || email is! String) return null;
    return AccountUser(id: id, email: email.toLowerCase(), name: (j['name'] as String?) ?? '');
  }

  Map<String, Object?> toJson() => {'id': id, 'email': email, 'name': name};
  String get display => name.isNotEmpty ? name : email;
}

/// The website wants the emailed code before the account can be used
class EmailCode {
  const EmailCode(this.challenge, this.sentTo);
  final String challenge;
  final String sentTo;
}

/// A browser sign-in in progress: the code to confirm at [url]
class BrowserSignIn {
  const BrowserSignIn({required this.code, required this.url, required this.poll});
  final String code;
  final String url;
  final String poll;
}

/// May this account use the beta? Unknown until the website has answered once.
enum BetaAccess { unknown, tester, closed }

class Account extends ChangeNotifier {
  Account(this.api, this._store) {
    final j = _store.readJson(_key);
    api.token = j?['token'] as String?;
    _user = AccountUser.from(j?['user']);
    _beta = BetaAccess.values.asNameMap()[j?['beta']] ?? BetaAccess.unknown;
    checking = _user == null && api.token != null;
  }

  final Api api;
  final Store _store;
  static const _key = 'account';

  /// Still asking the website whether the remembered sign-in is good (nobody remembered here)
  bool checking = false;

  AccountUser? _user;
  AccountUser? get user => _user;
  bool get signedIn => _user != null;

  BetaAccess _beta = BetaAccess.unknown;
  BetaAccess get beta => _beta;

  /// The website's words when the beta is closed to this account
  String? closedMessage;

  /// The last check couldn't reach the website
  bool offline = false;

  void _remember() => _store.writeJson(_key, {
    if (api.token != null) 'token': api.token,
    if (_user != null) 'user': _user!.toJson(),
    'beta': _beta.name,
  });

  void _signedIn(Map<String, Object?> j) {
    final user = AccountUser.from(j['user']);
    if (user == null) throw ApiError('The website answered without an account. Please try again.');
    if (j['token'] is String) api.token = j['token'] as String;
    if (_user?.id != user.id) _beta = BetaAccess.unknown;
    _user = user;
    _remember();
    notifyListeners();
    unawaited(checkBeta());
  }

  /// On start: is the remembered sign-in still good, and is the account still on the beta list?
  Future<void> restore() async {
    if (!checking && _user == null) return;
    try {
      final j = await api.call('GET', '/api/auth/me');
      final user = AccountUser.from(j['user']);
      if (user == null) {
        _forget();
        return;
      }
      _user = user;
      _remember();
      notifyListeners();
      await checkBeta();
    } on ApiError catch (e) {
      // offline: keep the remembered account and its beta answer; refused: sign out
      if (e.status == 401) {
        _forget();
      } else if (e.status == null && signedIn) {
        offline = true;
        notifyListeners();
      }
    } finally {
      if (checking) {
        checking = false;
        notifyListeners();
      }
    }
  }

  /// Asks the website whether this account may use the beta
  Future<void> checkBeta() async {
    if (!signedIn) return;
    try {
      final j = await api.call('GET', '/api/toolkit/me');
      _beta = j['tester'] == true ? BetaAccess.tester : BetaAccess.closed;
      closedMessage = j['message'] as String?;
      offline = false;
      _remember();
    } on ApiError catch (e) {
      if (e.status == 401) {
        _forget();
        return;
      }
      if (e.status == null) offline = true;
    }
    notifyListeners();
  }

  /// Signs in; returns the code challenge when the email still has to be confirmed
  Future<EmailCode?> signIn(String email, String password) async {
    try {
      _signedIn(await api.call('POST', '/api/auth/login', {'email': email.trim().toLowerCase(), 'password': password}));
      return null;
    } on ApiError catch (e) {
      if (!e.needsEmailCode) rethrow;
      return EmailCode(e.data['challenge']! as String, (e.data['sentTo'] as String?) ?? 'your email');
    }
  }

  /// Creates the account; the website then emails a code (returned) to confirm it
  Future<EmailCode?> register({
    required String name,
    required String email,
    required String password,
    String? company,
  }) async {
    try {
      _signedIn(
        await api.call('POST', '/api/auth/register', {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          if (company != null && company.trim().isNotEmpty) 'organization': company.trim(),
        }),
      );
      return null;
    } on ApiError catch (e) {
      if (!e.needsEmailCode) rethrow;
      return EmailCode(e.data['challenge']! as String, (e.data['sentTo'] as String?) ?? 'your email');
    }
  }

  Future<void> confirmEmail(EmailCode c, String code) async =>
      _signedIn(await api.call('POST', '/api/auth/verify-email', {'challenge': c.challenge, 'code': code.trim()}));

  Future<EmailCode> resendCode(EmailCode c) async {
    final j = await api.call('POST', '/api/auth/resend-verify', {'challenge': c.challenge});
    return EmailCode((j['challenge'] as String?) ?? c.challenge, (j['sentTo'] as String?) ?? c.sentTo);
  }

  Future<void> forgotPassword(String email) =>
      api.call('POST', '/api/auth/forgot-password', {'email': email.trim().toLowerCase()});

  /// Starts a sign-in to confirm in the browser (where Google sign-in works)
  Future<BrowserSignIn> startBrowserSignIn() async {
    final j = await api.call('POST', '/api/auth/device/start', {'app': 'Survey Toolkit'});
    final code = j['code'], poll = j['poll'];
    if (code is! String || poll is! String) throw ApiError('The website could not start a sign-in. Please try again.');
    final url = (j['url'] as String?) ?? '/link';
    return BrowserSignIn(code: code, poll: poll, url: url.startsWith('http') ? url : '${api.base}$url?code=$code');
  }

  /// Asks once whether the browser sign-in was confirmed: true when signed in, false to ask again,
  /// an [ApiError] when the code expired
  Future<bool> checkBrowserSignIn(BrowserSignIn s) async {
    final j = await api.call('POST', '/api/auth/device/poll', {'poll': s.poll});
    if (j['user'] != null) {
      _signedIn(j);
      return true;
    }
    if (j['state'] == 'expired' || j['state'] == 'denied') {
      throw ApiError('The sign-in code ran out. Start again.');
    }
    return false;
  }

  /// A single-use address that signs a web app window in and goes on to [path] (the workspace).
  /// null when it can't be had (offline, the beta list): the app then shows its own sign-in.
  Future<String?> handoffUrl(String path) async {
    if (!signedIn) return null;
    try {
      final j = await api.call('POST', '/api/toolkit/handoff', {'next': path});
      final url = j['url'];
      if (url is! String) return null;
      final u = Uri.tryParse(url), base = Uri.parse(api.base);
      // only the website itself, at its handover address
      if (u == null || u.host != base.host || u.scheme != base.scheme || u.path != '/api/toolkit/handoff') return null;
      return url;
    } on ApiError {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await api.call('POST', '/api/auth/logout');
    } on ApiError {
      // signed out on this PC anyway
    }
    _forget();
  }

  void _forget() {
    api.token = null;
    _user = null;
    _beta = BetaAccess.unknown;
    closedMessage = null;
    offline = false;
    _store.remove(_key);
    notifyListeners();
  }
}
