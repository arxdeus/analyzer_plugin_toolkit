// Demonstrates the building blocks in `analyzer_plugin_toolkit`, in the shape
// a real annotation-driven rule uses them.
//
// The rule sketched here reports a field annotated with `@Owned` that the
// declaring class never releases. The rule itself is not the point: the point
// is the four toolkit pieces it leans on, each marked below.

import 'dart:io';

import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin_toolkit/analyzer_plugin_toolkit.dart';

// ---------------------------------------------------------------------------
// 1. AnnotationFinder: recognise *your* annotation, quickly.
// ---------------------------------------------------------------------------

/// Matches on the declaring package, not on the class name alone, so a
/// same-named `Owned` from an unrelated package cannot drive this rule.
///
/// One finder for the whole rule, because it memoizes per element: a
/// declaration is inspected once no matter how many times a file mentions it,
/// and the memo table lives exactly as long as the element does.
final _annotations = AnnotationFinder('owned_lint');

/// The `@Owned` annotation on [element], or `null` when it carries none.
///
/// `valueOf` hands back a `DartObject` rather than a decoded record, which is
/// what keeps the toolkit free of any one plugin's annotation shapes. Read the
/// fields with `getField`.
({String? reason})? ownedAnnotation(Element? element) {
  final value = _annotations.valueOf(element, 'Owned');
  if (value == null) {
    return null;
  }
  return (reason: value.getField('reason')?.toStringValue());
}

// ---------------------------------------------------------------------------
// 2. ElementCache: memoize an answer that depends only on the element.
// ---------------------------------------------------------------------------

/// Whether a class declares a `release()` method, cached per element.
///
/// This is the kind of question asked once per *mention* but answered
/// identically every time. `of` computes on a miss and returns the memo on a
/// hit. Because the table is keyed by element identity, and an edit produces
/// fresh elements, a stale answer can never be served for changed source.
final _releasable = ElementCache<InterfaceElement, bool>('releasable');

bool hasRelease(InterfaceElement element) => _releasable.of(
  element,
  () => element.methods.any((method) => method.name == 'release'),
);

// ---------------------------------------------------------------------------
// The rule, which also uses `normalizeElement`, `referencedElement` and
// `AliasResolver`.
// ---------------------------------------------------------------------------

final class MissingRelease extends AnalysisRule {
  MissingRelease()
    : super(
        name: 'missing_release',
        description: 'Fields annotated with @Owned must be released.',
      );

  static const _code = LintCode(
    'missing_release',
    "The field '{0}' is annotated with '@Owned' but is never released.",
  );

  @override
  DiagnosticCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final members = node.body.members;

    // Collect the annotated fields.
    final owned = <VariableDeclaration, Element>{};
    for (final member in members) {
      if (member is! FieldDeclaration) {
        continue;
      }
      for (final variable in member.fields.variables) {
        final element = variable.declaredFragment?.element;
        if (element != null && ownedAnnotation(element) != null) {
          // 3. normalizeElement: the analyzer hands the same field back as a
          //    getter, a setter or the variable itself depending on where it
          //    was seen. Normalizing first is what makes the comparison at
          //    the bottom of this method meaningful.
          owned[variable] = normalizeElement(element)!;
        }
      }
    }
    if (owned.isEmpty) {
      return;
    }

    // Find what each member releases.
    final released = <Element>{};
    for (final member in members) {
      if (member is MethodDeclaration) {
        final body = member.body;
        body.visitChildren(
          _ReleaseCollector(AliasResolver.forBody(body), released),
        );
      }
    }

    for (final entry in owned.entries) {
      if (!released.contains(entry.value)) {
        rule.reportAtToken(entry.key.name, arguments: [entry.key.name.lexeme]);
      }
    }
  }
}

final class _ReleaseCollector extends RecursiveAstVisitor<void> {
  _ReleaseCollector(this.aliases, this.released);

  /// 4. AliasResolver: follows a value through the local names it hides
  ///    behind, so `final c = _connection; c.release();` counts as releasing
  ///    the field rather than releasing an unrelated local.
  final AliasResolver aliases;

  final Set<Element> released;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'release') {
      // `referencedElement` unwraps the shapes a target takes: a plain name,
      // a prefixed one, `this.field`, or a null-asserted `field!`.
      final target = referencedElement(node.target);
      final normalized = normalizeElement(target);
      if (normalized != null) {
        released.add(normalized);
      }
      released.addAll(aliases.resolve(node.target));
    }
    super.visitMethodInvocation(node);
  }
}

void main() {
  final rule = MissingRelease();
  stdout.writeln('${rule.name}: ${rule.description}');

  // `hasRelease` is used by a complete version of this rule, to check that the
  // annotated type actually offers the method the fix would call. Referenced
  // here so the example compiles as an executable library.
  stdout.writeln('cache helper: ${hasRelease.runtimeType}');
}
