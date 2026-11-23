import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/enums/loading_status.dart';
import '../../../../core/api/body/authentication/sign_in/sign_in_body.dart';
import '../../../../core/data/base/result.dart';
import '../../../../core/di/di.dart';
import '../repository/authentication_repository.dart';
import '../state/authentication_state.dart';

/// TODO: This notifier is for template purpose
///
final authenticationNotifierProvider =
    NotifierProvider<AuthenticationNotifier, AuthenticationState>(
      () => AuthenticationNotifier(getIt.get<AuthenticationRepository>()),
    );

class AuthenticationNotifier extends Notifier<AuthenticationState> {
  AuthenticationNotifier(this._authenticationRepository);
  final AuthenticationRepository _authenticationRepository;

  Future<void> signIn() async {
    state = state.copyWith(loadingStatus: LoadingStatus.loading);
    final result = await _authenticationRepository.signIn(
      body: SignInBody(email: 'email', password: 'password'),
    );
    switch (result) {
      case Success():
        state = state.copyWith(loadingStatus: LoadingStatus.done);
      case Failed():
        state = state.copyWith(loadingStatus: LoadingStatus.error);
    }
  }

  @override
  AuthenticationState build() => AuthenticationState();
}
