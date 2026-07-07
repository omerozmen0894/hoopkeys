import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseReady = await GameBackend.boot();
  runApp(TapDropArenaApp(firebaseReady: firebaseReady));
}

class TapDropArenaApp extends StatelessWidget {
  const TapDropArenaApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hoop Keys',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff15c7a7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xff0d1117),
        useMaterial3: true,
      ),
      home: AuthGate(firebaseReady: firebaseReady),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      return const AuthScreen(firebaseReady: false);
    }
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const AuthScreen(firebaseReady: true);
        return GameShell(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.firebaseReady) {
      setState(() => _message = 'Firebase baglantisi hazir degil.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_register) {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _email.text.trim(),
              password: _password.text,
            );
        await credential.user?.updateDisplayName(
          _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim(),
        );
        await GameBackend().saveProfileName(
          _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _message = AuthCopy.message(error));
    } catch (error) {
      setState(() => _message = AuthCopy.generic(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _guestLogin() async {
    if (!widget.firebaseReady) {
      setState(() => _message = 'Misafir girisi icin Firebase gerekli.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      await credential.user?.updateDisplayName('Misafir');
      await GameBackend().saveProfileName('Misafir');
    } on FirebaseAuthException catch (error) {
      setState(() => _message = AuthCopy.message(error));
    } catch (error) {
      setState(() => _message = AuthCopy.generic(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _message = 'Sifre sifirlama icin email yaz.');
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _email.text.trim(),
      );
      setState(() => _message = 'Sifre sifirlama maili gonderildi.');
    } on FirebaseAuthException catch (error) {
      setState(() => _message = AuthCopy.message(error));
    } catch (error) {
      setState(() => _message = AuthCopy.generic(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const GameLobbyBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LoginGameMark(),
                      const SizedBox(height: 22),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xff160f0a,
                          ).withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(
                              0xffffd166,
                            ).withValues(alpha: 0.24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xffff7a1a,
                              ).withValues(alpha: 0.18),
                              blurRadius: 34,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: false,
                                  label: Text('Giris'),
                                  icon: Icon(Icons.login),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text('Kayit'),
                                  icon: Icon(Icons.person_add),
                                ),
                              ],
                              selected: {_register},
                              onSelectionChanged:
                                  _busy
                                      ? null
                                      : (value) => setState(
                                        () => _register = value.single,
                                      ),
                            ),
                            if (!widget.firebaseReady) ...[
                              const SizedBox(height: 12),
                              const OfflineFirebaseBanner(),
                            ],
                            if (_register) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _name,
                                decoration: const InputDecoration(
                                  labelText: 'Oyuncu adi',
                                  prefixIcon: Icon(Icons.badge_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Sifre',
                                prefixIcon: Icon(Icons.lock_outline),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            if (_message != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _message!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xffffc46b),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _busy ? null : _submit,
                              icon: Icon(
                                _register ? Icons.person_add : Icons.login,
                              ),
                              label: Text(_register ? 'Kayit Ol' : 'Giris Yap'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _guestLogin,
                              icon: const Icon(Icons.person_outline),
                              label: const Text('Misafir Olarak Basla'),
                            ),
                            TextButton(
                              onPressed: _busy ? null : _resetPassword,
                              child: const Text('Sifremi unuttum'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthHeroPanel extends StatelessWidget {
  const AuthHeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return legacyBuild(context);
  }

  Widget legacyBuild(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff12312e), Color(0xff251707), Color(0xff0f1724)],
        ),
        border: Border.all(color: const Color(0x3319f5a8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xfffff1a8),
                      Color(0xffff8a2a),
                      Color(0xff8a3710),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffff8a2a).withValues(alpha: 0.34),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_basketball,
                  color: Colors.black87,
                  size: 34,
                ),
              ),
              const Spacer(),
              const Chip(
                avatar: Icon(Icons.emoji_events, size: 16),
                label: Text('100 Bolum'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Hoop Keys',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kapilari ac, topu kontrol et, potaya temiz gir ve genel siralamada yuksel.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              Expanded(child: AuthStatPill(label: 'Mod', value: 'Solo/Arena')),
              SizedBox(width: 8),
              Expanded(child: AuthStatPill(label: 'Skor', value: 'Global')),
              SizedBox(width: 8),
              Expanded(child: AuthStatPill(label: 'Giris', value: 'Misafir')),
            ],
          ),
        ],
      ),
    );
  }
}

class AuthStatPill extends StatelessWidget {
  const AuthStatPill({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return legacyBuild(context);
  }

  Widget legacyBuild(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class GameShell extends StatefulWidget {
  const GameShell({super.key, required this.user});

  final User user;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  final _backend = GameBackend();
  int _tab = 0;
  int _selectedLevelIndex = 0;
  int _unlockedLevelIndex = 0;
  int _coins = 0;
  int _routeJokers = 3;
  int _breakerJokers = 3;
  int _keyJokers = 3;
  bool _premium = false;
  String _playerName = 'Oyuncu';

  @override
  void initState() {
    super.initState();
    _playerName = widget.user.displayName ?? _nameFromEmail(widget.user.email);
    _loadProgress();
    _loadEconomy();
  }

  String _nameFromEmail(String? email) {
    final value = email?.split('@').first.trim();
    return value == null || value.isEmpty ? 'Oyuncu' : value;
  }

  Future<void> _loadProgress() async {
    final progress = (await _backend.loadProgress(
      widget.user.uid,
    )).clamp(0, GameLevel.samples.length - 1);
    if (!mounted) return;
    setState(() {
      _unlockedLevelIndex = progress;
      _selectedLevelIndex = progress;
    });
  }

  Future<void> _loadEconomy() async {
    final economy = await _backend.loadEconomy(widget.user.uid);
    if (!mounted) return;
    setState(() {
      _coins = economy.coins;
      _routeJokers = economy.routeJokers;
      _breakerJokers = economy.breakerJokers;
      _keyJokers = economy.keyJokers;
      _premium = economy.premium;
    });
  }

  Future<void> _unlockNext(int finishedLevel) async {
    final next = math.min(finishedLevel + 1, GameLevel.samples.length - 1);
    if (next <= _unlockedLevelIndex) return;
    await _backend.saveProgress(widget.user.uid, next);
    if (mounted) setState(() => _unlockedLevelIndex = next);
  }

  Future<void> _addCoins(int value) async {
    final reward = _premium ? value * 2 : value;
    final coins = _coins + reward;
    await _backend.saveEconomy(
      widget.user.uid,
      coins: coins,
      premium: _premium,
      routeJokers: _routeJokers,
      breakerJokers: _breakerJokers,
      keyJokers: _keyJokers,
    );
    if (mounted) setState(() => _coins = coins);
  }

  Future<void> _activatePremium() async {
    await _backend.saveEconomy(
      widget.user.uid,
      coins: _coins,
      premium: true,
      routeJokers: _routeJokers,
      breakerJokers: _breakerJokers,
      keyJokers: _keyJokers,
    );
    if (mounted) setState(() => _premium = true);
  }

  Future<bool> _spendJoker(PowerUpKind kind) async {
    final route = _routeJokers - (kind == PowerUpKind.route ? 1 : 0);
    final breaker = _breakerJokers - (kind == PowerUpKind.breaker ? 1 : 0);
    final key = _keyJokers - (kind == PowerUpKind.key ? 1 : 0);
    if (route < 0 || breaker < 0 || key < 0) return false;
    setState(() {
      _routeJokers = route;
      _breakerJokers = breaker;
      _keyJokers = key;
    });
    unawaited(
      _backend
          .saveEconomy(
            widget.user.uid,
            coins: _coins,
            premium: _premium,
            routeJokers: route,
            breakerJokers: breaker,
            keyJokers: key,
          )
          .timeout(const Duration(seconds: 3), onTimeout: () {}),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    void goMenu() => setState(() => _tab = 0);
    void continueGame() {
      setState(() {
        _selectedLevelIndex = _unlockedLevelIndex;
        _tab = 1;
      });
    }

    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0) goMenu();
      },
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _tab,
            children: [
              MainMenuScreen(
                playerName: _playerName,
                coins: _coins,
                premium: _premium,
                unlockedLevelIndex: _unlockedLevelIndex,
                onOpen: (value) => setState(() => _tab = value),
                onContinue: continueGame,
              ),
              PlayScreen(
                backend: _backend,
                playerName: _playerName,
                coins: _coins,
                routeJokers: _routeJokers,
                breakerJokers: _breakerJokers,
                keyJokers: _keyJokers,
                premium: _premium,
                selectedLevelIndex: _selectedLevelIndex,
                unlockedLevelIndex: _unlockedLevelIndex,
                onLevelSelected:
                    (value) => setState(() => _selectedLevelIndex = value),
                onLevelCompleted: _unlockNext,
                onCoinsEarned: _addCoins,
                onSpendJoker: _spendJoker,
                onBack: goMenu,
              ),
              LeaderboardScreen(backend: _backend, onBack: goMenu),
              ArenaScreen(
                backend: _backend,
                playerName: _playerName,
                selectedLevelIndex: _selectedLevelIndex,
                onLevelSelected:
                    (value) => setState(() => _selectedLevelIndex = value),
                onBack: goMenu,
              ),
              StoreScreen(
                coins: _coins,
                premium: _premium,
                onActivatePremium: _activatePremium,
                onBack: goMenu,
              ),
              HowToPlayScreen(onBack: goMenu),
              AccountScreen(
                backend: _backend,
                playerName: _playerName,
                email:
                    widget.user.isAnonymous
                        ? 'Misafir oyuncu'
                        : widget.user.email ?? '',
                onChanged: (value) => setState(() => _playerName = value),
                onBack: goMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({
    super.key,
    required this.playerName,
    required this.coins,
    required this.premium,
    required this.unlockedLevelIndex,
    required this.onOpen,
    required this.onContinue,
  });

  final String playerName;
  final int coins;
  final bool premium;
  final int unlockedLevelIndex;
  final ValueChanged<int> onOpen;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return GameLobbyMenu(
      playerName: playerName,
      coins: coins,
      premium: premium,
      unlockedLevelIndex: unlockedLevelIndex,
      onOpen: onOpen,
      onContinue: onContinue,
    );
  }

  Widget legacyBuild(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff07131a), Color(0xff0d1117), Color(0xff171008)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          PremiumLobbyHeader(
            playerName: playerName,
            coins: coins,
            premium: premium,
            unlockedLevelIndex: unlockedLevelIndex,
            onAccount: () => onOpen(6),
          ),
          const SizedBox(height: 10),
          MenuHeroCard(
            unlockedLevelIndex: unlockedLevelIndex,
            onPlay: onContinue,
            onArena: () => onOpen(3),
          ),
          const SizedBox(height: 12),
          LevelProgressStrip(unlockedLevelIndex: unlockedLevelIndex),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.12,
            children: [
              MenuCard(
                icon: Icons.leaderboard,
                title: 'Siralama',
                body: 'Gunluk, haftalik ve aylik podyum.',
                onTap: () => onOpen(2),
              ),
              MenuCard(
                icon: Icons.storefront,
                title: 'Market',
                body: 'Joker, coin ve premium alanı.',
                onTap: () => onOpen(4),
              ),
              MenuCard(
                icon: Icons.school,
                title: 'Nasil Oynanir',
                body: 'Atis, kapilar, jokerler ve skor.',
                onTap: () => onOpen(5),
              ),
              MenuCard(
                icon: Icons.groups,
                title: 'Arena',
                body: 'Arkadasinla oda yarisi.',
                onTap: () => onOpen(3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class GameLobbyMenu extends StatelessWidget {
  const GameLobbyMenu({
    super.key,
    required this.playerName,
    required this.coins,
    required this.premium,
    required this.unlockedLevelIndex,
    required this.onOpen,
    required this.onContinue,
  });

  final String playerName;
  final int coins;
  final bool premium;
  final int unlockedLevelIndex;
  final ValueChanged<int> onOpen;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final nextLevel = unlockedLevelIndex + 1;
    final progress = (nextLevel / GameLevel.samples.length).clamp(0.0, 1.0);
    return Stack(
      children: [
        const GameLobbyBackdrop(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PlayerBadge(
                        playerName: playerName,
                        premium: premium,
                        onAccount: () => onOpen(6),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CoinBadge(coins: coins),
                  ],
                ),
                const Spacer(),
                _ArenaHeroPanel(nextLevel: nextLevel),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.black.withValues(alpha: 0.26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: _ProgressRunway(progress: progress, level: nextLevel),
                ),
                const SizedBox(height: 18),
                _PlayButton(onPressed: onContinue),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xff081411).withValues(alpha: 0.92),
                        const Color(0xff0d2923).withValues(alpha: 0.92),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xff19f5a8).withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _DockAction(
                        icon: Icons.leaderboard,
                        label: 'Siralama',
                        onTap: () => onOpen(2),
                      ),
                      _DockAction(
                        icon: Icons.storefront,
                        label: 'Market',
                        onTap: () => onOpen(4),
                      ),
                      _DockAction(
                        icon: Icons.school,
                        label: 'Rehber',
                        onTap: () => onOpen(5),
                      ),
                      _DockAction(
                        icon: Icons.groups_rounded,
                        label: 'Arena',
                        onTap: () => onOpen(3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class GameLobbyBackdrop extends StatefulWidget {
  const GameLobbyBackdrop({super.key});

  @override
  State<GameLobbyBackdrop> createState() => _GameLobbyBackdropState();
}

class _GameLobbyBackdropState extends State<GameLobbyBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff101720), Color(0xff26190e), Color(0xff6f3b16)],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder:
            (context, child) => CustomPaint(
              painter: GameLobbyPainter(_controller.value),
              child: child,
            ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class GameLobbyPainter extends CustomPainter {
  const GameLobbyPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = progress * math.pi * 2;
    final vignette =
        Paint()
          ..shader = RadialGradient(
            center: Alignment(math.sin(pulse) * 0.10, -0.40),
            radius: 1.25,
            colors: [
              const Color(0xff774014).withValues(alpha: 0.38),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.55),
            ],
            stops: const [0.0, 0.56, 1.0],
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);

    final light =
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(
                0xffffd166,
              ).withValues(alpha: 0.20 + math.sin(pulse * 1.4).abs() * 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(
                size.width * (0.5 + math.sin(pulse) * 0.07),
                size.height * 0.15,
              ),
              radius: size.width * 0.55,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.15),
      size.width,
      light,
    );

    final line =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
    final woodLine =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.075)
          ..strokeWidth = 1;
    for (var x = -size.width; x < size.width * 2; x += 34) {
      canvas.drawLine(
        Offset(x.toDouble(), 0),
        Offset(x + size.height * 0.18, size.height),
        woodLine,
      );
    }
    canvas.drawLine(
      Offset(0, size.height * 0.55),
      Offset(size.width, size.height * 0.55),
      line,
    );
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.55), 82, line);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.5, size.height * 0.92),
        radius: size.width * 0.42,
      ),
      math.pi,
      math.pi,
      false,
      line,
    );

    for (var i = 0; i < 7; i++) {
      final t = i / 6;
      final x = size.width * t;
      final h = 16 + math.sin(pulse * 2 + i) * 6;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 10, size.height * 0.08, 20, h),
          const Radius.circular(4),
        ),
        Paint()
          ..color = Color.lerp(
            const Color(0xff19f5a8),
            const Color(0xffffd166),
            (math.sin(pulse + i) + 1) / 2,
          )!.withValues(alpha: 0.18),
      );
    }

    final lane =
        Paint()
          ..color = const Color(0x44ffffff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    final laneRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.82),
      width: size.width * 0.42,
      height: size.height * 0.20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(laneRect, const Radius.circular(10)),
      lane,
    );

    final hoopPaint =
        Paint()
          ..color = const Color(0xff19f5a8).withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
    final boardPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    final hoopCenter = Offset(size.width * 0.5, size.height * 0.23);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: hoopCenter - const Offset(0, 28),
          width: 116,
          height: 70,
        ),
        const Radius.circular(6),
      ),
      boardPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: hoopCenter + const Offset(0, 22),
        width: 92,
        height: 22,
      ),
      hoopPaint,
    );
    final netPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1.4;
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(
        hoopCenter + Offset(i * 13.0, 33),
        hoopCenter + Offset(i * 7.0, 70),
        netPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GameLobbyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ArenaHeroPanel extends StatelessWidget {
  const _ArenaHeroPanel({required this.nextLevel});

  final int nextLevel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MenuBallEmblem(),
        const SizedBox(height: 14),
        Text(
          'Hoop Keys',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
            color: const Color(0xfffff4dc),
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              const Shadow(color: Color(0x99ff8a2a), blurRadius: 30),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0x44ffd166)),
          ),
          child: Text(
            'Bolum $nextLevel  -  bonus topla, sek, potaya ak',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xeaffffff),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff8a2a).withValues(alpha: 0.48),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 66,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.play_arrow_rounded, size: 38),
          label: const Text(
            'OYNA',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xffff8a2a),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Color(0xffffe5a8), width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginGameMark extends StatelessWidget {
  const LoginGameMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _MenuBallEmblem(compact: true),
        const SizedBox(height: 14),
        Text(
          'Hoop Keys',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sek, hizlan, bonus topla, potaya gir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xc7ffffff)),
        ),
      ],
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.playerName,
    required this.premium,
    required this.onAccount,
  });

  final String playerName;
  final bool premium;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onAccount,
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  premium ? const Color(0xffffd166) : const Color(0xff1f6f62),
              foregroundColor: Colors.black,
              child: Icon(premium ? Icons.workspace_premium : Icons.person),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                playerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xffffd166),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffffd166).withValues(alpha: 0.24),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.black),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuBallEmblem extends StatelessWidget {
  const _MenuBallEmblem({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 96.0 : 128.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff8a2a).withValues(alpha: 0.42),
            blurRadius: 34,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CustomPaint(
            painter: _BasketballEmblemPainter(),
            child: SizedBox.expand(),
          ),
          Positioned(
            right: compact ? 14 : 18,
            bottom: compact ? 12 : 16,
            child: Container(
              width: compact ? 30 : 38,
              height: compact ? 30 : 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xffffd166),
                border: Border.all(color: Colors.black87, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.key,
                color: const Color(0xff0f1724),
                size: compact ? 18 : 23,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BasketballEmblemPainter extends CustomPainter {
  const _BasketballEmblemPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ballPaint =
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.45),
            colors: [Color(0xfffff2a8), Color(0xffff8a2a), Color(0xff7c2e0d)],
          ).createShader(rect);
    canvas.drawOval(rect.deflate(size.width * 0.04), ballPaint);

    final seam =
        Paint()
          ..color = const Color(0xff1b120d).withValues(alpha: 0.82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.045
          ..strokeCap = StrokeCap.round;
    final inner = rect.deflate(size.width * 0.13);
    canvas.drawLine(
      Offset(size.width * 0.50, inner.top),
      Offset(size.width * 0.50, inner.bottom),
      seam,
    );
    canvas.drawArc(inner, -math.pi * 0.05, math.pi * 1.10, false, seam);
    canvas.drawArc(inner, math.pi * 0.95, math.pi * 1.10, false, seam);
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.24,
        size.width * 0.90,
        size.height * 0.52,
      ),
      0,
      math.pi,
      false,
      seam,
    );

    final shine =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.035
          ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.20,
        size.height * 0.12,
        size.width * 0.42,
        size.height * 0.28,
      ),
      math.pi * 1.05,
      math.pi * 0.42,
      false,
      shine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HudGameIcon extends StatelessWidget {
  const _HudGameIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff8a2a).withValues(alpha: 0.42),
            blurRadius: 10,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CustomPaint(
            painter: _BasketballEmblemPainter(),
            child: SizedBox.expand(),
          ),
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xffffd166),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black87, width: 1),
              ),
              child: const Icon(Icons.key, color: Colors.black87, size: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRunway extends StatelessWidget {
  const _ProgressRunway({required this.progress, required this.level});

  final double progress;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Text('Sezon yolu', style: TextStyle(color: Colors.white70)),
            const Spacer(),
            Text(
              '$level/${GameLevel.samples.length}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 12,
            value: progress,
            backgroundColor: Colors.black.withValues(alpha: 0.35),
            valueColor: const AlwaysStoppedAnimation(Color(0xff19f5a8)),
          ),
        ),
      ],
    );
  }
}

