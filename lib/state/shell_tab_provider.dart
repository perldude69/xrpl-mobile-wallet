import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom-nav index for [MainShell] (0 Wallets, 1 Activity, 2 Settings).
final shellTabIndexProvider = StateProvider<int>((ref) => 0);
