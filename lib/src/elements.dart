import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';

/// Maps a resolved element onto the declaration a rule reasons about.
///
/// Two analyzer details get in the way of comparing elements by identity, and
/// both are normalized away here. Reading a field resolves to its synthetic
/// getter rather than to the field, and a member reached through a generic
/// class resolves to a `*Member` wrapper rather than to the declaration. A
/// rule that compared the raw elements would fail to recognise the field it is
/// tracking in either case.
Element? normalizeElement(Element? element) {
  if (element == null) {
    return null;
  }
  if (element is PropertyAccessorElement) {
    return element.variable.baseElement;
  }
  return element.baseElement;
}

/// Returns the element [expression] refers to, looking through the wrappers
/// that do not change which declaration is denoted: parentheses,
/// null-assertions, `this.` access and synthetic property accessors.
///
/// Returns `null` for anything that is not a plain reference to a variable, a
/// parameter or a field.
///
/// [anyTarget] decides whose state counts. By default only the enclosing
/// instance's own members resolve, so `other.field` yields `null`: a rule
/// about an object cleaning up after itself must not be satisfied by somebody
/// else's field of the same name. With [anyTarget] set, a member resolves
/// whatever it is read from, so `session.token` denotes the `token` field,
/// which is what a rule about a value's secrecy needs: a secret read from
/// another object is still the same annotated declaration.
Element? referencedElement(Expression? expression, {bool anyTarget = false}) {
  if (expression == null) {
    return null;
  }
  final target = expression.unParenthesized;
  if (target is SimpleIdentifier) {
    return normalizeElement(target.element);
  }
  if (target is PrefixedIdentifier) {
    // `prefix.name` only refers to our own state when `prefix` is an import
    // prefix. When it is a variable or a field, this is somebody else's
    // member, as in `peer._controller`.
    if (anyTarget || target.prefix.element is PrefixElement) {
      return normalizeElement(target.identifier.element);
    }
    return null;
  }
  if (target is PropertyAccess) {
    // Only `this.field` counts; `other.field` refers to somebody else's state.
    if (anyTarget || target.target is ThisExpression) {
      return normalizeElement(target.propertyName.element);
    }
    return null;
  }
  if (target is PostfixExpression && target.operator.type == TokenType.BANG) {
    return referencedElement(target.operand, anyTarget: anyTarget);
  }
  return null;
}