class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xff0b2926).withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x5519f5a8)),
              ),
              child: Icon(icon, color: const Color(0xffb7fff0)),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class PremiumLobbyHeader extends StatelessWidget {
  const PremiumLobbyHeader({
    super.key,
    required this.playerName,
    required this.coins,
    required this.premium,
    required this.unlockedLevelIndex,
    required this.onAccount,
  });

  final String playerName;
  final int coins;
  final bool premium;
  final int unlockedLevelIndex;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff102b2b), Color(0xff2d1a08), Color(0xff111827)],
        ),
        border: Border.all(
          color: const Color(0xffffd166).withValues(alpha: 0.30),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff8a2a).withValues(alpha: 0.18),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xfffff1a8),
                      Color(0xffff8a2a),
                      Color(0xff8a3710),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffff8a2a).withValues(alpha: 0.38),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: const Icon(Icons.key, color: Colors.black87, size: 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoop Keys',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Hesap',
                onPressed: onAccount,
                icon: const Icon(Icons.person),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LobbyStat(
                  icon: Icons.flag,
                  label: 'Bolum',
                  value: '${unlockedLevelIndex + 1}/100',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LobbyStat(
                  icon: Icons.monetization_on,
                  label: premium ? 'P Coin' : 'Coin',
                  value: '$coins',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LobbyStat(
                  icon: Icons.workspace_premium,
                  label: 'Mod',
                  value: premium ? 'Premium' : 'Standart',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LobbyStat extends StatelessWidget {
  const _LobbyStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xffffd166), size: 18),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class MenuHeroCard extends StatelessWidget {
  const MenuHeroCard({
    super.key,
    required this.unlockedLevelIndex,
    required this.onPlay,
    required this.onArena,
  });

  final int unlockedLevelIndex;
  final VoidCallback onPlay;
  final VoidCallback onArena;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 190),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff17413d), Color(0xff7a3510), Color(0xff101923)],
        ),
        border: Border.all(
          color: const Color(0xffffd166).withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffff8a2a).withValues(alpha: 0.16),
            blurRadius: 30,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sports_basketball,
                size: 64,
                color: Color(0xffff8a2a),
              ),
              const Spacer(),
              Chip(
                avatar: const Icon(Icons.bolt, size: 16),
                label: const Text('Kaldigin yer'),
                backgroundColor: const Color(
                  0xffffd166,
                ).withValues(alpha: 0.18),
              ),
            ],
          ),
          const Spacer(),
          Text(
            'Sek, hizlan, fileyi bul.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kaldigin bolumden basla. Bonuslari topla, engelleri kullan, potaya temiz gir.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.flag, size: 16),
            label: Text(
              'Devam: Bolum ${unlockedLevelIndex + 1} - ${GameLevel.samples[unlockedLevelIndex].name}',
            ),
            backgroundColor: const Color(0xff19f5a8).withValues(alpha: 0.16),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Devam Et'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Arena',
                onPressed: onArena,
                icon: const Icon(Icons.groups),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LevelProgressStrip extends StatelessWidget {
  const LevelProgressStrip({super.key, required this.unlockedLevelIndex});

  final int unlockedLevelIndex;

  @override
  Widget build(BuildContext context) {
    final total = GameLevel.samples.length;
    final progress = (unlockedLevelIndex + 1) / total;
    final start = math.max(0, unlockedLevelIndex - 5);
    final end = math.min(total, start + 12);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Color(0xff19f5a8)),
              const SizedBox(width: 8),
              Text(
                'Bolum ilerlemesi',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              Text(
                '${unlockedLevelIndex + 1}/$total',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xff2d3748),
              color: const Color(0xff19f5a8),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = start; i < end; i++)
                _ProgressDot(index: i, unlockedLevelIndex: unlockedLevelIndex),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Gecilen bolumler yesil, kaldigin bolum sari gosterilir.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.index, required this.unlockedLevelIndex});

  final int index;
  final int unlockedLevelIndex;

  @override
  Widget build(BuildContext context) {
    final completed = index < unlockedLevelIndex;
    final current = index == unlockedLevelIndex;
    final locked = index > unlockedLevelIndex;
    final color =
        completed
            ? const Color(0xff19f5a8)
            : current
            ? const Color(0xffffd166)
            : const Color(0xff2d3748);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: locked ? 0.42 : 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: current ? Colors.white : Colors.white.withValues(alpha: 0.10),
        ),
        boxShadow:
            completed
                ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 12,
                  ),
                ]
                : null,
      ),
      child: Icon(
        completed
            ? Icons.check
            : current
            ? Icons.play_arrow
            : Icons.lock,
        size: 17,
        color: completed || current ? Colors.black : Colors.white54,
      ),
    );
  }
}

class MenuCard extends StatelessWidget {
  const MenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = switch (icon) {
      Icons.leaderboard => const Color(0xffffd166),
      Icons.storefront => const Color(0xff19f5a8),
      Icons.school => const Color(0xff7dd3fc),
      Icons.groups => const Color(0xffff8a2a),
      _ => const Color(0xffffd166),
    };
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.20),
              const Color(0xff161b22),
              const Color(0xff0f1724),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 18),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 32),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              body,
              maxLines: 2,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.backend,
    required this.playerName,
    required this.coins,
    required this.routeJokers,
    required this.breakerJokers,
    required this.keyJokers,
    required this.premium,
    required this.selectedLevelIndex,
    required this.unlockedLevelIndex,
    required this.onLevelSelected,
    required this.onLevelCompleted,
    required this.onCoinsEarned,
    required this.onSpendJoker,
    required this.onBack,
  });

  final GameBackend backend;
  final String playerName;
  final int coins;
  final int routeJokers;
  final int breakerJokers;
  final int keyJokers;
  final bool premium;
  final int selectedLevelIndex;
  final int unlockedLevelIndex;
  final ValueChanged<int> onLevelSelected;
  final Future<void> Function(int levelIndex) onLevelCompleted;
  final Future<void> Function(int coins) onCoinsEarned;
  final Future<bool> Function(PowerUpKind kind) onSpendJoker;
  final VoidCallback onBack;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late GameLevel _level;
  late GameRun _run;
  Duration _lastTick = Duration.zero;
  bool _scoreSubmitted = false;
  bool _showTutorial = false;
  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    _loadLevel(widget.selectedLevelIndex);
    _maybeShowTutorial();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(covariant PlayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLevelIndex != widget.selectedLevelIndex) {
      _loadLevel(widget.selectedLevelIndex);
      _maybeShowTutorial();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _loadLevel(int index) {
    final safeIndex = index.clamp(0, GameLevel.samples.length - 1);
    _level = GameLevel.samples[safeIndex];
    _run = GameRun(level: _level);
    _lastTick = Duration.zero;
    _scoreSubmitted = false;
  }

  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked || widget.selectedLevelIndex != 0) return;
    _tutorialChecked = true;
    final prefs = await SharedPreferences.getInstance();
    final key = 'tutorial_seen_${widget.backend.uid}';
    if (!mounted || prefs.getBool(key) == true) return;
    setState(() => _showTutorial = true);
  }

  Future<void> _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_seen_${widget.backend.uid}', true);
    if (mounted) setState(() => _showTutorial = false);
  }

  void _tick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (!mounted) return;
    final changed = _run.step(dt.clamp(0, 0.033).toDouble());
    if (_run.won && !_scoreSubmitted) {
      _scoreSubmitted = true;
      unawaited(_finishLevel());
    }
    if (changed) setState(() {});
  }

  Future<void> _finishLevel() async {
    final finishedLevel = _level;
    final finishedRun = _run;
    unawaited(
      _persistLevelFinish(
        finishedLevel,
        finishedRun,
      ).timeout(const Duration(seconds: 4), onTimeout: () {}),
    );
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 1850));
    if (!mounted) return;
    final next = finishedLevel.index + 1;
    if (next < GameLevel.samples.length) {
      widget.onLevelSelected(next);
      setState(() => _loadLevel(next));
    }
  }

  Future<void> _persistLevelFinish(GameLevel level, GameRun run) async {
    try {
      await Future.wait([
        widget.backend.submitScore(
          name: widget.playerName,
          score: run.score,
          level: level.name,
          levelIndex: level.index,
          moves: run.moves,
          durationMs: run.elapsed.inMilliseconds,
        ),
        widget.onLevelCompleted(level.index),
        widget.onCoinsEarned(45 + level.index * 7 + run.collectedCoins * 18),
      ]);
    } catch (_) {
      // Gameplay must keep flowing even if network/local persistence is slow.
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        _run.won
            ? (_run.perfectShot ? 'Mukemmel basket!' : 'Basket!')
            : _run.failed
            ? 'Tekrar dene'
            : !_run.launched
            ? 'Surukle ve birak'
            : _run.remainingNudges == 0
            ? 'Kontrol bitti'
            : _level.hint;
    final hudStatus =
        '$status  | Anahtar ${_run.availableKeys}/${_run.totalKeys}  | Bonus ${_run.collectedCoins}/${_run.totalBonusCoins}';
    return Container(
      color: const Color(0xff0a0f16),
      child: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 700;
                final maxContentWidth =
                    isTablet
                        ? math
                            .min(
                              constraints.maxWidth - 32,
                              constraints.maxWidth > constraints.maxHeight
                                  ? 920
                                  : 760,
                            )
                            .toDouble()
                        : constraints.maxWidth;
                final sidePadding = isTablet ? 16.0 : 0.0;
                final boardPadding =
                    isTablet
                        ? const EdgeInsets.fromLTRB(14, 10, 14, 10)
                        : const EdgeInsets.fromLTRB(10, 8, 10, 8);
                return Center(
                  child: SizedBox(
                    width: maxContentWidth,
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            12 + sidePadding,
                            8,
                            12 + sidePadding,
                            0,
                          ),
                          child: MobileGameHud(
                            title: 'B${_level.index + 1}  ${_level.name}',
                            status: hudStatus,
                            run: _run,
                            coins: widget.coins,
                            premium: widget.premium,
                            onRestart:
                                () => setState(() => _loadLevel(_level.index)),
                            onLevels: _showLevelSheet,
                            onBack: widget.onBack,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: boardPadding,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: GameBoard(
                                run: _run,
                                onNudge:
                                    (force) =>
                                        setState(() => _run.nudge(force)),
                                onAim:
                                    (force) => setState(() => _run.aim(force)),
                                onShoot:
                                    (force) =>
                                        setState(() => _run.shoot(force)),
                                onRestart:
                                    () => setState(
                                      () => _loadLevel(_level.index),
                                    ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            12 + sidePadding,
                            0,
                            12 + sidePadding,
                            10,
                          ),
                          child: MobileJokerDock(
                            routeCount: widget.routeJokers,
                            breakerCount: widget.breakerJokers,
                            keyCount: widget.keyJokers,
                            onExtraControl: () async {
                              if (await widget.onSpendJoker(
                                PowerUpKind.route,
                              )) {
                                setState(() => _run.addControlJoker());
                              }
                            },
                            onExtraTime: () async {
                              if (await widget.onSpendJoker(
                                PowerUpKind.breaker,
                              )) {
                                setState(() => _run.addBreakerJoker());
                              }
                            },
                            onExtraKey: () async {
                              if (await widget.onSpendJoker(PowerUpKind.key)) {
                                setState(() => _run.openGateJoker());
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_showTutorial)
            Positioned.fill(
              child: GameTutorialOverlay(onClose: _dismissTutorial),
            ),
        ],
      ),
    );
  }

  void _showLevelSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff0d1117),
      showDragHandle: true,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LevelSelector(
              selectedIndex: _level.index,
              unlockedIndex: widget.unlockedLevelIndex,
              onSelected: (index) {
                if (index > widget.unlockedLevelIndex) return;
                Navigator.of(context).pop();
                widget.onLevelSelected(index);
                setState(() => _loadLevel(index));
              },
            ),
          ),
    );
  }
}

