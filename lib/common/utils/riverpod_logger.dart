import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';

base class RiverpodLogger extends ProviderObserver {
  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final provider = context.provider;
    log('''
        {
          "provider_add": "${provider.name ?? provider.runtimeType}",
          "value": "$value"
        }
    ''', name: '${provider.name ?? provider.runtimeType}');
  }

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    final provider = context.provider;
    log('''
          {
            "provider": "${provider.name ?? provider.runtimeType}",
            "newValue": "$newValue"
          }
    ''', name: '${provider.name ?? provider.runtimeType}');
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    final provider = context.provider;
    log('''
        {
          "provider_dispose_called": "${provider.name ?? provider.runtimeType}",
        }
    ''', name: '${provider.name ?? provider.runtimeType}');
  }
}
