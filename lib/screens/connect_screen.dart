import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/router_provider.dart';
import '../theme/app_theme.dart';
import 'shell_screen.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});
  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _ipCtrl = TextEditingController(text: '192.168.8.1');
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final store = await ref.read(localStoreProvider.future);
    _ipCtrl.text = store.getRouterIp();
    _userCtrl.text = store.getUsername();
    _passCtrl.text = store.getPassword() ?? '';
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(routerControllerProvider);

    ref.listen(routerControllerProvider, (prev, next) {
      if (next.state == ConnState.connected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ShellScreen()),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.router_rounded,
                    size: 64, color: AppColors.accent),
                const SizedBox(height: 16),
                Text('HiLink Control Hub',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('اتصل بالراوتر بتاعك للمتابعة',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6))),
                const SizedBox(height: 32),
                if (!_loaded)
                  const CircularProgressIndicator()
                else ...[
                  TextField(
                    controller: _ipCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الراوتر (IP)',
                      prefixIcon: Icon(Icons.dns_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'كلمة سر الأدمن',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (conn.state == ConnState.error)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(conn.message ?? 'فشل الاتصال',
                          style: const TextStyle(color: AppColors.danger)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: conn.state == ConnState.connecting
                          ? null
                          : () => ref.read(routerControllerProvider.notifier).connect(
                                ip: _ipCtrl.text.trim(),
                                username: _userCtrl.text.trim(),
                                password: _passCtrl.text,
                              ),
                      child: conn.state == ConnState.connecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('اتصال'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