enum PowerUpKind { route, breaker, key }

class GameTutorialOverlay extends StatelessWidget {
  const GameTutorialOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.68),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xff101923),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xff19f5a8).withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.38),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key, color: Color(0xffffd166), size: 32),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ilk atis rehberi',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Kirmizi kapilar topu durdurur. Top once altin anahtari alir, sonra kapiya carparsa kapi kalici acilir.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  const GateTutorialDemo(),
                  const SizedBox(height: 14),
                  const TutorialLine(
                    icon: Icons.swipe,
                    text:
                        'Topu surukle ve birak: atisin yonunu sen belirlersin.',
                  ),
                  const TutorialLine(
                    icon: Icons.key,
                    text:
                        'Anahtar topun ustunde durur; elle degil, topla alininca kapilari acar.',
                  ),
                  const TutorialLine(
                    icon: Icons.sports_basketball,
                    text:
                        'Amac potaya girmek; bonus coinler daha yuksek skor verir.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Anladim, basla'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GateTutorialDemo extends StatelessWidget {
  const GateTutorialDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff0d1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _GateStateBox(
              label: 'Anahtar',
              color: Color(0xffffd166),
              icon: Icons.key,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.sports_basketball, color: Color(0xffffd166)),
          ),
          Expanded(
            child: _GateStateBox(
              label: 'Acik',
              color: Color(0xff19f5a8),
              icon: Icons.lock_open,
            ),
          ),
        ],
      ),
    );
  }
}

class _GateStateBox extends StatelessWidget {
  const _GateStateBox({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class TutorialLine extends StatelessWidget {
  const TutorialLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xff19f5a8), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.backend,
    required this.onBack,
  });

