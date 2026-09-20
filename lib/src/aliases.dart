import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_plugin_toolkit/src/elements.dart';

/// The maximum length of a local-alias chain that is followed.
///
/// Alias chains cannot contain cycles (an initializer always precedes the
/// variable it initializes), so this is a cheap safety net rather than a
/// correctness requirement.
const aliasDepthLimit = 8;

/// Resolves references to the declarations they may refer to, within the body
/// of a single function.
///
/// Resolution returns a *set*, because one expression can refer to several
/// declarations: `cond ? _a : _b` is either field, and the loop variable of
/// `for (final c in [_a, _b])` takes both in turn. A local variable is an
/// alias for its initializer only when it is never assigned again, so
/// `var x = _c; x = other;` resolves to nothing.
final class AliasResolver {
  /// Builds a resolver for the aliases declared inside [body].
  ///
  /// [anyTarget] is forwarded to [referencedElement], so a resolver built with
  /// it also sees members read from other objects.
  ///
  /// The walk over [body] is deferred until the first question is asked.
  /// Callers routinely build a resolver for a member and then find nothing
  /// worth resolving in it, and a member that is never asked about should not
  /// cost a traversal of its whole body.
  AliasResolver.forBody(this._body, {this.anyTarget = false});

  final AstNode _body;

  /// Whether a member read from any object resolves, rather than only the
  /// enclosing instance's own state. Forwarded to [referencedElement].
  final bool anyTarget;

  late final _AliasCollector _aliases = _collect();

  /// Walks the body, once, on the first call that needs it.
  _AliasCollector _collect() {
    final collector = _AliasCollector();
    _body.accept(collector);
    return collector;
  }

  /// Whether [expression] may refer to [target].
  bool refersTo(Expression? expression, Element target) =>
      resolve(expression).contains(target);

  /// Returns every declaration [expression] may refer to.
  Set<Element> resolve(Expression? expression, [int depth = 0]) {
    if (expression == null || depth > aliasDepthLimit) {
      return const {};
    }
    final target = expression.unParenthesized;
    if (target is ConditionalExpression) {
      return {
        ...resolve(target.thenExpression, depth + 1),
        ...resolve(target.elseExpression, depth + 1),
      };
    }
    final element = referencedElement(target, anyTarget: anyTarget);
    if (element == null) {
      return const {};
    }
    if (element is! LocalVariableElement) {
      return {element};
    }
    if (_aliases.reassigned.contains(element)) {
      return const {};
    }
    return {
      for (final initializer
          in _aliases.initializers[element] ?? const <Expression>[])
        ...resolve(initializer, depth + 1),
    };
  }
}

/// Collects local-variable initializers and assignments inside one function
/// body.
///
/// Nested function bodies are visited too. That is intentionally permissive:
/// a closure that disposes a field still disposes it, and the locals of a
/// closure are distinct elements, so they cannot collide with the outer ones.
final class _AliasCollector extends RecursiveAstVisitor<void> {
  final Map<Element, List<Expression>> initializers = {};
  final Set<Element> reassigned = {};

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    final element = node.declaredFragment?.element;
    final initializer = node.initializer;
    if (element != null && initializer != null) {
      _record(element, initializer);
    }
    super.visitVariableDeclaration(node);
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    // `for (final c in [_a, _b])` binds `c` to each element in turn, so the
    // loop variable aliases every element of a literal collection.
    final element = node.loopVariable.declaredFragment?.element;
    if (element != null) {
      for (final expression in _elementsOf(node.iterable)) {
        _record(element, expression);
      }
    }
    super.visitForEachPartsWithDeclaration(node);
  }

  /// Returns the expressions a collection literal is built from.
  ///
  /// Only literals are understood; anything else yields nothing, which simply
  /// means the loop variable is not treated as an alias.
  List<Expression> _elementsOf(Expression iterable) {
    final target = iterable.unParenthesized;
    if (target is! ListLiteral && target is! SetOrMapLiteral) {
      return const [];
    }
    final elements = target is ListLiteral
        ? target.elements
        : (target as SetOrMapLiteral).elements;
    return [
      for (final element in elements)
        if (element is Expression)
          element
        else if (element is SpreadElement)
          ..._elementsOf(element.expression),
    ];
  }

  void _record(Element element, Expression initializer) =>
      initializers.putIfAbsent(element.baseElement, () => []).add(initializer);

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final element = referencedElement(node.leftHandSide);
    if (element != null) {
      reassigned.add(element);
    }
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    if (node.operator.type != TokenType.BANG) {
      final element = referencedElement(node.operand);
      if (element != null) {
        reassigned.add(element);
      }
    }
    super.visitPostfixExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    const mutating = {TokenType.PLUS_PLUS, TokenType.MINUS_MINUS};
    if (mutating.contains(node.operator.type)) {
      final element = referencedElement(node.operand);
      if (element != null) {
        reassigned.add(element);
      }
    }
    super.visitPrefixExpression(node);
  }
}
