import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin_toolkit/analyzer_plugin_toolkit.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnnotationFinderTest);
  });
}

/// The annotation the finder under test is looking for, declared by a package
/// called `mine`.
const _mineSource = '''
final class Marker {
  const Marker([this.reason]);
  final String? reason;
}

const marker = Marker();
''';

/// A *different* package declaring an annotation of the same name.
///
/// This is the case a name-only comparison gets wrong, and the reason the
/// finder resolves by package.
const _theirsSource = '''
final class Marker {
  const Marker([this.reason]);
  final String? reason;
}
''';

/// A rule that reports nothing.
///
/// `AnalysisRuleTest` is built for testing rules and insists on having one,
/// but the subject here is the finder rather than any rule. This satisfies the
/// harness while contributing no diagnostics of its own, so nothing it does
/// can affect what the tests observe.
final class _NoOpRule extends AnalysisRule {
  _NoOpRule() : super(name: 'no_op', description: 'Reports nothing.');

  static const LintCode _code = LintCode(
    'no_op',
    'This rule never reports.',
    uniqueName: 'LintCode.no_op',
  );

  @override
  DiagnosticCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {}
}

@reflectiveTest
class AnnotationFinderTest extends AnalysisRuleTest {
  /// A finder for the annotations of `package:mine`.
  final AnnotationFinder finder = AnnotationFinder('mine');

  @override
  void setUp() {
    rule = _NoOpRule();
    newPackage('mine').addFile('lib/mine.dart', _mineSource);
    newPackage('theirs').addFile('lib/theirs.dart', _theirsSource);
    super.setUp();
  }

  /// Resolves [content] and returns the class named [name].
  Future<Element> _classNamed(String content, String name) async {
    newFile(testFile.path, content);
    final result = await resolveFile(testFile.path);
    final errors = result.diagnostics.where((d) => d.severity.name == 'ERROR');
    expect(errors, isEmpty, reason: 'the fixture must compile: $errors');
    final element = result.libraryElement.getClass(name);
    expect(element, isNotNull, reason: 'no class named $name');
    return element!;
  }

  Future<void> test_findsTheAnnotationOfItsOwnPackage() async {
    final element = await _classNamed('''
import 'package:mine/mine.dart';

@Marker()
class Target {}
''', 'Target');

    expect(finder.has(element, 'Marker'), isTrue);
  }

  Future<void> test_readsTheAnnotationsFields() async {
    final element = await _classNamed('''
import 'package:mine/mine.dart';

@Marker('because')
class Target {}
''', 'Target');

    final value = finder.valueOf(element, 'Marker');
    expect(value, isNotNull);
    expect(value!.getField('reason')?.toStringValue(), 'because');
  }

  Future<void> test_rejectsSameNameFromAnotherPackage() async {
    // The case that matters. Somebody else's `Marker` must not drive rules
    // that know nothing about it, and only the declaring package tells the
    // two apart.
    final element = await _classNamed('''
import 'package:theirs/theirs.dart';

@Marker()
class Target {}
''', 'Target');

    expect(finder.has(element, 'Marker'), isFalse);
  }

  Future<void> test_findsTheAnnotationThroughAConstVariable() async {
    // `@marker` resolves to a getter rather than to a constructor, so the
    // cheap name filter cannot decide it and must fall through to evaluation.
    // A filter that rejected this would silently disable the rule.
    final element = await _classNamed('''
import 'package:mine/mine.dart';

@marker
class Target {}
''', 'Target');

    expect(finder.has(element, 'Marker'), isTrue);
  }

  Future<void> test_ignoresAnUnrelatedAnnotation() async {
    final element = await _classNamed('''
import 'package:mine/mine.dart';

@deprecated
class Target {}
''', 'Target');

    expect(finder.has(element, 'Marker'), isFalse);
  }

  Future<void> test_reportsNothingForAnUnannotatedElement() async {
    final element = await _classNamed('''
class Target {}
''', 'Target');

    expect(finder.has(element, 'Marker'), isFalse);
    expect(finder.valueOf(element, 'Marker'), isNull);
  }

  Future<void> test_reportsNothingForNull() async {
    expect(finder.has(null, 'Marker'), isFalse);
    expect(finder.valueOf(null, 'Marker'), isNull);
  }

  Future<void> test_distinguishesTwoAnnotationClasses() async {
    // One cache entry per element holds the answers for every class asked
    // about, so a "yes" for one name must not leak into another.
    final element = await _classNamed('''
import 'package:mine/mine.dart';

@Marker()
class Target {}
''', 'Target');

    expect(finder.has(element, 'Marker'), isTrue);
    expect(finder.has(element, 'Absent'), isFalse);
    // Asked a second time, now that both answers are memoized.
    expect(finder.has(element, 'Marker'), isTrue);
    expect(finder.has(element, 'Absent'), isFalse);
  }
}