  final GameBackend backend;
  final VoidCallback onBack;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardPeriod _period = LeaderboardPeriod.daily;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GameHeader(
          title: 'Siralama',
          subtitle: '${_period.label} genel liderleri ve toplam skor yarisi.',
          actions: [
            IconButton(
              tooltip: 'Geri',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<LeaderboardPeriod>(
            segments:
                LeaderboardPeriod.values
                    .map(
                      (period) => ButtonSegment(
                        value: period,
                        label: Text(period.label),
                        icon: Icon(period.icon),
                      ),
                    )
                    .toList(),
            selected: {_period},
            onSelectionChanged:
                (value) => setState(() => _period = value.single),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<LeaderboardEntry>>(
            stream: widget.backend.watchLeaderboard(period: _period),
            builder: (context, snapshot) {
              final entries = snapshot.data ?? LeaderboardEntry.demoGlobal();
              if (entries.isEmpty) {
                return const EmptyPanel(
                  icon: Icons.emoji_events_outlined,
                  title: 'Henüz skor yok',
                  body: 'Bu periyotta ilk bitiren oyuncu zirveye yazilir.',
                );
              }
              final topEntries = entries.take(3).toList();
              final restEntries = entries.skip(3).toList();
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                itemCount: restEntries.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return TopThreePodium(entries: topEntries);
                  }
                  return LeaderboardTile(
                    entry: restEntries[index - 1],
                    rank: index + 3,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ArenaScreen extends StatefulWidget {
  const ArenaScreen({
    super.key,
    required this.backend,
    required this.playerName,
    required this.selectedLevelIndex,
    required this.onLevelSelected,
    required this.onBack,
  });

  final GameBackend backend;
  final String playerName;
  final int selectedLevelIndex;
  final ValueChanged<int> onLevelSelected;
  final VoidCallback onBack;

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen>
    with SingleTickerProviderStateMixin {
  final _roomCode = TextEditingController();
  StreamSubscription<ArenaRoom?>? _roomSub;
  late final Ticker _ticker;
  ArenaRoom? _room;
  GameRun? _run;
  Duration _lastTick = Duration.zero;
  bool _busy = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _roomSub?.cancel();
    _roomCode.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final run = _run;
    final room = _room;
    if (run == null || room == null) return;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    final changed = run.step(dt.clamp(0, 0.033).toDouble());
    if (run.won && !_submitted) {
      _submitted = true;
      widget.backend.submitArenaScore(room.id, run.score);
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _createRoom() async {
    setState(() => _busy = true);
    final room = await widget.backend.createArenaRoom(
      widget.playerName,
      widget.selectedLevelIndex,
    );
    await _watch(room.id);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _joinRoom() async {
    final code = _roomCode.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    final room = await widget.backend.joinArenaRoom(code, widget.playerName);
    await _watch(room.id);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _watch(String id) async {
    await _roomSub?.cancel();
    _roomSub = widget.backend.watchArenaRoom(id).listen((room) {
      if (room == null || !mounted) return;
      final shouldCreateRun = _room?.id != room.id || _run == null;
      setState(() {
        _room = room;
        if (shouldCreateRun) {
          _run = GameRun(level: GameLevel.samples[room.levelIndex]);
          _lastTick = Duration.zero;
          _submitted = false;
        }
      });
    });
  }

  void _restartArenaRun() {
    final room = _room;
    if (room == null) return;
    setState(() {
      _run = GameRun(level: GameLevel.samples[room.levelIndex]);
      _lastTick = Duration.zero;
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final run = _run;
    return Column(
      children: [
        GameHeader(
          title: 'Arena',
          subtitle: 'Oda kur, kodu paylas, ayni potada skor yarisi yap.',
          actions: [
            IconButton(
              tooltip: 'Geri',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        LevelSelector(
          selectedIndex: widget.selectedLevelIndex,
          unlockedIndex: GameLevel.samples.length - 1,
          onSelected: widget.onLevelSelected,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _createRoom,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Oda Kur'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _roomCode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Oda kodu',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Katil',
                onPressed: _busy ? null : _joinRoom,
                icon: const Icon(Icons.login),
              ),
            ],
          ),
        ),
        if (room == null)
          const Expanded(
            child: EmptyPanel(
              icon: Icons.groups_2_outlined,
              title: 'Arena bekliyor',
              body: 'Bir oda kur veya arkadasinin koduyla katil.',
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                ArenaRoomStrip(room: room),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    child:
                        run == null
                            ? const SizedBox.shrink()
                            : GameBoard(
                              run: run,
                              onNudge:
                                  (force) => setState(() => run.nudge(force)),
                              onAim: (force) => setState(() => run.aim(force)),
                              onShoot:
                                  (force) => setState(() => run.shoot(force)),
                              onRestart: _restartArenaRun,
                            ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class ArenaRoomStrip extends StatelessWidget {
  const ArenaRoomStrip({super.key, required this.room});

  final ArenaRoom room;

  @override
  Widget build(BuildContext context) {
    final winner = room.winnerName;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xff19f5a8).withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff19f5a8).withValues(alpha: 0.12),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xff19f5a8),
            foregroundColor: Colors.black,
            child: Text(room.id.substring(0, 2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oda ${room.id}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${room.hostName}: ${room.hostScore ?? '-'}   ${room.guestName ?? 'Bekleniyor'}: ${room.guestScore ?? '-'}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (winner != null)
            Chip(
              avatar: const Icon(Icons.emoji_events, size: 16),
              label: Text(winner),
            ),
        ],
      ),
    );
  }
}

class StoreScreen extends StatelessWidget {
  const StoreScreen({
    super.key,
    required this.coins,
    required this.premium,
    required this.onActivatePremium,
    required this.onBack,
  });

  final int coins;
  final bool premium;
  final VoidCallback onActivatePremium;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        GameHeader(
          title: 'Market',
          subtitle: '$coins coin | Jokerler oyun icinde kullanilir.',
          actions: [
            IconButton(
              tooltip: 'Geri',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        StoreOffer(
          icon: Icons.workspace_premium,
          title: premium ? 'Premium Aktif' : 'Premium Mod',
          body:
              premium
                  ? 'Bolum odulleri iki kat geliyor.'
                  : 'Coin kazancini ikiye katlar, ileride reklamsiz/ozel potalar icin hazir.',
          action: premium ? 'Aktif' : 'Aktif Et',
          onTap: premium ? null : onActivatePremium,
        ),
        const SizedBox(height: 10),
        const StoreOffer(
          icon: Icons.track_changes,
          title: 'Rota Jokeri',
          body:
              'Baslangicta 3 adet. Topu potaya dogru guclu sekilde yonlendirir.',
          action: 'Oyun icinde',
        ),
        const SizedBox(height: 10),
        const StoreOffer(
          icon: Icons.hardware,
          title: 'Kirici Joker',
          body:
              'Baslangicta 3 adet. En yakin duvar veya engeli sahadan kaldirir.',
          action: 'Oyun icinde',
        ),
        const SizedBox(height: 10),
        const StoreOffer(
          icon: Icons.key,
          title: 'Anahtar Jokeri',
          body: 'Baslangicta 3 adet. En yakin kapinin kilidini direkt acar.',
          action: 'Oyun icinde',
        ),
        const SizedBox(height: 10),
        const StoreOffer(
          icon: Icons.attach_money,
          title: 'Para Kazanimi',
          body:
              'Bu alan gercek odeme, reklam odulu veya sponsorlu coin paketleri icin hazirlandi.',
          action: 'Hazir',
        ),
      ],
    );
  }
}

class StoreOffer extends StatelessWidget {
  const StoreOffer({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xff161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xffffd166),
            foregroundColor: Colors.black,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(body, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Atis', 'Topu surukle ve birak. Nisan cizgisi atis yonunu gosterir.'),
      (
        'Anahtarli Kapilar',
        'Top altin anahtari alir, sonra kilitli kapiya carparsa kapi kalici acilir.',
      ),
      (
        'Aksiyon Alanlari',
        'Mavi hiz seridi topu potaya iter, turkuaz cekim alani rotayi yumusatir.',
      ),
      ('Bonus Coin', 'Riskli rotadaki altin bonuslar skoru ve odulu artirir.'),
      (
        'Joker',
        'Rota topu potaya ceker, kirici engeli kaldirir, anahtar kapinin kilidini acar.',
      ),
      ('Skor', 'Az hamle, az kontrol ve hizli basket daha cok puan getirir.'),
      ('Arena', 'Oda kodu ile arkadasinla ayni bolumde skor yarisi yaparsin.'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        GameHeader(
          title: 'Nasil Oynanir',
          subtitle: 'Ilk bolumden itibaren hedef: temiz atis, dogru rota.',
          actions: [
            IconButton(
              tooltip: 'Geri',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: StoreOffer(
              icon: Icons.sports_basketball,
              title: item.$1,
              body: item.$2,
              action: 'OK',
            ),
          ),
        ),
      ],
    );
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    required this.backend,
    required this.playerName,
    required this.email,
    required this.onChanged,
    required this.onBack,
  });

  final GameBackend backend;
  final String playerName;
  final String email;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.playerName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final value = _name.text.trim().isEmpty ? 'Oyuncu' : _name.text.trim();
    await FirebaseAuth.instance.currentUser?.updateDisplayName(value);
    await widget.backend.saveProfileName(value);
    widget.onChanged(value);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Oyuncu adi guncellendi.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      children: [
        GameHeader(
          title: 'Hesap',
          subtitle: 'Profilin siralamalarda bu adla gorunur.',
          actions: [
            IconButton(
              tooltip: 'Geri',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Oyuncu adi',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.white12),
          ),
          tileColor: const Color(0xff161b22),
          leading: const Icon(Icons.email_outlined),
          title: Text(widget.email),
          subtitle: const Text('Email ve sifre ile giris yapildi.'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saveName,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Kaydet'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Cikis Yap'),
        ),
      ],
    );
  }
}

class GameBoard extends StatefulWidget {
  const GameBoard({
    super.key,
    required this.run,
    required this.onNudge,
    required this.onAim,
    required this.onShoot,
    required this.onRestart,
  });

  final GameRun run;
  final ValueChanged<Offset> onNudge;
  final ValueChanged<Offset> onAim;
  final ValueChanged<Offset> onShoot;
  final VoidCallback onRestart;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  Offset? _dragStart;
  Offset? _dragEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            if (widget.run.failed) return;
            _dragStart = details.localPosition;
            _dragEnd = details.localPosition;
          },
          onPanUpdate: (details) {
            if (widget.run.failed || _dragStart == null) return;
            _dragEnd = details.localPosition;
            final drag = _dragEnd! - _dragStart!;
            final force = Offset(drag.dx / size.width, drag.dy / size.height);
            if (!widget.run.launched) widget.onAim(force);
          },
          onPanEnd: (_) {
            if (widget.run.failed || _dragStart == null || _dragEnd == null) {
              _dragStart = null;
              _dragEnd = null;
              return;
            }
            final drag = _dragEnd! - _dragStart!;
            final force = Offset(drag.dx / size.width, drag.dy / size.height);
            if (widget.run.launched) {
              widget.onNudge(force);
            } else {
              widget.onShoot(force);
            }
            _dragStart = null;
            _dragEnd = null;
          },
          onTapDown: (details) {
            if (widget.run.failed) {
              widget.onRestart();
              return;
            }
            final local = details.localPosition;
            if (widget.run.launched) return;
            widget.onAim(
              Offset(
                (local.dx / size.width - widget.run.ball.dx) * 0.25,
                (local.dy / size.height - widget.run.ball.dy) * 0.25,
              ),
            );
          },
          child: CustomPaint(
            painter: GamePainter(widget.run),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class GamePainter extends CustomPainter {
  GamePainter(this.run);

  final GameRun run;

  @override
  void paint(Canvas canvas, Size size) {
    final board = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final pulse = run.elapsed.inMilliseconds / 1000;
    _drawArenaCourt(canvas, size, board, pulse);
    if (run.impactPulse > 0) {
      canvas.drawRRect(
        board.deflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + run.impactPulse * 3
          ..color = const Color(
            0xffffd166,
          ).withValues(alpha: run.impactPulse * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    final goal = run.level.goalRect(size, run.elapsed);
    final swish = Curves.easeOutCubic.transform(run.winAnimation.clamp(0, 1));
    final rimGlow = run.won ? 1 - (swish - 0.35).clamp(0, 1) : 0.0;
    final netSwing =
        run.won ? math.sin(swish * math.pi * 3) * (1 - swish) * 12 : 0.0;
    final backboard = Rect.fromCenter(
      center: Offset(goal.center.dx, goal.center.dy - 34),
      width: goal.width * 1.55,
      height: 34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        backboard.translate(0, 6).inflate(4),
        const Radius.circular(8),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(backboard, const Radius.circular(4)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.92),
            const Color(0xffb7d9ff).withValues(alpha: 0.58),
            Colors.white.withValues(alpha: 0.75),
          ],
        ).createShader(backboard),
    );
    canvas.drawLine(
      backboard.topLeft + const Offset(8, 6),
      backboard.topRight + const Offset(-18, 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(backboard.deflate(6), const Radius.circular(3)),
      Paint()
        ..color = const Color(0xff1e293b).withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(goal.left + goal.width * 0.15, goal.center.dy),
      Offset(goal.right - goal.width * 0.15, goal.center.dy),
      Paint()
        ..color =
            Color.lerp(
              const Color(0xffff5a36),
              const Color(0xffffd166),
              (math.sin(pulse * 5) + 1) / 2,
            )!
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7 + rimGlow * 4,
    );
    if (rimGlow > 0) {
      canvas.drawCircle(
        goal.center,
        goal.width * (0.36 + swish * 0.12),
        Paint()
          ..color = const Color(0xffffd166).withValues(alpha: rimGlow * 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(
        center: goal.center,
        width: goal.width * 0.78,
        height: goal.height * 0.45,
      ),
      Paint()
        ..color = const Color(0xfffff1c7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final netPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.48)
          ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      final x = goal.left + goal.width * (0.2 + t * 0.6);
      final wave = math.sin(t * math.pi + swish * math.pi * 3) * netSwing;
      canvas.drawLine(
        Offset(x, goal.center.dy + 3),
        Offset(
          goal.center.dx + (x - goal.center.dx) * 0.42 + wave,
          goal.bottom + swish * goal.height * 0.75,
        ),
        netPaint,
      );
    }
    _drawRimShadow(canvas, goal);

    for (final obstacle in run.obstacles) {
      _drawObstacle(canvas, size, obstacle);
    }

    for (var i = 0; i < run.level.coinTargets.length; i++) {
      if (run.collectedCoinIndexes.contains(i)) continue;
      _drawBonusCoin(canvas, size, run.level.coinTargets[i], pulse + i * 0.4);
    }

    for (var i = 0; i < run.level.keyTargets.length; i++) {
      if (run.collectedKeyIndexes.contains(i)) continue;
      _drawKey(canvas, size, run.level.keyTargets[i], pulse + i * 0.35);
    }

    for (final particle in run.particles) {
      final p = Offset(
        particle.position.dx * size.width,
        particle.position.dy * size.height,
      );
      canvas.drawCircle(
        p,
        particle.radius * size.shortestSide * (1 - particle.age),
        Paint()..color = particle.color.withValues(alpha: 1 - particle.age),
      );
    }

    final rawBall = Offset(run.ball.dx * size.width, run.ball.dy * size.height);
    final ball =
        run.won
            ? Offset(
              rawBall.dx + (goal.center.dx - rawBall.dx) * swish * 0.35,
              rawBall.dy + goal.height * 1.15 * swish,
            )
            : rawBall;
    if (!run.launched && !run.failed && !run.won) {
      final target =
          ball +
          Offset(run.aimVector.dx * size.width, run.aimVector.dy * size.height);
      final aimPaint =
          Paint()
            ..color = const Color(0xfffff1c7).withValues(alpha: 0.68)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round;
      canvas.drawLine(ball, target, aimPaint);
      canvas.drawCircle(target, 7, Paint()..color = const Color(0xffffd166));
    }
    for (var i = 0; i < run.trail.length; i++) {
      final item = run.trail[i];
      final t = i / math.max(1, run.trail.length - 1);
      final point = Offset(item.dx * size.width, item.dy * size.height);
      canvas.drawCircle(
        point,
        run.ballRadius * size.shortestSide * (0.35 + t * 0.62),
        Paint()
          ..color = Color.lerp(
            const Color(0xff38bdf8),
            const Color(0xffff8a2a),
            t,
          )!.withValues(alpha: t * 0.34)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
    final chaser = run.chaserPosition;
    if (chaser != null) {
      _drawChaser(canvas, size, chaser, pulse);
    }
    if (run.guideSeconds > 0 || run.slowMoSeconds > 0) {
      _drawPowerAura(canvas, size, ball, pulse);
    }
    canvas.drawCircle(
      ball + const Offset(0, 8),
      run.ballRadius * size.shortestSide * 1.05,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    if (run.launched && !run.won && !run.failed) {
      _drawSpeedFlare(canvas, size, ball, pulse);
    }
    canvas.drawCircle(
      ball,
      run.ballRadius * size.shortestSide * (1.22 - swish * 0.18),
      Paint()
        ..color = const Color(0xffff8a2a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    final ballRadius = run.ballRadius * size.shortestSide * (1 - swish * 0.16);
    canvas.drawCircle(
      ball,
      ballRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          colors: [Color(0xffffd28a), Color(0xffff8a2a), Color(0xff9a3d12)],
        ).createShader(Rect.fromCircle(center: ball, radius: ballRadius)),
    );
    final seam =
        Paint()
          ..color = const Color(0xff3f1a0a).withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;
    canvas.drawCircle(ball, ballRadius * 0.72, seam);
    canvas.drawLine(
      ball + Offset(-ballRadius, 0),
      ball + Offset(ballRadius, 0),
      seam,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: ball,
        width: ballRadius * 1.2,
        height: ballRadius * 2,
      ),
      -math.pi / 2,
      math.pi,
      false,
      seam,
    );
    canvas.drawCircle(
      ball + Offset(-ballRadius * 0.32, -ballRadius * 0.36),
      ballRadius * 0.20,
      Paint()..color = Colors.white.withValues(alpha: 0.38),
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: ball,
        width: ballRadius * 1.2,
        height: ballRadius * 2,
      ),
      math.pi / 2,
      math.pi,
      false,
      seam,
    );

    if (run.guideSeconds > 0 || run.slowMoSeconds > 0) {
      _drawPowerStatus(canvas, size, pulse);
    }

    if (run.won && run.winAnimation < 0.78) {
      _drawSwishNet(canvas, goal, swish, netSwing);
      _text(
        canvas,
        goal.center - Offset(0, goal.height * 1.35 + 22 * (1 - swish)),
        '+${run.score}',
        (16 + 6 * rimGlow).toDouble(),
        const Color(0xfffff1a8).withValues(alpha: 0.45 + rimGlow * 0.55),
        FontWeight.w900,
      );
    }

    if (run.failed || (run.won && run.winAnimation >= 0.78)) {
      if (run.won) {
        _drawWinResult(canvas, size, board);
      } else {
        canvas.drawRRect(
          board,
          Paint()..color = Colors.black.withValues(alpha: 0.38),
        );
        _text(
          canvas,
          size.center(Offset.zero) - const Offset(0, 28),
          'TEKRAR DENE',
          26,
          Colors.white,
          FontWeight.w900,
        );
        _text(
          canvas,
          size.center(Offset.zero) + const Offset(0, 18),
          'Bolumu yeniden baslatmak icin dokun',
          13,
          Colors.white70,
          FontWeight.w700,
        );
      }
    }
  }

  void _drawWinResult(Canvas canvas, Size size, RRect board) {
    final reveal = ((run.winAnimation - 0.78) / 0.22).clamp(0.0, 1.0);
    canvas.drawRRect(
      board,
      Paint()..color = Colors.black.withValues(alpha: 0.22 * reveal),
    );
    final panel = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: math.min(size.width * 0.84, 360),
      height: 190,
    );
    final panelRRect = RRect.fromRectAndRadius(
      panel,
      const Radius.circular(22),
    );
    canvas.drawRRect(
      panelRRect.shift(const Offset(0, 10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.36)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff1b2a28), Color(0xff102019), Color(0xff4a2b12)],
        ).createShader(panel),
    );
    canvas.drawRRect(
      panelRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xffffd166).withValues(alpha: 0.48),
    );
    _text(
      canvas,
      panel.topCenter + const Offset(0, 24),
      'BOLUM TAMAMLANDI',
      17,
      const Color(0xfffff1c7),
      FontWeight.w900,
    );
    _drawStars(canvas, panel.topCenter + const Offset(0, 62), run.starRating);
    _text(
      canvas,
      panel.center + const Offset(0, 8),
      '${run.score} PUAN',
      24,
      Colors.white,
      FontWeight.w900,
    );
    _drawResultRow(
      canvas,
      panel.left + 26,
      panel.bottom - 54,
      'Hiz',
      '${run.timeLeftSeconds}s kaldi',
      run.earnedTimeStar,
    );
    _drawResultRow(
      canvas,
      panel.left + panel.width * 0.37,
      panel.bottom - 54,
      'Kontrol',
      '${run.moves} hamle',
      run.earnedSkillStar,
    );
    _drawResultRow(
      canvas,
      panel.left + panel.width * 0.67,
      panel.bottom - 54,
      'Bonus',
      '${run.collectedCoins}/${run.totalBonusCoins}',
      run.earnedBonusStar,
    );
  }

  void _drawResultRow(
    Canvas canvas,
    double x,
    double y,
    String label,
    String value,
    bool earned,
  ) {
    final color = earned ? const Color(0xffffd166) : Colors.white38;
    _drawStar(canvas, Offset(x + 11, y + 11), 9, color);
    _text(
      canvas,
      Offset(x + 47, y + 6),
      label,
      11,
      Colors.white70,
      FontWeight.w800,
    );
    _text(canvas, Offset(x + 50, y + 25), value, 12, color, FontWeight.w900);
  }

  void _drawArenaCourt(Canvas canvas, Size size, RRect board, double pulse) {
    canvas.drawRRect(
      board,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xffb9793c), Color(0xff8d5427), Color(0xff5b3217)],
        ).createShader(Offset.zero & size),
    );

    for (var x = 0.0; x < size.width; x += size.width / 8) {
      final rect = Rect.fromLTWH(x, 0, size.width / 8, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(
                0xffffc072,
              ).withValues(alpha: x % 2 == 0 ? 0.20 : 0.08),
              Colors.black.withValues(alpha: x % 2 == 0 ? 0.04 : 0.12),
            ],
          ).createShader(rect),
      );
    }

    final grain =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.055)
          ..strokeWidth = 0.8;
    for (var y = 18.0; y < size.height; y += 28) {
      final wave = math.sin(y * 0.04 + pulse * 0.35) * 8;
      canvas.drawLine(Offset(wave, y), Offset(size.width + wave, y + 6), grain);
    }

    for (var i = 0; i < 4; i++) {
      final x = ((math.sin(pulse * 0.55 + i * 1.9) + 1) / 2) * size.width;
      final y = size.height * (0.12 + i * 0.10);
      canvas.drawCircle(
        Offset(x, y),
        size.width * (0.18 + i * 0.025),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xfffff1c7).withValues(alpha: 0.13),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(x, y), radius: size.width * 0.25),
          ),
      );
    }

    final courtLine =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.4);
    canvas.drawLine(
      Offset(0, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
      courtLine,
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.18,
      courtLine,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.88),
        width: size.width * 0.72,
        height: size.height * 0.32,
      ),
      math.pi,
      math.pi,
      false,
      courtLine,
    );

    canvas.drawRRect(
      board,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.18),
          radius: 1.05,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.34)],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawRimShadow(Canvas canvas, Rect goal) {
    canvas.drawOval(
      Rect.fromCenter(
        center: goal.center + const Offset(0, 9),
        width: goal.width * 0.82,
        height: goal.height * 0.50,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _drawSpeedFlare(Canvas canvas, Size size, Offset ball, double pulse) {
    final speed = run.velocity.distance.clamp(0.0, 1.8);
    if (speed < 0.18) return;
    final direction = run.velocity / math.max(0.001, run.velocity.distance);
    final tail = Offset(direction.dx * size.width, direction.dy * size.height);
    for (var i = 0; i < 4; i++) {
      final t = (i + 1) / 4;
      canvas.drawLine(
        ball - tail * (0.012 + t * 0.018),
        ball - tail * (0.036 + t * 0.035),
        Paint()
          ..color = const Color(
            0xffffd166,
          ).withValues(alpha: (1 - t) * 0.25 + speed * 0.08)
          ..strokeWidth = (5 - i).toDouble()
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.drawCircle(
      ball,
      run.ballRadius * size.shortestSide * (1.55 + math.sin(pulse * 12) * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(
          0xffffd166,
        ).withValues(alpha: 0.12 + speed * 0.08),
    );
  }

  void _drawChaser(Canvas canvas, Size size, Offset normalized, double pulse) {
    final center = Offset(
      normalized.dx * size.width,
      normalized.dy * size.height,
    );
    final radius = size.shortestSide * (0.040 + math.sin(pulse * 7) * 0.004);
    canvas.drawCircle(
      center,
      radius * 2.4,
      Paint()
        ..color = const Color(0xffef476f).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xffff9aae), Color(0xffef476f), Color(0xff5b1224)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * 1.15,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.38),
    );
    _text(canvas, center, '!', 17, Colors.white, FontWeight.w900);
  }

  void _drawPowerAura(Canvas canvas, Size size, Offset ball, double pulse) {
    final activeGuide = run.guideSeconds > 0;
    final activeSlow = run.slowMoSeconds > 0;
    final color =
        activeSlow ? const Color(0xff7dd3fc) : const Color(0xff19f5a8);
    final radius =
        run.ballRadius *
        size.shortestSide *
        (2.35 + math.sin(pulse * 8) * 0.18);
    canvas.drawCircle(
      ball,
      radius * 1.35,
      Paint()
        ..color = color.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawCircle(
      ball,
      radius,
      Paint()
        ..color = color.withValues(
          alpha: activeGuide && activeSlow ? 0.52 : 0.40,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8,
    );
    if (!activeGuide) return;
    final rim = run.level.goalAt(run.elapsed);
    final target = Offset(
      rim.center.dx * size.width,
      rim.center.dy * size.height,
    );
    canvas.drawLine(
      ball,
      target,
      Paint()
        ..color = const Color(0xff19f5a8).withValues(alpha: 0.22)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3,
    );
  }

  void _drawPowerStatus(Canvas canvas, Size size, double pulse) {
    final text =
        run.slowMoSeconds > 0
            ? 'ENGEL KIRILDI'
            : run.guideSeconds > 0
            ? 'ROTA DESTEGI'
            : '';
    if (text.isEmpty) return;
    final rect = Rect.fromLTWH(size.width * 0.34, 10, size.width * 0.32, 24);
    final color =
        run.slowMoSeconds > 0
            ? const Color(0xff7dd3fc)
            : const Color(0xff19f5a8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      Paint()
        ..color = color.withValues(
          alpha: 0.24 + math.sin(pulse * 8).abs() * 0.08,
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(999)),
      Paint()
        ..color = color.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _text(canvas, rect.center, text, 11, Colors.white, FontWeight.w900);
  }

  void _drawStars(Canvas canvas, Offset center, int stars) {
    for (var i = 0; i < 3; i++) {
      final starCenter = center + Offset((i - 1) * 34.0, 4);
      final active = i < stars;
      _drawStar(
        canvas,
        starCenter,
        active ? 13 : 11,
        active ? const Color(0xffffd166) : Colors.white.withValues(alpha: 0.25),
      );
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawSwishNet(Canvas canvas, Rect goal, double swish, double netSwing) {
    final paint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.78 * (1 - swish * 0.45))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
    final bottom = goal.bottom + goal.height * (0.85 + swish * 0.65);
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final t = i / 4;
      final top = Offset(
        goal.left + goal.width * (0.22 + t * 0.56),
        goal.center.dy + 3,
      );
      final wave = math.sin(t * math.pi + swish * math.pi * 3) * netSwing;
      path
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          goal.center.dx + (top.dx - goal.center.dx) * 0.3 + wave,
          goal.center.dy + goal.height * 0.58,
          goal.center.dx + (top.dx - goal.center.dx) * 0.12 + wave * 0.5,
          bottom,
        );
    }
    canvas.drawPath(path, paint);
  }

  void _drawObstacle(Canvas canvas, Size size, GameObstacle obstacle) {
    final rect = obstacle.rectFor(size);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    if (obstacle.open && obstacle.kind != ObstacleKind.gate) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xff7dd3fc).withValues(alpha: 0.32),
      );
      for (var i = 0; i < 4; i++) {
        final t = (i + 1) / 5;
        canvas.drawLine(
          Offset(rect.left + rect.width * t, rect.top + 3),
          Offset(rect.left + rect.width * (1 - t * 0.35), rect.bottom - 3),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.18)
            ..strokeWidth = 1.2,
        );
      }
      _text(canvas, rect.center, 'KIRIK', 10, Colors.white54, FontWeight.w800);
      return;
    }
    final baseColor = switch (obstacle.kind) {
      ObstacleKind.gate =>
        obstacle.open ? const Color(0xff264653) : const Color(0xffe63966),
      ObstacleKind.wall => const Color(0xff4b5563),
      ObstacleKind.bumper => const Color(0xffffb703),
      ObstacleKind.fanLeft || ObstacleKind.fanRight => const Color(0xff7b61ff),
      ObstacleKind.boost => const Color(0xff38bdf8),
      ObstacleKind.gravity => const Color(0xff19f5a8),
    };
    canvas.drawRRect(
      rrect.shift(const Offset(0, 5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              baseColor,
              Colors.white,
              0.22,
            )!.withValues(alpha: obstacle.open ? 0.38 : 0.96),
            baseColor.withValues(alpha: obstacle.open ? 0.34 : 0.92),
            Color.lerp(
              baseColor,
              Colors.black,
              0.35,
            )!.withValues(alpha: obstacle.open ? 0.32 : 0.94),
          ],
        ).createShader(rect)
        ..maskFilter =
            obstacle.open ? null : const MaskFilter.blur(BlurStyle.normal, 1),
    );
    if (!obstacle.open) {
      final shineX =
          rect.left +
          rect.width *
              ((math.sin(run.elapsed.inMilliseconds / 450 + rect.left) + 1) /
                  2);
      canvas.drawLine(
        Offset(shineX, rect.top + 3),
        Offset(
          (shineX + rect.width * 0.22).clamp(rect.left, rect.right),
          rect.bottom - 3,
        ),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.16)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = obstacle.kind == ObstacleKind.gate ? 2.8 : 2
        ..color = (obstacle.kind == ObstacleKind.gate
                ? const Color(0xffffd166)
                : Colors.white)
            .withValues(alpha: obstacle.open ? 0.16 : 0.30),
    );
    if (obstacle.kind == ObstacleKind.gravity && !obstacle.open) {
      canvas.drawCircle(
        rect.center,
        rect.shortestSide *
            (0.55 + math.sin(run.elapsed.inMilliseconds / 180) * 0.05),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xff19f5a8).withValues(alpha: 0.34),
      );
    }
    final label = switch (obstacle.kind) {
      ObstacleKind.gate => obstacle.open ? 'ACIK' : 'KAPI',
      ObstacleKind.wall => 'DUVAR',
      ObstacleKind.bumper => 'ZIP',
      ObstacleKind.fanLeft => '<<<',
      ObstacleKind.fanRight => '>>>',
      ObstacleKind.boost => 'HIZ',
      ObstacleKind.gravity => 'CEK',
    };
    _text(canvas, rect.center, label, 11, Colors.white, FontWeight.w800);
  }

  void _drawBonusCoin(
    Canvas canvas,
    Size size,
    Offset normalized,
    double pulse,
  ) {
    final center = Offset(
      normalized.dx * size.width,
      normalized.dy * size.height,
    );
    final radius = size.shortestSide * (0.020 + math.sin(pulse * 5) * 0.002);
    canvas.drawCircle(
      center,
      radius * 1.85,
      Paint()
        ..color = const Color(0xffffd166).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.35),
          colors: [Color(0xfffff1a8), Color(0xffffb703), Color(0xffb45309)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    _text(canvas, center, '+', 13, const Color(0xff4a2a00), FontWeight.w900);
  }

  void _drawKey(Canvas canvas, Size size, Offset normalized, double pulse) {
    final center = Offset(
      normalized.dx * size.width,
      normalized.dy * size.height,
    );
    final glow =
        Paint()
          ..color = const Color(0xffffd166).withValues(alpha: 0.24)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, size.shortestSide * 0.042, glow);
    final paint =
        Paint()
          ..color =
              Color.lerp(
                const Color(0xfffff1a8),
                const Color(0xffffb703),
                (math.sin(pulse * 5) + 1) / 2,
              )!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    final r = size.shortestSide * 0.018;
    canvas.drawCircle(center + Offset(-r * 1.2, 0), r, paint);
    canvas.drawLine(center, center + Offset(r * 2.4, 0), paint);
    canvas.drawLine(
      center + Offset(r * 1.25, 0),
      center + Offset(r * 1.25, r * 0.85),
      paint,
    );
    canvas.drawLine(
      center + Offset(r * 2.05, 0),
      center + Offset(r * 2.05, r * 0.62),
      paint,
    );
  }

  void _text(
    Canvas canvas,
    Offset center,
    String text,
    double size,
    Color color,
    FontWeight weight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}

class GameRun {
  GameRun({required this.level})
    : obstacles = level.obstacles.map((item) => item.copy()).toList(),
      ball = Offset(level.dropX, 0.20),
      velocity = Offset.zero;

  final GameLevel level;
  final List<GameObstacle> obstacles;
  final List<Offset> trail = [];
  final List<GameParticle> particles = [];
  final Set<int> collectedCoinIndexes = {};
  final Set<int> collectedKeyIndexes = {};
  Offset ball;
  Offset velocity;
  Offset aimVector = const Offset(0.10, 0.36);
  bool launched = false;
  int moves = 0;
  int nudges = 0;
  int bonusNudges = 0;
  int bonusSeconds = 0;
  int bonusKeys = 0;
  double guideSeconds = 0;
  double slowMoSeconds = 0;
  int usedKeys = 0;
  bool won = false;
  bool failed = false;
  double winAnimation = 0;
  double impactPulse = 0;
  double _stuckSeconds = 0;
  Offset _stuckProbe = Offset.zero;
  final Stopwatch _clock = Stopwatch()..start();
  double get ballRadius => (0.023 + level.index * 0.00012).clamp(0.023, 0.034);
  int get maxNudges => math.max(4, 7 - (level.index ~/ 28)) + bonusNudges;
  int get remainingNudges => math.max(0, maxNudges - nudges);
  int get shotClockSeconds =>
      math.max(20, 28 - (level.index ~/ 16)) + bonusSeconds;
  int get timeLeftSeconds =>
      launched
          ? math.max(0, shotClockSeconds - elapsed.inSeconds)
          : shotClockSeconds;
  bool get perfectShot => moves <= 2 && nudges <= 2;
  bool get earnedTimeStar =>
      won && timeLeftSeconds >= (shotClockSeconds * 0.28).round();
  bool get earnedSkillStar => won && moves <= 3 + level.index ~/ 35;
  bool get earnedBonusStar =>
      won &&
      collectedCoins >= math.max(1, (totalBonusCoins * 0.60).ceil()) &&
      nudges <= math.max(2, maxNudges - 2);
  int get starRating {
    if (!won) return 0;
    var stars = 1;
    if (earnedTimeStar && earnedSkillStar) stars++;
    if (earnedBonusStar) stars++;
    return stars.clamp(1, 3);
  }

  int get collectedCoins => collectedCoinIndexes.length;
  int get totalBonusCoins => level.coinTargets.length;
  int get gateCount =>
      obstacles.where((item) => item.kind == ObstacleKind.gate).length;
  int get starterKeys => 0;

  int get availableKeys => math.max(
    0,
    starterKeys + collectedKeyIndexes.length + bonusKeys - usedKeys,
  );
  int get totalKeys => starterKeys + level.keyTargets.length + bonusKeys;

  Duration get elapsed => _clock.elapsed;

  int get score {
    final timePenalty =
        elapsed.inMilliseconds ~/ (75 - level.index).clamp(42, 75);
    final movePenalty = moves * (95 + level.index * 14);
    final nudgePenalty = nudges * (135 + level.index * 18);
    final perfectBonus = perfectShot && won ? 900 + level.index * 120 : 0;
    final clutchBonus = remainingNudges == 0 && won ? 450 : 0;
    final coinBonus = collectedCoins * (320 + level.index * 35);
    final levelBonus = 1000 + level.index * 420;
    return math.max(
      50,
      6000 +
          levelBonus +
          perfectBonus +
          clutchBonus +
          coinBonus -
          timePenalty -
          movePenalty -
          nudgePenalty,
    );
  }

  void tapObstacle(String id) {
    if (won || failed) return;
    final index = obstacles.indexWhere((item) => item.id == id);
    if (index == -1 || !obstacles[index].isTapTarget) return;
    if (obstacles[index].open) return;
    if (availableKeys <= 0) {
      _burst(
        obstacles[index].normalized.center,
        const Color(0xffff5d73),
        count: 5,
      );
      return;
    }
    usedKeys++;
    obstacles[index] = obstacles[index].copy(open: true);
    moves++;
    _burst(obstacles[index].normalized.center, const Color(0xff19f5a8));
  }

  void collectKey(int index) {
    if (won || failed || collectedKeyIndexes.contains(index)) return;
    collectedKeyIndexes.add(index);
    _burst(level.keyTargets[index], const Color(0xffffd166), count: 12);
  }

  void aim(Offset force) {
    if (won || failed || launched) return;
    aimVector = Offset(force.dx.clamp(-0.42, 0.42), force.dy.clamp(0.07, 0.64));
  }

  void shoot(Offset force) {
    if (won || failed || launched) return;
    aim(force);
    launched = true;
    moves++;
    _clock
      ..reset()
      ..start();
    velocity = Offset(
      aimVector.dx * (1.86 + level.index * 0.018).clamp(1.86, 3.08) +
          level.startVX,
      aimVector.dy * (1.16 + level.index * 0.010).clamp(1.16, 2.02),
    );
    _burst(ball, const Color(0xffffd166), count: 12);
  }

  void nudge(Offset force) {
    if (won || failed || !launched) return;
    if (remainingNudges <= 0) {
      _burst(ball, const Color(0xffff5d73), count: 3);
      return;
    }
    nudges++;
    final strength = (0.90 + level.index * 0.010).clamp(0.90, 1.42);
    velocity += Offset(
      force.dx.clamp(-0.038, 0.038) * strength,
      force.dy.clamp(-0.034, 0.024) * strength,
    );
    _burst(ball, const Color(0xff7dd3fc), count: 4);
  }

  void addControlJoker() {
    if (won || failed) return;
    bonusNudges += 1;
    guideSeconds = math.max(guideSeconds, 5.5);
    final rim = level.goalAt(elapsed).center;
    final direction = rim - ball;
    final length = math.max(0.001, direction.distance);
    final guideVelocity = Offset(
      direction.dx / length * 0.76,
      direction.dy / length * 0.58,
    );
    velocity = launched ? velocity * 0.38 + guideVelocity : guideVelocity;
    _burst(ball, const Color(0xff19f5a8), count: 24);
  }

  void addBreakerJoker() {
    if (won || failed) return;
    final targetKinds = {
      ObstacleKind.wall,
      ObstacleKind.bumper,
      ObstacleKind.fanLeft,
      ObstacleKind.fanRight,
      ObstacleKind.gravity,
    };
    var nearestIndex = -1;
    var nearestDistance = double.infinity;
    for (var i = 0; i < obstacles.length; i++) {
      final obstacle = obstacles[i];
      if (obstacle.open || !targetKinds.contains(obstacle.kind)) continue;
      final center = obstacle.normalized.center;
      final towardGoal =
          level.goal.center.dy >= center.dy || center.dy > ball.dy;
      if (!towardGoal) continue;
      final distance = (center - ball).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    if (nearestIndex == -1) {
      slowMoSeconds = math.max(slowMoSeconds, 2.0);
      _burst(ball, const Color(0xff7dd3fc), count: 12);
      return;
    }
    final obstacle = obstacles[nearestIndex];
    obstacles[nearestIndex] = obstacle.copy(open: true);
    moves++;
    slowMoSeconds = math.max(slowMoSeconds, 1.4);
    _burst(obstacle.normalized.center, const Color(0xff7dd3fc), count: 26);
    _burst(ball, const Color(0xff7dd3fc), count: 12);
  }

  void openGateJoker() {
    if (won || failed) return;
    var nearestGateIndex = -1;
    var nearestDistance = double.infinity;
    for (var i = 0; i < obstacles.length; i++) {
      final obstacle = obstacles[i];
      if (obstacle.kind != ObstacleKind.gate || obstacle.open) continue;
      final distance = (obstacle.normalized.center - ball).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestGateIndex = i;
      }
    }
    if (nearestGateIndex == -1) {
      bonusKeys++;
      _burst(ball, const Color(0xffffd166), count: 14);
      return;
    }
    obstacles[nearestGateIndex] = obstacles[nearestGateIndex].copy(open: true);
    moves++;
    _burst(
      obstacles[nearestGateIndex].normalized.center,
      const Color(0xffffd166),
      count: 26,
    );
    _burst(ball, const Color(0xffffd166), count: 10);
  }

  bool step(double dt) {
    _ageParticles(dt);
    if (won) {
      winAnimation = (winAnimation + dt * 1.55).clamp(0, 1);
      return particles.isNotEmpty || winAnimation < 1;
    }
    if (failed) return particles.isNotEmpty;
    if (!launched) return true;
    if (elapsed.inSeconds >= shotClockSeconds) {
      failed = true;
      _clock.stop();
      _burst(ball, const Color(0xffff5d73), count: 18);
      return true;
    }

    _applyPowerUps(dt);
    _applyChaserPressure(dt);
    final gravityScale = slowMoSeconds > 0 ? 0.42 : 1.0;
    velocity +=
        Offset(0, (0.56 + level.index * 0.003).clamp(0.56, 0.86) * dt) *
        gravityScale;
    velocity = Offset(
      velocity.dx * (1 - 0.10 * dt),
      velocity.dy * (1 - 0.025 * dt),
    );
    var next = ball + velocity * dt;
    final radius = ballRadius;

    if (next.dx < radius || next.dx > 1 - radius) {
      velocity = Offset(-velocity.dx * 0.72, velocity.dy);
      next = Offset(next.dx.clamp(radius, 1 - radius), next.dy);
      _burst(next, const Color(0xff59a7ff));
    }

    for (
      var obstacleIndex = 0;
      obstacleIndex < obstacles.length;
      obstacleIndex++
    ) {
      final obstacle = obstacles[obstacleIndex];
      if (obstacle.open) continue;
      if (obstacle.kind == ObstacleKind.fanLeft &&
          obstacle.normalized.inflate(radius).contains(next)) {
        velocity += Offset(-0.42 * dt, -0.06 * dt);
        continue;
      }
      if (obstacle.kind == ObstacleKind.fanRight &&
          obstacle.normalized.inflate(radius).contains(next)) {
        velocity += Offset(0.42 * dt, -0.06 * dt);
        continue;
      }
      if (obstacle.kind == ObstacleKind.boost &&
          obstacle.normalized.inflate(radius).contains(next)) {
        final towardHoop = level.goal.center.dx >= next.dx ? 1.0 : -1.0;
        velocity += Offset(towardHoop * 0.50 * dt, -0.18 * dt);
        _burst(next, const Color(0xff38bdf8), count: 2);
        continue;
      }
      if (obstacle.kind == ObstacleKind.gravity &&
          obstacle.normalized.inflate(radius).contains(next)) {
        final pull = obstacle.normalized.center - next;
        velocity += Offset(pull.dx * 0.95 * dt, pull.dy * 0.46 * dt);
        continue;
      }
      final rect = obstacle.normalized.inflate(radius * 0.72);
      if (!rect.contains(next)) continue;
      if (obstacle.kind == ObstacleKind.gate && availableKeys > 0) {
        usedKeys++;
        moves++;
        obstacles[obstacleIndex] = obstacle.copy(open: true);
        _burst(obstacle.normalized.center, const Color(0xff19f5a8), count: 14);
        _burst(next, const Color(0xffffd166), count: 8);
        continue;
      }
      if (obstacle.kind == ObstacleKind.bumper) {
        if (ball.dy > rect.center.dy && velocity.dy < 0) {
          velocity = Offset(
            velocity.dx * 0.92,
            velocity.dy.abs() * 0.70 + 0.10,
          );
          next = Offset(next.dx, rect.bottom + radius * 1.2);
        } else {
          velocity = Offset(
            velocity.dx * 1.10,
            -velocity.dy.abs() * 0.98 - 0.16,
          );
          next = Offset(next.dx, rect.top - radius * 1.2);
        }
        _burst(next, const Color(0xffffd166), count: 12);
        continue;
      }
      next = _resolveSolidCollision(rect, next, radius);
      _burst(next, const Color(0xffef476f));
    }

    for (var i = 0; i < level.coinTargets.length; i++) {
      if (collectedCoinIndexes.contains(i)) continue;
      final target = level.coinTargets[i];
      if ((next - target).distance <= radius * 2.6) {
        collectedCoinIndexes.add(i);
        _burst(target, const Color(0xffffd166), count: 14);
      }
    }

    for (var i = 0; i < level.keyTargets.length; i++) {
      if (collectedKeyIndexes.contains(i)) continue;
      final target = level.keyTargets[i];
      if ((next - target).distance <= radius * 3.0) {
        collectedKeyIndexes.add(i);
        _burst(target, const Color(0xffffd166), count: 12);
      }
    }

    final rim = level.goalAt(elapsed);
    final crossedRim =
        ball.dy < rim.center.dy &&
        next.dy >= rim.center.dy &&
        next.dx > rim.left + radius &&
        next.dx < rim.right - radius &&
        velocity.dy > 0.05;
    if (crossedRim) {
      won = true;
      _clock.stop();
      next = Offset(next.dx, rim.center.dy + radius);
      _burst(next, const Color(0xff19f5a8), count: 18);
      _burst(rim.center, const Color(0xffffd166), count: 16);
    }

    if (!won && next.dy >= 0.985) {
      failed = true;
      _clock.stop();
      next = Offset(next.dx, 0.985);
      _burst(next, const Color(0xffff5d73), count: 18);
    }

    ball = next;
    _unstickIfNeeded(dt);
    trail.add(ball);
    if (trail.length > 18) trail.removeAt(0);
    return true;
  }

  Offset? get chaserPosition {
    if (!level.hasChaser || !launched || won || failed) return null;
    final seconds = elapsed.inMilliseconds / 1000;
    final y = (-0.10 + (seconds - 2.2) * level.chaserSpeed).clamp(-0.12, 0.92);
    if (y < -0.04) return null;
    final x =
        (level.dropX + math.sin(seconds * 1.35 + level.index) * 0.13)
            .clamp(0.10, 0.90)
            .toDouble();
    return Offset(x, y);
  }

  void _applyChaserPressure(double dt) {
    final chaser = chaserPosition;
    if (chaser == null) return;
    final distance = (ball - chaser).distance;
    if (distance > ballRadius * 3.4) return;
    final away = ball - chaser;
    final length = math.max(0.001, away.distance);
    velocity += Offset(away.dx / length * 0.40, -0.10) * dt * 4;
    if (distance < ballRadius * 1.55) {
      failed = true;
      _clock.stop();
      _burst(ball, const Color(0xffef476f), count: 20);
    }
  }

  void _applyPowerUps(double dt) {
    if (slowMoSeconds > 0) {
      slowMoSeconds = math.max(0, slowMoSeconds - dt);
      velocity *= (1 - 0.82 * dt).clamp(0.0, 1.0);
    }
    if (guideSeconds <= 0) return;
    guideSeconds = math.max(0, guideSeconds - dt);
    final rim = level.goalAt(elapsed).center;
    final direction = rim - ball;
    final length = math.max(0.001, direction.distance);
    velocity +=
        Offset(direction.dx / length * 0.78, direction.dy / length * 0.34) * dt;
    if (velocity.distance > 1.45) {
      velocity = Offset(
        velocity.dx / velocity.distance * 1.45,
        velocity.dy / velocity.distance * 1.45,
      );
    }
  }

  Offset _resolveSolidCollision(Rect rect, Offset next, double radius) {
    final left = (next.dx - rect.left).abs();
    final right = (rect.right - next.dx).abs();
    final top = (next.dy - rect.top).abs();
    final bottom = (rect.bottom - next.dy).abs();
    final minDistance = math.min(math.min(left, right), math.min(top, bottom));
    final escape = radius * 1.35;
    if (minDistance == top) {
      velocity = Offset(velocity.dx * 0.90, -velocity.dy.abs() * 0.58 - 0.035);
      return Offset(next.dx, rect.top - escape);
    }
    if (minDistance == bottom) {
      velocity = Offset(velocity.dx * 0.90, velocity.dy.abs() * 0.58 + 0.035);
      return Offset(next.dx, rect.bottom + escape);
    }
    if (minDistance == left) {
      velocity = Offset(-velocity.dx.abs() * 0.70 - 0.045, velocity.dy * 0.94);
      return Offset(rect.left - escape, next.dy);
    }
    velocity = Offset(velocity.dx.abs() * 0.70 + 0.045, velocity.dy * 0.94);
    return Offset(rect.right + escape, next.dy);
  }

  void _unstickIfNeeded(double dt) {
    final speed = velocity.distance;
    final moved = (ball - _stuckProbe).distance;
    if (moved > 0.020 || speed > 0.16) {
      _stuckSeconds = 0;
      _stuckProbe = ball;
      return;
    }
    _stuckSeconds += dt;
    if (_stuckSeconds < 0.50) return;
    final rim = level.goalAt(elapsed).center;
    final direction = rim - ball;
    final length = math.max(0.001, direction.distance);
    ball = Offset(
      (ball.dx + direction.dx / length * 0.018).clamp(0.04, 0.96),
      (ball.dy - 0.018).clamp(0.06, 0.94),
    );
    velocity += Offset(direction.dx / length * 0.22, -0.16);
    _burst(ball, const Color(0xff7dd3fc), count: 8);
    _stuckSeconds = 0;
    _stuckProbe = ball;
  }

  void _burst(Offset center, Color color, {int count = 8}) {
    impactPulse = math.max(impactPulse, 0.65);
    final random = math.Random(center.hashCode + moves);
    for (var i = 0; i < count; i++) {
      particles.add(
        GameParticle(
          position: center,
          velocity: Offset(
            (random.nextDouble() - 0.5) * 0.42,
            (random.nextDouble() - 0.5) * 0.42,
          ),
          color: color,
          radius: 0.012 + random.nextDouble() * 0.012,
        ),
      );
    }
  }

  void _ageParticles(double dt) {
    impactPulse = math.max(0, impactPulse - dt * 1.8);
    for (final particle in particles) {
      particle.age += dt * 1.8;
      particle.position += particle.velocity * dt;
    }
    particles.removeWhere((particle) => particle.age >= 1);
  }
}

class GameParticle {
  GameParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.radius,
  });

  Offset position;
  final Offset velocity;
  final Color color;
  final double radius;
  double age = 0;
}

class GameLevel {
  const GameLevel({
    required this.index,
    required this.name,
    required this.hint,
    required this.dropX,
    required this.startVX,
    required this.goal,
    required this.obstacles,
    this.hoopMotion = 0,
    this.hoopSpeed = 0,
  });

  final int index;
  final String name;
  final String hint;
  final double dropX;
  final double startVX;
  final Rect goal;
  final List<GameObstacle> obstacles;
  final double hoopMotion;
  final double hoopSpeed;

  List<Offset> get coinTargets {
    final count = math.min(5, 2 + index ~/ 6);
    final pattern = switch (index % 4) {
      0 => const [
        Offset(0.28, 0.30),
        Offset(0.55, 0.44),
        Offset(0.72, 0.58),
        Offset(0.42, 0.74),
        Offset(0.64, 0.82),
      ],
      1 => const [
        Offset(0.66, 0.28),
        Offset(0.46, 0.42),
        Offset(0.30, 0.54),
        Offset(0.60, 0.72),
        Offset(0.36, 0.80),
      ],
      2 => const [
        Offset(0.44, 0.30),
        Offset(0.62, 0.44),
        Offset(0.74, 0.58),
        Offset(0.46, 0.70),
        Offset(0.25, 0.80),
      ],
      _ => const [
        Offset(0.58, 0.30),
        Offset(0.38, 0.43),
        Offset(0.24, 0.56),
        Offset(0.52, 0.70),
        Offset(0.69, 0.80),
      ],
    };
    return pattern.take(count).toList();
  }

  List<Offset> get keyTargets {
    final gates =
        obstacles.where((item) => item.kind == ObstacleKind.gate).toList();
    if (gates.isEmpty) return const [];
    return List.generate(gates.length, (keyIndex) {
      final gate = gates[keyIndex].normalized;
      final easy = index < 8;
      final side = keyIndex.isEven ? -1.0 : 1.0;
      final drift = easy ? 0.015 : (0.055 + (index / 160).clamp(0.0, 0.055));
      final verticalGap =
          easy ? 0.050 : (0.070 + (index / 180).clamp(0.0, 0.060));
      final aboveY = gate.top - verticalGap;
      final belowY = gate.bottom + verticalGap;
      final y =
          aboveY > 0.11
              ? aboveY
              : belowY < 0.82
              ? belowY
              : gate.center.dy;
      final x = gate.center.dx + side * drift * ((keyIndex % 3) + 1);
      return Offset(x.clamp(0.10, 0.90), y.clamp(0.12, 0.82));
    });
  }

  bool get hasChaser => index >= 24 && (index + 1) % 10 == 0;
  double get chaserSpeed => (0.030 + (index / 220)).clamp(0.030, 0.070);

  Rect goalAt(Duration elapsed) {
    if (hoopMotion == 0 || hoopSpeed == 0) return goal;
    final offset =
        math.sin(elapsed.inMilliseconds / 1000 * hoopSpeed * math.pi * 2) *
        hoopMotion;
    return goal.shift(Offset(offset, 0));
  }

  Rect goalRect(Size size, Duration elapsed) {
    final current = goalAt(elapsed);
    return Rect.fromLTRB(
      current.left * size.width,
      current.top * size.height,
      current.right * size.width,
      current.bottom * size.height,
    );
  }

  static final List<GameLevel> samples = [
    ..._baseSamples,
    for (var index = 10; index < 100; index++) _generatedLevel(index),
  ];

  static const List<GameLevel> _baseSamples = [
    GameLevel(
      index: 0,
      name: 'Ilk Basket',
      hint: 'Topu surukle, bonuslari topla ve potaya yumusak indir.',
      dropX: 0.30,
      startVX: 0.08,
      goal: Rect.fromLTWH(0.56, 0.88, 0.26, 0.065),
      obstacles: [
        GameObstacle(
          id: 'rampa',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.20, 0.42, 0.48, 0.045),
        ),
      ],
    ),
    GameLevel(
      index: 1,
      name: 'Ziplama Hatti',
      hint: 'Kapilar kolay. Sari tampon topu potaya yumusatir.',
      dropX: 0.76,
      startVX: -0.08,
      goal: Rect.fromLTWH(0.12, 0.88, 0.25, 0.062),
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.30, 0.34, 0.42, 0.045),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.42, 0.62, 0.22, 0.04),
        ),
        GameObstacle(
          id: 'd',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.18, 0.73, 0.42, 0.045),
        ),
      ],
    ),
    GameLevel(
      index: 2,
      name: 'Ruzgar Odasi',
      hint: 'Mor alan hafif iter. Kapilari ac, ruzgari yardimci kullan.',
      dropX: 0.50,
      startVX: 0.03,
      goal: Rect.fromLTWH(0.38, 0.88, 0.24, 0.062),
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.08, 0.30, 0.30, 0.045),
        ),
        GameObstacle(
          id: 'fan',
          kind: ObstacleKind.fanRight,
          normalized: Rect.fromLTWH(0.18, 0.46, 0.24, 0.09),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.34, 0.64, 0.42, 0.045),
        ),
        GameObstacle(
          id: 'boost',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.22, 0.74, 0.24, 0.05),
        ),
        GameObstacle(
          id: 'd',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.55, 0.76, 0.22, 0.04),
        ),
      ],
    ),
    GameLevel(
      index: 3,
      name: 'Cift Rota',
      hint: 'Hiz seridini yakala, tamponla yumusat ve genis potaya indir.',
      dropX: 0.22,
      startVX: 0.10,
      goal: Rect.fromLTWH(0.64, 0.87, 0.27, 0.066),
      hoopMotion: 0.0,
      hoopSpeed: 0.0,
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.30, 0.34, 0.34, 0.034),
        ),
        GameObstacle(
          id: 'wall1',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.58, 0.42, 0.24, 0.034),
        ),
        GameObstacle(
          id: 'b',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.14, 0.54, 0.42, 0.046),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.44, 0.70, 0.24, 0.038),
        ),
      ],
    ),
    GameLevel(
      index: 4,
      name: 'Dar Kuyu',
      hint: 'Az hamle daha cok skor. Kapilari gereksiz acma.',
      dropX: 0.82,
      startVX: -0.20,
      goal: Rect.fromLTWH(0.08, 0.90, 0.20, 0.06),
      hoopMotion: 0.035,
      hoopSpeed: 0.24,
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.42, 0.32, 0.40, 0.045),
        ),
        GameObstacle(
          id: 'b',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.10, 0.31, 0.46, 0.045),
        ),
        GameObstacle(
          id: 'bumper',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.38, 0.46, 0.22, 0.04),
        ),
        GameObstacle(
          id: 'wall1',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.68, 0.40, 0.055, 0.30),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.gate,
          normalized: Rect.fromLTWH(0.45, 0.58, 0.42, 0.045),
        ),
        GameObstacle(
          id: 'd',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.12, 0.73, 0.40, 0.045),
        ),
      ],
    ),
    GameLevel(
      index: 5,
      name: 'Final Labirenti',
      hint: 'Ruzgar ve tamponu birlikte kullan, hedef dar.',
      dropX: 0.50,
      startVX: 0.16,
      goal: Rect.fromLTWH(0.40, 0.90, 0.20, 0.06),
      hoopMotion: 0.045,
      hoopSpeed: 0.28,
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.07, 0.17, 0.31, 0.045),
        ),
        GameObstacle(
          id: 'b',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.62, 0.17, 0.31, 0.045),
        ),
        GameObstacle(
          id: 'fan1',
          kind: ObstacleKind.fanRight,
          normalized: Rect.fromLTWH(0.15, 0.34, 0.25, 0.10),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.gate,
          normalized: Rect.fromLTWH(0.22, 0.48, 0.56, 0.045),
        ),
        GameObstacle(
          id: 'fan2',
          kind: ObstacleKind.fanLeft,
          normalized: Rect.fromLTWH(0.60, 0.61, 0.25, 0.10),
        ),
        GameObstacle(
          id: 'wall1',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.47, 0.58, 0.055, 0.25),
        ),
        GameObstacle(
          id: 'd',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.40, 0.76, 0.20, 0.04),
        ),
      ],
    ),
    GameLevel(
      index: 6,
      name: 'Pota Arkasi',
      hint: 'Topu once yan duvardan sektir, sonra dar cembere indir.',
      dropX: 0.16,
      startVX: 0.22,
      goal: Rect.fromLTWH(0.67, 0.86, 0.18, 0.055),
      hoopMotion: 0.050,
      hoopSpeed: 0.32,
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.30, 0.16, 0.48, 0.04),
        ),
        GameObstacle(
          id: 'fan',
          kind: ObstacleKind.fanRight,
          normalized: Rect.fromLTWH(0.10, 0.34, 0.25, 0.11),
        ),
        GameObstacle(
          id: 'b',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.46, 0.48, 0.40, 0.04),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.22, 0.67, 0.20, 0.04),
        ),
      ],
    ),
    GameLevel(
      index: 7,
      name: 'Ruzgarli Turnike',
      hint: 'Ruzgari ters kullan; topu potaya son anda yumusat.',
      dropX: 0.82,
      startVX: -0.19,
      goal: Rect.fromLTWH(0.17, 0.86, 0.20, 0.055),
      hoopMotion: 0.035,
      hoopSpeed: 0.26,
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.28, 0.18, 0.40, 0.04),
        ),
        GameObstacle(
          id: 'fan1',
          kind: ObstacleKind.fanLeft,
          normalized: Rect.fromLTWH(0.54, 0.33, 0.25, 0.11),
        ),
        GameObstacle(
          id: 'b',
          kind: ObstacleKind.gate,
          normalized: Rect.fromLTWH(0.10, 0.50, 0.45, 0.04),
        ),
        GameObstacle(
          id: 'fan2',
          kind: ObstacleKind.fanLeft,
          normalized: Rect.fromLTWH(0.30, 0.65, 0.24, 0.10),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.61, 0.75, 0.18, 0.035),
        ),
      ],
    ),
    GameLevel(
      index: 8,
      name: 'Ucluk Cizgisi',
      hint: 'Az temasla uzun yol: bonus cizgisini yakala, rota icin sek.',
      dropX: 0.48,
      startVX: 0.08,
      goal: Rect.fromLTWH(0.42, 0.85, 0.19, 0.052),
      hoopMotion: 0.040,
      hoopSpeed: 0.30,
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.08, 0.16, 0.27, 0.04),
        ),
        GameObstacle(
          id: 'b',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.65, 0.16, 0.27, 0.04),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.gate,
          normalized: Rect.fromLTWH(0.24, 0.34, 0.52, 0.04),
        ),
        GameObstacle(
          id: 'fan1',
          kind: ObstacleKind.fanRight,
          normalized: Rect.fromLTWH(0.10, 0.50, 0.25, 0.10),
        ),
        GameObstacle(
          id: 'fan2',
          kind: ObstacleKind.fanLeft,
          normalized: Rect.fromLTWH(0.65, 0.50, 0.25, 0.10),
        ),
        GameObstacle(
          id: 'd',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.41, 0.72, 0.18, 0.035),
        ),
      ],
    ),
    GameLevel(
      index: 9,
      name: 'Son Saniye',
      hint: 'En dar cember. Topu hizli degil, kontrollu indir.',
      dropX: 0.28,
      startVX: 0.18,
      goal: Rect.fromLTWH(0.68, 0.84, 0.18, 0.052),
      hoopMotion: 0.045,
      hoopSpeed: 0.34,
      obstacles: [
        GameObstacle(
          id: 'a',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.16, 0.32, 0.46, 0.038),
        ),
        GameObstacle(
          id: 'fan1',
          kind: ObstacleKind.fanRight,
          normalized: Rect.fromLTWH(0.10, 0.42, 0.24, 0.10),
        ),
        GameObstacle(
          id: 'b',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(0.46, 0.43, 0.46, 0.038),
        ),
        GameObstacle(
          id: 'fan2',
          kind: ObstacleKind.fanLeft,
          normalized: Rect.fromLTWH(0.55, 0.56, 0.26, 0.10),
        ),
        GameObstacle(
          id: 'c',
          kind: ObstacleKind.gate,
          normalized: Rect.fromLTWH(0.16, 0.68, 0.42, 0.038),
        ),
        GameObstacle(
          id: 'd',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(0.46, 0.74, 0.16, 0.034),
        ),
      ],
    ),
  ];

  static GameLevel _generatedLevel(int index) {
    final random = math.Random(index * 9973);
    final tier = index ~/ 10;
    final stage = index ~/ 20;
    final leftGoal = index.isOdd;
    final hoopWidth = (0.25 - stage * 0.012).clamp(0.18, 0.25).toDouble();
    final dropX = 0.16 + random.nextDouble() * 0.68;
    final goalX =
        leftGoal
            ? 0.08 + random.nextDouble() * 0.16
            : 0.71 - random.nextDouble() * 0.16;
    final goalY = (0.88 - tier * 0.002).clamp(0.84, 0.90).toDouble();
    final goal = Rect.fromLTWH(goalX, goalY, hoopWidth, 0.052);
    final obstacles = <GameObstacle>[];

    bool tryAdd(GameObstacle obstacle, {double padding = 0.045}) {
      final rect = obstacle.normalized;
      if (rect.left < 0.045 ||
          rect.right > 0.955 ||
          rect.top < 0.12 ||
          rect.bottom > 0.82) {
        return false;
      }
      final startLane = Rect.fromLTWH(dropX - 0.08, 0.12, 0.16, 0.18);
      if (rect.inflate(0.025).overlaps(startLane)) return false;
      if (rect.inflate(0.085).overlaps(goal)) return false;
      for (final item in obstacles) {
        if (rect.inflate(padding).overlaps(item.normalized.inflate(padding))) {
          return false;
        }
      }
      obstacles.add(obstacle);
      return true;
    }

    Rect laneRect(double y, double width, {double wiggle = 0.18}) {
      final goalCenter = goal.center.dx;
      final t = ((y - 0.16) / 0.68).clamp(0.0, 1.0);
      final laneCenter = dropX + (goalCenter - dropX) * t;
      final side = random.nextBool() ? -1.0 : 1.0;
      final center =
          (laneCenter + side * (0.14 + random.nextDouble() * wiggle))
              .clamp(0.10 + width / 2, 0.90 - width / 2)
              .toDouble();
      return Rect.fromLTWH(center - width / 2, y, width, 0.038);
    }

    final gateCount =
        index < 35
            ? 0
            : index < 65
            ? 1
            : (index % 12 == 0 ? 2 : 1);
    final flowCount =
        index < 25
            ? 2
            : index < 60
            ? 3
            : 4;
    for (var i = 0; i < flowCount; i++) {
      final y = 0.17 + i * (0.58 / math.max(1, flowCount));
      final width = 0.28 + random.nextDouble() * 0.20;
      tryAdd(
        GameObstacle(
          id: 'flow$i',
          kind:
              i.isEven
                  ? ObstacleKind.boost
                  : index % 3 == 0
                  ? ObstacleKind.bumper
                  : ObstacleKind.wall,
          normalized: laneRect(
            (y + random.nextDouble() * 0.035).clamp(0.13, 0.78).toDouble(),
            width,
          ),
        ),
      );
    }
    for (var i = 0; i < gateCount; i++) {
      final y = 0.28 + i * (0.42 / math.max(1, gateCount));
      final width = 0.24 + random.nextDouble() * 0.16;
      tryAdd(
        GameObstacle(
          id: 'gate$i',
          kind: ObstacleKind.gate,
          normalized: laneRect(
            (y + random.nextDouble() * 0.045).clamp(0.18, 0.76).toDouble(),
            width,
            wiggle: 0.10,
          ),
        ),
        padding: 0.055,
      );
    }
    if (index >= 28 && index % 4 != 1) {
      tryAdd(
        GameObstacle(
          id: 'wall',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(
            0.24 + random.nextDouble() * 0.44,
            0.30 + random.nextDouble() * 0.25,
            0.038 + random.nextDouble() * 0.018,
            0.14 + random.nextDouble() * 0.12,
          ),
        ),
        padding: 0.060,
      );
    }
    if (index >= 16 && index % 2 == 1) {
      tryAdd(
        GameObstacle(
          id: 'bumper',
          kind: ObstacleKind.bumper,
          normalized: Rect.fromLTWH(
            0.18 + random.nextDouble() * 0.56,
            0.48 + random.nextDouble() * 0.30,
            0.15 + random.nextDouble() * 0.09,
            0.034,
          ),
        ),
        padding: 0.065,
      );
    }
    if (index >= 10 && index % 3 != 0) {
      tryAdd(
        GameObstacle(
          id: 'boost',
          kind: ObstacleKind.boost,
          normalized: Rect.fromLTWH(
            0.16 + random.nextDouble() * 0.58,
            0.56 + random.nextDouble() * 0.22,
            0.18 + random.nextDouble() * 0.08,
            0.046,
          ),
        ),
        padding: 0.050,
      );
    }
    if (index >= 38) {
      tryAdd(
        GameObstacle(
          id: 'fan',
          kind: index.isEven ? ObstacleKind.fanRight : ObstacleKind.fanLeft,
          normalized: Rect.fromLTWH(
            0.10 + random.nextDouble() * 0.62,
            0.26 + random.nextDouble() * 0.42,
            0.20 + random.nextDouble() * 0.06,
            0.08 + random.nextDouble() * 0.025,
          ),
        ),
        padding: 0.055,
      );
    }
    if (index >= 58 && index % 5 == 0) {
      tryAdd(
        GameObstacle(
          id: 'gravity',
          kind: ObstacleKind.gravity,
          normalized: Rect.fromLTWH(
            0.22 + random.nextDouble() * 0.50,
            0.36 + random.nextDouble() * 0.30,
            0.18 + random.nextDouble() * 0.08,
            0.10,
          ),
        ),
        padding: 0.060,
      );
    }
    if (index >= 78 && index % 6 == 0) {
      tryAdd(
        GameObstacle(
          id: 'fan2',
          kind: index % 8 == 0 ? ObstacleKind.fanLeft : ObstacleKind.fanRight,
          normalized: Rect.fromLTWH(
            0.15 + random.nextDouble() * 0.55,
            0.55 + random.nextDouble() * 0.22,
            0.20 + random.nextDouble() * 0.08,
            0.085,
          ),
        ),
        padding: 0.055,
      );
    }
    var filler = 0;
    while (obstacles.length < 2 && filler < 4) {
      final y = 0.30 + filler * 0.16;
      tryAdd(
        GameObstacle(
          id: 'safe$filler',
          kind: filler.isEven ? ObstacleKind.boost : ObstacleKind.bumper,
          normalized: laneRect(y, 0.22, wiggle: 0.08),
        ),
        padding: 0.055,
      );
      filler++;
    }
    return GameLevel(
      index: index,
      name: _generatedName(index),
      hint: _generatedHint(index),
      dropX: dropX,
      startVX: (random.nextDouble() - 0.5) * (0.10 + stage * 0.024),
      goal: goal,
      hoopMotion: (0.010 + stage * 0.012).clamp(0.010, 0.058).toDouble(),
      hoopSpeed: (0.10 + stage * 0.070).clamp(0.10, 0.46).toDouble(),
      obstacles: obstacles,
    );
  }

  static String _generatedName(int index) {
    if (index >= 24 && (index + 1) % 10 == 0) {
      return 'Takip Baskisi ${index + 1}';
    }
    const names = [
      'Hiz Koridoru',
      'Ruzgar Turnikesi',
      'Dar Cember',
      'Bonus Rotasi',
      'Sekme Sahasi',
      'Akis Labirenti',
      'Keskin Aci',
      'Son Hamle',
      'File Yolu',
      'Usta Parkur',
    ];
    return '${names[index % names.length]} ${index + 1}';
  }

  static String _generatedHint(int index) {
    if (index >= 24 && (index + 1) % 10 == 0) {
      return 'Kirmizi baski seni kovalar; hizli oyna, bonusu abartmadan potaya ak.';
    }
    if (index >= 70) {
      return 'Rota dar, pota hareketli. Once akisi kur, sonra bonusu kovala.';
    }
    if (index >= 45) {
      return 'Ruzgar, sekme ve hiz seridini zincirle; kontrol jokerini sona sakla.';
    }
    if (index >= 25) {
      return 'Anahtar varsa rota acilir; yoksa sekme ve hiz seridiyle yolu bul.';
    }
    return 'Bonus cizgisini takip et, engelleri avantaja cevir, potaya yumusak gir.';
  }
}

