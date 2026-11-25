import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

const _textWidgets = {'Text', 'SelectableText', 'TextSpan', 'Tooltip'};

const _textArguments = {
  'text',
  'label',
  'title',
  'subtitle',
  'body',
  'message',
  'hint',
  'hintText',
  'labelText',
  'helperText',
  'errorText',
  'placeholder',
  'tooltip',
  'semanticLabel',
  'semanticsLabel',
  'actionLabel',
  'confirmLabel',
  'cancelLabel',
};

/// Collects string literals with letters that are shown to the user.
class _HardCodedStringFinder extends RecursiveAstVisitor<void> {
  _HardCodedStringFinder(this.path, this.unit);

  final String path;
  final CompilationUnit unit;
  final List<String> findings = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.name.lexeme;
    if (_textWidgets.contains(type)) {
      final first = node.argumentList.arguments.firstOrNull;
      if (first is StringLiteral) {
        _check(first);
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null && _textWidgets.contains(node.methodName.name)) {
      final first = node.argumentList.arguments.firstOrNull;
      if (first is StringLiteral) {
        _check(first);
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedArgument(NamedArgument node) {
    final expression = node.argumentExpression;
    if (_textArguments.contains(node.name.lexeme) &&
        expression is StringLiteral) {
      _check(expression);
    }
    super.visitNamedArgument(node);
  }

  /// Records [literal] when its fixed text contains a letter.
  void _check(StringLiteral literal) {
    final fixed = switch (literal) {
      SimpleStringLiteral(:final value) => value,
      StringInterpolation(:final elements) =>
        elements.whereType<InterpolationString>().map((e) => e.value).join(),
      AdjacentStrings(:final strings) =>
        strings.map((s) => s.toSource()).join(),
    };
    if (RegExp(r'\p{L}', unicode: true).hasMatch(fixed)) {
      final line = unit.lineInfo.getLocation(literal.offset).lineNumber;
      findings.add('$path:$line ${literal.toSource()}');
    }
  }
}

/// Returns the hard-coded user-visible strings in [source], labelled with [path] and line.
List<String> findHardCodedStrings(String path, String source) {
  final unit = parseString(content: source).unit;
  final finder = _HardCodedStringFinder(path, unit);
  unit.accept(finder);
  return finder.findings;
}

void main() {
  test('the check catches literals in text widgets and text arguments', () {
    const source = """
Widget a() => Text('Hello');
Widget b() => Button(label: 'Save \$name');
Widget c() => Text('\${count} · \${total}');
Widget d() => Button(onTap: go, text: l10n.save, key: Key('save'));
Widget e() => const TextSpan(text: 'Bonjour');
""";
    final findings = findHardCodedStrings('x.dart', source);
    expect(findings, hasLength(3));
    expect(findings[0], contains('x.dart:1'));
    expect(findings[2], contains('Bonjour'));
  });

  test('presentation code has no hard-coded user-visible strings (AC-11.1)', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              f.path.contains('${Platform.pathSeparator}presentation') ||
              f.path.contains(
                'common${Platform.pathSeparator}widgets${Platform.pathSeparator}',
              ),
        )
        .toList();
    expect(files, isNotEmpty);
    final findings = <String>[];
    for (final file in files) {
      findings.addAll(findHardCodedStrings(file.path, file.readAsStringSync()));
    }
    expect(findings, isEmpty, reason: findings.join('\n'));
  });
}
