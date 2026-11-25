import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_mate/core/auth/auth_models.dart';

void main() {
  test('initials come from the name, else the email', () {
    AppUser user({String? name, String? email}) => AppUser(
      uid: 'u',
      provider: AuthProviderKind.google,
      displayName: name,
      email: email,
    );

    expect(user(name: 'Alex Morgan').initials, 'AM');
    expect(user(name: 'Trần Quang Minh').initials, 'TM');
    expect(user(email: 'minh.tran@example.com').initials, 'MT');
    expect(user(email: 'linh@example.com').initials, 'LI');
    expect(user().initials, '?');
  });

  test('only linked, signed-in and switched results count as success', () {
    expect(const SignInResult(SignInOutcome.linked).succeeded, isTrue);
    expect(const SignInResult(SignInOutcome.switchedAccount).succeeded, isTrue);
    expect(const SignInResult(SignInOutcome.cancelled).succeeded, isFalse);
  });
}