enum ObstacleKind { gate, wall, bumper, fanLeft, fanRight, boost, gravity }

class GameObstacle {
  const GameObstacle({
    required this.id,
    required this.normalized,
    this.kind = ObstacleKind.gate,
    this.open = false,
  });

  final String id;
  final Rect normalized;
  final ObstacleKind kind;
  final bool open;

  bool get isTapTarget => false;

  Rect rectFor(Size size) => Rect.fromLTRB(
    normalized.left * size.width,
    normalized.top * size.height,
    normalized.right * size.width,
    normalized.bottom * size.height,
  );

  GameObstacle copy({bool? open}) {
    return GameObstacle(
      id: id,
      normalized: normalized,
      kind: kind,
      open: open ?? this.open,
    );
  }
}

class GameBackend {
  static bool _ready = false;

  static Future<bool> boot() async {
    if (!DefaultFirebaseOptions.isConfigured) return false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _ready = true;
      return true;
    } catch (_) {
      _ready = false;
      return false;
    }
  }

  String get uid => FirebaseAuth.instance.currentUser?.uid ?? 'offline';
  bool get ready => _ready;

  Future<int> loadProgress(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getInt('unlocked_$uid') ?? 0;
    if (!_ready) return local;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final remote = doc.data()?['unlockedLevelIndex'] as int? ?? local;
      final best = math.max(local, remote);
      await prefs.setInt('unlocked_$uid', best);
      return best;
    } catch (_) {
      return local;
    }
  }

  Future<void> saveProgress(String uid, int unlockedLevelIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unlocked_$uid', unlockedLevelIndex);
    if (!_ready) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'unlockedLevelIndex': unlockedLevelIndex,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<GameEconomy> loadEconomy(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final localCoins = prefs.getInt('coins_$uid') ?? 120;
    final localPremium = prefs.getBool('premium_$uid') ?? false;
    final localRouteJokers = prefs.getInt('route_jokers_$uid') ?? 3;
    final localBreakerJokers = prefs.getInt('breaker_jokers_$uid') ?? 3;
    final localKeyJokers = prefs.getInt('key_jokers_$uid') ?? 3;
    if (!_ready) {
      return GameEconomy(
        coins: localCoins,
        premium: localPremium,
        routeJokers: localRouteJokers,
        breakerJokers: localBreakerJokers,
        keyJokers: localKeyJokers,
      );
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() ?? {};
      final coins = data['coins'] as int? ?? localCoins;
      final premium = data['premium'] as bool? ?? localPremium;
      final routeJokers = data['routeJokers'] as int? ?? localRouteJokers;
      final breakerJokers = data['breakerJokers'] as int? ?? localBreakerJokers;
      final keyJokers = data['keyJokers'] as int? ?? localKeyJokers;
      await prefs.setInt('coins_$uid', coins);
      await prefs.setBool('premium_$uid', premium);
      await prefs.setInt('route_jokers_$uid', routeJokers);
      await prefs.setInt('breaker_jokers_$uid', breakerJokers);
      await prefs.setInt('key_jokers_$uid', keyJokers);
      return GameEconomy(
        coins: coins,
        premium: premium,
        routeJokers: routeJokers,
        breakerJokers: breakerJokers,
        keyJokers: keyJokers,
      );
    } catch (_) {
      return GameEconomy(
        coins: localCoins,
        premium: localPremium,
        routeJokers: localRouteJokers,
        breakerJokers: localBreakerJokers,
        keyJokers: localKeyJokers,
      );
    }
  }

  Future<void> saveEconomy(
    String uid, {
    required int coins,
    required bool premium,
    required int routeJokers,
    required int breakerJokers,
    required int keyJokers,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins_$uid', coins);
    await prefs.setBool('premium_$uid', premium);
    await prefs.setInt('route_jokers_$uid', routeJokers);
    await prefs.setInt('breaker_jokers_$uid', breakerJokers);
    await prefs.setInt('key_jokers_$uid', keyJokers);
    if (!_ready) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'coins': coins,
      'premium': premium,
      'routeJokers': routeJokers,
      'breakerJokers': breakerJokers,
      'keyJokers': keyJokers,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveProfileName(String name) async {
    if (!_ready) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': name,
      'email': FirebaseAuth.instance.currentUser?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> submitScore({
    required String name,
    required int score,
    required String level,
    required int levelIndex,
    required int moves,
    required int durationMs,
  }) async {
    if (!_ready) return;
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();
    for (final period in LeaderboardPeriod.values) {
      final periodKey = period.keyFor(now);
      final ref = FirebaseFirestore.instance
          .collection('leaderboard')
          .doc('${period.name}_${periodKey}_${levelIndex}_$uid');
      final globalRef = FirebaseFirestore.instance
          .collection('leaderboardGlobal')
          .doc('${period.name}_$periodKey')
          .collection('entries')
          .doc(uid);
      batch.set(ref, {
        'uid': uid,
        'name': name,
        'score': score,
        'level': level,
        'levelIndex': levelIndex,
        'moves': moves,
        'durationMs': durationMs,
        'period': period.name,
        'periodKey': periodKey,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(globalRef, {
        'uid': uid,
        'name': name,
        'totalScore': FieldValue.increment(score),
        'plays': FieldValue.increment(1),
        'lastScore': score,
        'lastLevel': level,
        'lastLevelIndex': levelIndex,
        'lastMoves': moves,
        'lastDurationMs': durationMs,
        'period': period.name,
        'periodKey': periodKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Stream<List<LeaderboardEntry>> watchLeaderboard({
    required LeaderboardPeriod period,
  }) {
    if (!_ready) return Stream.value(LeaderboardEntry.demoGlobal());
    final periodKey = period.keyFor(DateTime.now());
    return FirebaseFirestore.instance
        .collection('leaderboardGlobal')
        .doc('${period.name}_$periodKey')
        .collection('entries')
        .orderBy('totalScore', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return LeaderboardEntry(
              name: data['name'] as String? ?? 'Oyuncu',
              score: data['totalScore'] as int? ?? 0,
              level: data['lastLevel'] as String? ?? 'Genel',
              levelIndex: data['lastLevelIndex'] as int? ?? 0,
              moves: data['plays'] as int? ?? 0,
              durationMs: data['lastDurationMs'] as int? ?? 0,
            );
          }).toList();
        });
  }

  Future<ArenaRoom> createArenaRoom(String playerName, int levelIndex) async {
    final id = _roomCode();
    final room = ArenaRoom(
      id: id,
      hostUid: uid,
      hostName: playerName,
      levelIndex: levelIndex,
    );
    if (!_ready) return room;
    await FirebaseFirestore.instance.collection('arenaRooms').doc(id).set({
      'hostUid': uid,
      'hostName': playerName,
      'guestUid': null,
      'guestName': null,
      'levelIndex': levelIndex,
      'hostScore': null,
      'guestScore': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return room;
  }

  Future<ArenaRoom> joinArenaRoom(String id, String playerName) async {
    if (!_ready) {
      return ArenaRoom(
        id: id,
        hostUid: 'host',
        hostName: 'Ev Sahibi',
        guestUid: uid,
        guestName: playerName,
        levelIndex: 0,
      );
    }
    final ref = FirebaseFirestore.instance.collection('arenaRooms').doc(id);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw StateError('Oda bulunamadi.');
    }
    await ref.set({
      'guestUid': uid,
      'guestName': playerName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final updated = await ref.get();
    return ArenaRoom.fromMap(updated.id, updated.data() ?? {});
  }

  Stream<ArenaRoom?> watchArenaRoom(String id) {
    if (!_ready) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('arenaRooms')
        .doc(id)
        .snapshots()
        .map(
          (doc) =>
              doc.exists ? ArenaRoom.fromMap(doc.id, doc.data() ?? {}) : null,
        );
  }

  Future<void> submitArenaScore(String roomId, int score) async {
    if (!_ready) return;
    final ref = FirebaseFirestore.instance.collection('arenaRooms').doc(roomId);
    final snapshot = await ref.get();
    final room = ArenaRoom.fromMap(roomId, snapshot.data() ?? {});
    final isHost = room.hostUid == uid;
    await ref.set({
      isHost ? 'hostScore' : 'guestScore': score,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _roomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = math.Random();
    return List.generate(5, (_) => chars[random.nextInt(chars.length)]).join();
  }
}

class GameEconomy {
  const GameEconomy({
    required this.coins,
    required this.premium,
    required this.routeJokers,
    required this.breakerJokers,
    required this.keyJokers,
  });

  final int coins;
  final bool premium;
  final int routeJokers;
  final int breakerJokers;
  final int keyJokers;
}

class ArenaRoom {
  const ArenaRoom({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.levelIndex,
    this.guestUid,
    this.guestName,
    this.hostScore,
    this.guestScore,
  });

  final String id;
  final String hostUid;
  final String hostName;
  final int levelIndex;
  final String? guestUid;
  final String? guestName;
  final int? hostScore;
  final int? guestScore;

  String? get winnerName {
    if (hostScore == null || guestScore == null) return null;
    if (hostScore == guestScore) return 'Berabere';
    return (hostScore ?? 0) > (guestScore ?? 0)
        ? hostName
        : (guestName ?? 'Misafir');
  }

  static ArenaRoom fromMap(String id, Map<String, dynamic> data) {
    return ArenaRoom(
      id: id,
      hostUid: data['hostUid'] as String? ?? '',
      hostName: data['hostName'] as String? ?? 'Oyuncu',
      guestUid: data['guestUid'] as String?,
      guestName: data['guestName'] as String?,
      levelIndex: data['levelIndex'] as int? ?? 0,
      hostScore: data['hostScore'] as int?,
      guestScore: data['guestScore'] as int?,
    );
  }
}

enum LeaderboardPeriod {
  daily('Gunluk', Icons.today),
  weekly('Haftalik', Icons.calendar_view_week),
  monthly('Aylik', Icons.calendar_month);

  const LeaderboardPeriod(this.label, this.icon);

  final String label;
  final IconData icon;

  String keyFor(DateTime date) {
    final utc = date.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return switch (this) {
      LeaderboardPeriod.daily => '$y$m$d',
      LeaderboardPeriod.weekly =>
        '$y-W${_weekOfYear(utc).toString().padLeft(2, '0')}',
      LeaderboardPeriod.monthly => '$y$m',
    };
  }

  int _weekOfYear(DateTime date) {
    final first = DateTime.utc(date.year, 1, 1);
    return ((date.difference(first).inDays + first.weekday) / 7).ceil();
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.score,
    required this.level,
    required this.levelIndex,
    required this.moves,
    required this.durationMs,
  });

  final String name;
  final int score;
  final String level;
  final int levelIndex;
  final int moves;
  final int durationMs;

  static const demo = [
    LeaderboardEntry(
      name: 'Mavi',
      score: 28420,
      level: 'Final Labirenti',
      levelIndex: 5,
      moves: 6,
      durationMs: 9500,
    ),
    LeaderboardEntry(
      name: 'Ada',
      score: 25180,
      level: 'Dar Kuyu',
      levelIndex: 4,
      moves: 5,
      durationMs: 10800,
    ),
    LeaderboardEntry(
      name: 'Kaan',
      score: 21940,
      level: 'Ziplama Hatti',
      levelIndex: 1,
      moves: 4,
      durationMs: 12800,
    ),
    LeaderboardEntry(
      name: 'Ece',
      score: 18320,
      level: 'Ruzgar Odasi',
      levelIndex: 2,
      moves: 3,
      durationMs: 11600,
    ),
  ];

  static List<LeaderboardEntry> demoGlobal() =>
      [...demo]..sort((a, b) => b.score.compareTo(a.score));
}

class MobileGameHud extends StatelessWidget {
  const MobileGameHud({
    super.key,
    required this.title,
    required this.status,
    required this.run,
    required this.coins,
    required this.premium,
    required this.onRestart,
    required this.onLevels,
    required this.onBack,
  });

  final String title;
  final String status;
  final GameRun run;
  final int coins;
  final bool premium;
  final VoidCallback onRestart;
  final VoidCallback onLevels;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 36, height: 36, child: _HudGameIcon()),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: 'Geri',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                style: IconButton.styleFrom(
                  minimumSize: const Size(38, 38),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                tooltip: 'Bolumler',
                onPressed: onLevels,
                icon: const Icon(Icons.grid_view),
                style: IconButton.styleFrom(
                  minimumSize: const Size(38, 38),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Yeniden baslat',
                onPressed: onRestart,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: HudChip(label: 'Skor', value: '${run.score}')),
            const SizedBox(width: 6),
            Expanded(
              child: HudChip(label: 'Sure', value: '${run.timeLeftSeconds}s'),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: HudChip(
                label: 'Kontrol',
                value: '${run.remainingNudges}/${run.maxNudges}',
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: HudChip(
                label: premium ? 'P Coin' : 'Coin',
                value: '$coins',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HudChip extends StatelessWidget {
  const HudChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white60),
          ),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class MobileJokerDock extends StatelessWidget {
  const MobileJokerDock({
    super.key,
    required this.routeCount,
    required this.breakerCount,
    required this.keyCount,
    required this.onExtraControl,
    required this.onExtraTime,
    required this.onExtraKey,
  });

  final int routeCount;
  final int breakerCount;
  final int keyCount;
  final VoidCallback onExtraControl;
  final VoidCallback onExtraTime;
  final VoidCallback onExtraKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PowerUpButton(
            onPressed: routeCount > 0 ? onExtraControl : null,
            icon: const Icon(Icons.track_changes),
            label: 'Rota',
            count: routeCount,
            color: const Color(0xff19f5a8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PowerUpButton(
            onPressed: breakerCount > 0 ? onExtraTime : null,
            icon: const Icon(Icons.hardware),
            label: 'Kirici',
            count: breakerCount,
            color: const Color(0xff7dd3fc),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PowerUpButton(
            onPressed: keyCount > 0 ? onExtraKey : null,
            icon: const Icon(Icons.key),
            label: 'Anahtar',
            count: keyCount,
            color: const Color(0xffffd166),
          ),
        ),
      ],
    );
  }
}

class _PowerUpButton extends StatefulWidget {
  const _PowerUpButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String label;
  final int count;
  final Color color;

  @override
  State<_PowerUpButton> createState() => _PowerUpButtonState();
}

class _PowerUpButtonState extends State<_PowerUpButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = enabled ? 0.18 + _controller.value * 0.16 : 0.05;
        return GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: enabled ? 1 : 0.45,
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xff101820),
                    widget.color.withValues(alpha: 0.72),
                    const Color(0xff05080c),
                  ],
                ),
                border: Border.all(
                  color: widget.color.withValues(alpha: enabled ? 0.80 : 0.26),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: glow),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.20),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconTheme(
                          data: IconThemeData(
                            color: Colors.white.withValues(alpha: 0.94),
                            size: 22,
                          ),
                          child: widget.icon,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.94),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 7,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.52),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        'x${widget.count}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class JokerBar extends StatelessWidget {
  const JokerBar({
    super.key,
    required this.coins,
    required this.premium,
    required this.onExtraControl,
    required this.onExtraTime,
  });

  final int coins;
  final bool premium;
  final VoidCallback onExtraControl;
  final VoidCallback onExtraTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: StatPill(
              label: premium ? 'Premium Coin' : 'Coin',
              value: '$coins',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: coins >= 35 ? onExtraControl : null,
              icon: const Icon(Icons.track_changes),
              label: const Text('Rota'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: coins >= 45 ? onExtraTime : null,
              icon: const Icon(Icons.hardware),
              label: const Text('Kirici'),
            ),
          ),
        ],
      ),
    );
  }
}

class LevelSelector extends StatelessWidget {
  const LevelSelector({
    super.key,
    required this.selectedIndex,
    required this.unlockedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final int unlockedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: GameLevel.samples.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final level = GameLevel.samples[index];
          final selected = selectedIndex == index;
          final locked = index > unlockedIndex;
          return SizedBox(
            width: 156,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: locked ? null : () => onSelected(index),
              child: Ink(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      selected
                          ? const Color(0xff143f3a)
                          : const Color(0xff161b22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? const Color(0xff19f5a8) : Colors.white12,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text('Bolum ${index + 1}'),
                        const Spacer(),
                        Icon(locked ? Icons.lock : Icons.lock_open, size: 16),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LeaderboardTile extends StatelessWidget {
  const LeaderboardTile({super.key, required this.entry, required this.rank});

  final LeaderboardEntry entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xff161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xff2d3748),
            foregroundColor: Colors.white,
            child: Text('$rank'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank. ${entry.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${entry.moves} oyun - son: B${entry.levelIndex + 1} ${entry.level}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(
            '${entry.score}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class TopThreePodium extends StatelessWidget {
  const TopThreePodium({super.key, required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff101923), Color(0xff24170b), Color(0xff101923)],
        ),
        border: Border.all(
          color: const Color(0xffffd166).withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xffffd166).withValues(alpha: 0.18),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xffffd166)),
              const SizedBox(width: 8),
              Text(
                'Ilk 3',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              const Text('Genel skor', style: TextStyle(color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (entries.length > 1)
                Expanded(child: PodiumCard(entry: entries[1], rank: 2)),
              Expanded(
                child: PodiumCard(
                  entry: entries.first,
                  rank: 1,
                  featured: true,
                ),
              ),
              if (entries.length > 2)
                Expanded(child: PodiumCard(entry: entries[2], rank: 3)),
            ],
          ),
        ],
      ),
    );
  }
}

class PodiumCard extends StatelessWidget {
  const PodiumCard({
    super.key,
    required this.entry,
    required this.rank,
    this.featured = false,
  });

  final LeaderboardEntry entry;
  final int rank;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final color = switch (rank) {
      1 => const Color(0xffffd166),
      2 => const Color(0xffd7dee8),
      _ => const Color(0xffd1905a),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: EdgeInsets.fromLTRB(8, featured ? 16 : 10, 8, 10),
      height: featured ? 174 : 138,
      decoration: BoxDecoration(
        color: color.withValues(alpha: featured ? 0.25 : 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: featured ? 0.24 : 0.12),
            blurRadius: featured ? 22 : 14,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: featured ? 24 : 20,
            backgroundColor: color,
            foregroundColor: Colors.black,
            child: Icon(
              rank == 1 ? Icons.workspace_premium : Icons.emoji_events,
              size: featured ? 26 : 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '#$rank',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '${entry.score}',
            maxLines: 1,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: featured ? 24 : 19,
            ),
          ),
          Text(
            '${entry.moves} oyun',
            maxLines: 1,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff182433), Color(0xff111827), Color(0xff2a1f13)],
        ),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff19f5a8).withValues(alpha: 0.08),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0xffffd28a),
                  Color(0xffff8a2a),
                  Color(0xff8a3710),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xffff8a2a).withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.sports_basketball, color: Colors.black87),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class ScoreStrip extends StatelessWidget {
  const ScoreStrip({super.key, required this.run});

  final GameRun run;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: StatPill(label: 'Skor', value: '${run.score}')),
          const SizedBox(width: 8),
          Expanded(child: StatPill(label: 'Hamle', value: '${run.moves}')),
          const SizedBox(width: 8),
          Expanded(
            child: StatPill(label: 'Sure', value: '${run.timeLeftSeconds}s'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: StatPill(
              label: 'Kontrol',
              value: '${run.remainingNudges}/${run.maxNudges}',
            ),
          ),
        ],
      ),
    );
  }
}

