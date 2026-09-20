import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';

/// Returns the body of [element], when it is declared in one of the units
/// currently under analysis.
///
/// Returns `null` for elements declared in another library, including other
/// libraries of the same package. That is the fundamental limit of this
/// plugin's helper analysis: callers fall back to a name-based heuristic.
FunctionBody? bodyOf(ExecutableElement? element, RuleContext context) {
  if (element == null) {
    return null;
  }
  final fragment = element.baseElement.firstFragment;
  final path = fragment.libraryFragment.source.fullName;
  final offset = fragment.nameOffset ?? fragment.offset;
  for (final unit in context.allUnits) {
    if (unit.file.path != path) {
      continue;
    }
    final node = unit.unit.nodeCovering(offset: offset);
    final declaration = node?.thisOrAncestorMatching(
      (node) =>
          node is MethodDeclaration ||
          node is FunctionDeclaration ||
          node is ConstructorDeclaration,
    );
    return switch (declaration) {
      MethodDeclaration(:final body) => body,
      FunctionDeclaration(
        functionExpression: FunctionExpression(:final body),
      ) =>
        body,
      ConstructorDeclaration(:final body) => body,
      _ => null,
    };
  }
  return null;
}
