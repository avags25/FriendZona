import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_error.dart';
import 'auth_repository.dart';
import 'models.dart';
import 'validation.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.isLoading) return const _LaunchScreen();
    if (auth.hasError) {
      return _ScaffoldShell(
        child: _ErrorPanel(
          title: 'Не удалось восстановить сессию',
          message: _messageFor(auth.error),
          actionLabel: 'Повторить',
          onAction: () => ref.invalidate(authControllerProvider),
        ),
      );
    }
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF9F6FF), Color(0xFFFFF7F0), Color(0xFFF1F2FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _BrandMark(),
                      const SizedBox(height: 24),
                      const _WelcomeArtwork(),
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ближе к своим.',
                            style: Theme.of(context).textTheme.headlineLarge
                                ?.copyWith(
                                  height: 1.05,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                  color: const Color(0xFF202039),
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Social World поможет быть на связи с важными людьми — в вашем ритме.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  height: 1.5,
                                  color: const Color(0xFF6D6A7C),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Column(
                        children: [
                          FilledButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('Создать аккаунт'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => context.go('/login'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              foregroundColor: const Color(0xFF5147C8),
                              side: const BorderSide(color: Color(0xFFDCD9F2)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('У меня уже есть аккаунт'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            LoginRequest(email: _email.text.trim(), password: _password.text),
          );
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthLayout(
    eyebrow: 'С возвращением',
    title: 'Войдите в свой мир',
    subtitle: 'Продолжим с того места, где вы остановились.',
    footer: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Впервые здесь?'),
        TextButton(
          onPressed: () => context.go('/register'),
          child: const Text('Создать аккаунт'),
        ),
      ],
    ),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EmailField(controller: _email),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            validator: (value) =>
                value == null || value.isEmpty ? 'Введите пароль' : null,
            decoration: InputDecoration(
              labelText: 'Пароль',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SubmitButton(label: 'Войти', onPressed: _submit),
        ],
      ),
    ),
  );
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            RegisterRequest(
              email: _email.text.trim(),
              password: _password.text,
              displayName: _name.text.trim(),
            ),
          );
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthLayout(
    eyebrow: 'Ваше пространство начинается здесь',
    title: 'Создайте аккаунт',
    subtitle: 'Имя можно изменить в профиле в любое время.',
    footer: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Уже с нами?'),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Войти'),
        ),
      ],
    ),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            validator: FormValidation.displayName,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Как к вам обращаться',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          _EmailField(controller: _email),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            validator: FormValidation.password,
            decoration: InputDecoration(
              labelText: 'Пароль',
              helperText: 'Не менее 12 символов',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                tooltip: _obscure ? 'Показать пароль' : 'Скрыть пароль',
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SubmitButton(label: 'Создать аккаунт', onPressed: _submit),
        ],
      ),
    ),
  );
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value;
    if (user == null) return const _LaunchScreen();
    return Scaffold(
      appBar: AppBar(
        title: const _BrandMark(compact: true),
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFE7E3FF),
              child: Icon(
                Icons.person_outline,
                color: Color(0xFF5147C8),
                size: 19,
              ),
            ),
            tooltip: 'Профиль',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6358D8), Color(0xFF8379E8)],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x265148C8),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Pill(label: 'ВАШЕ ПРОСТРАНСТВО'),
                  const SizedBox(height: 22),
                  Text(
                    'Рады видеть,\n${user.displayName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      height: 1.12,
                      letterSpacing: -0.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Хорошие планы начинаются с простого сообщения.',
                    style: TextStyle(color: Color(0xFFE6E3FF), height: 1.45),
                  ),
                  const SizedBox(height: 18),
                  const Icon(
                    Icons.waves_rounded,
                    color: Color(0xFFCDC9FF),
                    size: 27,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Card(
              child: ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Друзья'),
                subtitle: const Text('Код, список друзей и заявки'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/friends'),
              ),
            ),
            const SizedBox(height: 11),
            Text(
              'Будет в Social World',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF26253C),
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Разделы появятся, когда будут готовы.',
              style: TextStyle(color: Color(0xFF777587)),
            ),
            const SizedBox(height: 16),
            const _FutureFeatureCard(
              icon: Icons.explore_outlined,
              title: 'Карта',
              description: 'Пространство для мест и ваших планов',
              tint: Color(0xFFE8F4EF),
              iconColor: Color(0xFF387B63),
            ),
            const SizedBox(height: 11),
            const _FutureFeatureCard(
              icon: Icons.event_outlined,
              title: 'Встречи',
              description: 'Договориться увидеться станет проще',
              tint: Color(0xFFFFEEE7),
              iconColor: Color(0xFFC85F45),
            ),
            const SizedBox(height: 11),
            const _FutureFeatureCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Персонаж',
              description: 'Ваше цифровое отражение — впереди',
              tint: Color(0xFFEDEBFF),
              iconColor: Color(0xFF6256CF),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _loadedId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateDisplayName(_name.text.trim());
      if (mounted) _showMessage(context, 'Имя профиля обновлено');
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).asData?.value;
    if (user == null) return const _LaunchScreen();
    if (_loadedId != user.id) {
      _loadedId = user.id;
      _name.text = user.displayName;
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'Мой профиль',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A5FDD), Color(0xFF958CF0)],
                  ),
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 43,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF777587)),
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                title: const Text('Код друга'),
                subtitle: Text(
                  user.friendCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Скопировать код',
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: user.friendCode));
                    _showMessage(context, 'Код скопирован');
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Отображаемое имя',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _name,
                validator: FormValidation.displayName,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.badge_outlined),
                  hintText: 'Ваше имя',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SubmitButton(label: 'Сохранить изменения', onPressed: _save),
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Выйти из аккаунта'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: const Color(0xFFB34540),
                side: const BorderSide(color: Color(0xFFE7C7C5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 38),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(backgroundColor: Colors.white),
                  ),
                ),
                const SizedBox(height: 25),
                const _BrandMark(),
                const SizedBox(height: 34),
                Text(
                  eyebrow.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF655BCC),
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: const Color(0xFF25243A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF777587),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),
                child,
                const SizedBox(height: 24),
                footer,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.emailAddress,
    textInputAction: TextInputAction.next,
    autofillHints: const [AutofillHints.email],
    validator: FormValidation.email,
    decoration: const InputDecoration(
      labelText: 'Email',
      prefixIcon: Icon(Icons.alternate_email_rounded),
    ),
  );
}