class StatPill extends StatelessWidget {
  const StatPill({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xff161b22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class OfflineFirebaseBanner extends StatelessWidget {
  const OfflineFirebaseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff33271a),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xff9f7736)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xffffc46b)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Firebase baglantisi yok. Email/sifre girisi icin proje ayari gerekir.',
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white54),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthCopy {
  static String message(FirebaseAuthException error) {
    final code = error.code.toLowerCase();
    final serverMessage = error.message ?? '';
    if (code == 'unknown' ||
        serverMessage.contains('CONFIGURATION_NOT_FOUND') ||
        serverMessage.contains('PASSWORD_LOGIN_DISABLED')) {
      return 'Firebase Authentication henuz acik degil. Console > Authentication > Sign-in method > Email/Password secenegini etkinlestir.';
    }
    return switch (code) {
      'email-already-in-use' => 'Bu email zaten kayitli.',
      'invalid-email' => 'Email formati hatali.',
      'weak-password' => 'Sifre en az 6 karakter olmali.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email veya sifre hatali.',
      'operation-not-allowed' =>
        'Firebase Console uzerinden Email/Password girisi acilmali.',
      'network-request-failed' =>
        'Internet baglantisi yok veya Firebase erisilemiyor.',
      _ =>
        'Islem tamamlanamadi: $code${serverMessage.isEmpty ? '' : ' - $serverMessage'}',
    };
  }

  static String generic(Object error) {
    return 'Islem tamamlanamadi. Firebase Authentication ayarlarini kontrol et: $error';
  }
}
