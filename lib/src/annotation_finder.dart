import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer_plugin_toolkit/src/cache.dart';

/// Finds the annotations of one package on the elements a rule is looking at.
///
/// A plugin whose rules are driven by annotations has to answer the same
/// question everywhere: does this declaration carry *my* annotation? Getting
/// that right is more than a name comparison, and getting it fast is more than
/// a constant evaluation, so both are done once here rather than in each
/// plugin.
///
/// ## Why the package matters
///
/// Annotations are matched by class name *and* by the package that declares
/// them. Matching on the name alone would let somebody else's `Throws` or
/// `Disposable`, from an unrelated package, drive rules that know nothing
/// about it. Matching on the exact library URI would be too strict instead:
/// a package may re-export its annotations from several libraries, and a rule
/// should not care which one the user imported.
///
/// ## Why it is fast
///
/// Two things make the naive version slow. Evaluating a constant is the most
/// expensive thing a rule does, and real code is full of annotations belonging
/// to somebody else (`@override`, `@immutable`, a code generator's), so the
/// evaluation is almost always wasted. And the same element is asked about
/// once per *mention*, though the answer depends only on the element.
///
/// So a candidate is rejected by name before it is evaluated, and the final
/// answer is memoized per element. See [ElementCache] for what the memo
/// table's lifetime is tied to.
final class AnnotationFinder {
  /// Creates a finder for annotations declared by the package named
  /// [package].
  ///
  /// [cacheName] labels the memo table for debugging, and defaults to the
  /// package name.
  AnnotationFinder(this.package, {String? cacheName})
    : _values = ElementCache<Element, Map<String, DartObject?>>(
        cacheName ?? package,
      );

  /// The package whose annotations this finder recognises.
  final String package;

  /// The annotations found on an element, keyed by class name.
  ///
  /// Keyed per element rather than per (element, name) pair so that one
  /// element costs one cache entry no matter how many annotation classes the
  /// plugin asks about. The inner map is filled lazily, one class at a time.
  final ElementCache<Element, Map<String, DartObject?>> _values;

  /// Returns the value of the annotation named [className] on [element], or
  /// `null` when [element] does not carry it.
  ///
  /// The value is a [DartObject], so a caller reads the annotation's fields
  /// with `getField`. Returning the object rather than a decoded record keeps
  /// this package free of any particular plugin's annotation shapes.
  DartObject? valueOf(Element? element, String className) {
    if (element == null) {
      return null;
    }
    final found = _values.of(element, () => <String, DartObject?>{});
    if (found.containsKey(className)) {
      return found[className];
    }
    final value = _computeValue(element, className);
    found[className] = value;
    return value;
  }

  /// Whether [element] carries the annotation named [className].
  bool has(Element? element, String className) =>
      valueOf(element, className) != null;

  /// Finds the annotation without consulting the memo table.
  DartObject? _computeValue(Element element, String className) {
    for (final annotation in element.metadata.annotations) {
      if (!_mayBe(annotation, className)) {
        continue;
      }
      final value = annotation.computeConstantValue();
      if (value != null && _isOurs(value, className)) {
        return value;
      }
    }
    return null;
  }

  /// Whether [annotation] could be the annotation named [className], judged
  /// without evaluating it.
  ///
  /// `@Disposable()` resolves to the constructor of the annotation class, and
  /// `@disposable` (a `const` variable holding one) resolves to a getter. The
  /// constructor case is decided here in full, which is what covers ordinary
  /// code. The getter case cannot be decided without knowing the variable's
  /// value, so it falls through to evaluation rather than being rejected: a
  /// wrong "no" here would silently disable a rule, while a wrong "maybe"
  /// only costs one evaluation.
  bool _mayBe(ElementAnnotation annotation, String className) {
    final element = annotation.element;
    if (element is ConstructorElement) {
      final enclosing = element.enclosingElement;
      return enclosing.name == className && declares(enclosing.library);
    }
    return true;
  }

  /// Whether [value] is an instance of this package's class named
  /// [className].
  bool _isOurs(DartObject value, String className) {
    final type = value.type;
    if (type is! InterfaceType) {
      return false;
    }
    final element = type.element;
    if (element.name != className) {
      return false;
    }
    return declares(element.library);
  }

  /// Whether [library] belongs to the package this finder recognises.
  ///
  /// Compares the first path segment of a `package:` URI, so every library of
  /// the package counts, whichever one re-exports the annotation.
  bool declares(LibraryElement library) {
    final uri = library.uri;
    return uri.scheme == 'package' &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.first == package;
  }
}