class _SubmitButton extends ConsumerWidget {
  const _SubmitButton({required this.label, required this.onPressed});

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(authControllerProvider).isLoading;
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 34 : 42,
        height: compact ? 34 : 42,
        decoration: BoxDecoration(
          color: const Color(0xFF5147C8),
          borderRadius: BorderRadius.circular(compact ? 12 : 15),
        ),
        child: Icon(
          Icons.public_rounded,
          size: compact ? 19 : 23,
          color: Colors.white,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'social world',
        style: TextStyle(
          fontSize: compact ? 17 : 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: const Color(0xFF28263F),
        ),
      ),
    ],
  );
}

class _WelcomeArtwork extends StatelessWidget {
  const _WelcomeArtwork();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 220,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 214,
          height: 214,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEDEAFF),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.9),
              width: 11,
            ),
          ),
        ),
        Container(
          width: 144,
          height: 144,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7E73E8), Color(0xFF544AC9)],
            ),
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 68),
        ),
        const _OrbitDot(left: 35, top: 44, color: Color(0xFFE97B64), size: 30),
        const _OrbitDot(right: 28, top: 67, color: Color(0xFFB4D7C7), size: 24),
        const _OrbitDot(
          left: 52,
          bottom: 28,
          color: Color(0xFFF4CC73),
          size: 18,
        ),
        Positioned(
          right: 45,
          bottom: 36,
          child: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1C29234D),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFED7C68),
              size: 22,
            ),
          ),
        ),
      ],
    ),
  );
}

class _OrbitDot extends StatelessWidget {
  const _OrbitDot({
    this.left,
    this.right,
    this.top,
    this.bottom,
    required this.color,
    required this.size,
  });

  final double? left;
  final double? right;
  final double? top;
  final double? bottom;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    right: right,
    top: top,
    bottom: bottom,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1D302A69),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
    ),
  );
}

class _FutureFeatureCard extends StatelessWidget {
  const _FutureFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tint,
    required this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFECEAF0)),
    ),
    child: Row(
      children: [
        Container(
          width: 47,
          height: 47,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF302E43),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF807E8D),
                ),
              ),
            ],
          ),
        ),
        const _Pill(label: 'СКОРО', light: true),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.light = false});

  final String label;
  final bool light;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: light
          ? const Color(0xFFF1F0FA)
          : Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w800,
        color: light ? const Color(0xFF716E84) : Colors.white,
      ),
    ),
  );
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}

class _ScaffoldShell extends StatelessWidget {
  const _ScaffoldShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: Color(0xFF817BAF),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF777587)),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    ),
  );
}

void _showError(BuildContext context, Object error) {
  final message = error is ApiError
      ? error.message
      : 'Не удалось выполнить действие';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

String _messageFor(Object? error) =>
    error is ApiError ? error.message : 'Проверьте подключение к backend.';
