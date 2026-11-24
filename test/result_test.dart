import 'package:lingo_mate/core/data/base/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Result.success holds the value', () {
    final result = Result.success(42);

    expect(result, isA<Success<int>>());
    expect((result as Success<int>).value, 42);
  });

  test('Failed reports an undefined error for a non-Dio exception', () {
    final result = Result<int>.failed(UseCaseException(Exception('boom')));

    expect(result, isA<Failed<int>>());
    expect((result as Failed<int>).errorCode, errorNotDefined);
  });
}
