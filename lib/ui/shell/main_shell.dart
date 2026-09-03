import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xrpl_mobile_wallet/state/shell_tab_provider.dart';
import 'package:xrpl_mobile_wallet/ui/activity/activity_screen.dart';
import 'package:xrpl_mobile_wallet/ui/network/connection_status_chip.dart';
import 'package:xrpl_mobile_wallet/ui/settings/buy_coffee.dart';
import 'package:xrpl_mobile_wallet/ui/settings/settings_screen.dart';
import 'package:xrpl_mobile_wallet/ui/wallets/list/wallet_list_screen.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _titles = ['Wallets', 'Activity', 'Settings'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[index]),
        actions: [
          if (index == 2)
            IconButton(
              tooltip: 'Buy the developer a coffee',
              icon: const Icon(Icons.coffee),
              onPressed: () => openBuyCoffee(context, ref),
            ),
          const ConnectionStatusChip(),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: const [
          WalletListScreen(),
          ActivityScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          ref.read(shellTabIndexProvider.notifier).state = i;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallets',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
