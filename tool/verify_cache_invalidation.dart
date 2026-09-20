// Checks that the per-element memoization in `lib/src/cache.dart` cannot go
// stale when a file is edited.
//
// Every rule built on this toolkit caches answers about elements in an
// `Expando` keyed on the element. That is only sound if editing a file
// produces *fresh* element objects, so a cached answer can never be read back
// for a declaration whose source has changed. The guarantee belongs to the
// analyzer rather than to this package, which makes it exactly the kind of
// assumption worth checking rather than reasoning about.
//
// The check runs against a real annotation in a real package, resolved by the
// real analyzer: a temporary package declares an annotation, applies it to a
// field, is resolved, then has the annotation edited away and is resolved
// again. A finder that answered "still annotated" the second time would mean
// the cache had outlived the source it described.
//
//     dart run tool/verify_cache_invalidation.dart
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin_toolkit/analyzer_plugin_toolkit.dart';

Future<void> main() async {
  final dir = Directory.systemTemp.createTempSync('toolkit_cache_check');
  try {
    await _run(dir);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

Future<void> _run(Directory dir) async {
  final root = dir.path;

  File('$root/pubspec.yaml').writeAsStringSync('''
name: marker
environment:
  sdk: ^3.13.2
''');
  // A minimal package config, so the analyzer resolves `package:marker`
  // without a `pub get` in a throwaway directory.
  Directory('$root/.dart_tool').createSync();
  File('$root/.dart_tool/package_config.json').writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "marker",
      "rootUri": "../",
      "packageUri": "lib/",
      "languageVersion": "3.13"
    }
  ]
}
''');
  Directory('$root/lib').createSync();
  File('$root/lib/marker.dart').writeAsStringSync('''
/// The annotation this check looks for.
final class Marker {
  const Marker();
}
''');

  final target = File('$root/lib/subject.dart');

  // First revision: the field carries the annotation.
  target.writeAsStringSync('''
import 'package:marker/marker.dart';

class Subject {
  @Marker()
  final Object field = Object();
}
''');

  final collection = AnalysisContextCollection(
    includedPaths: [root],
    resourceProvider: PhysicalResourceProvider.INSTANCE,
  );
  final context = collection.contextFor(target.path);

  // One finder across both revisions: a fresh finder per revision would have
  // an empty cache and could not possibly return a stale answer, so it would
  // prove nothing.
  final finder = AnnotationFinder('marker');

  final before = await _fieldOf(context, target.path);
  final annotatedBefore = finder.has(before, 'Marker');

  // Second revision: the annotation is gone. If the cache outlived the source
  // it describes, the stale `true` is read back here.
  target.writeAsStringSync('''
import 'package:marker/marker.dart';

class Subject {
  final Object field = Object();
}
''');
  context.changeFile(target.path);
  await context.applyPendingFileChanges();

  final after = await _fieldOf(context, target.path);
  final annotatedAfter = finder.has(after, 'Marker');

  stdout
    ..writeln('before edit: annotated = $annotatedBefore')
    ..writeln('after  edit: annotated = $annotatedAfter')
    ..writeln('element identity reused: ${identical(before, after)}');

  if (!annotatedBefore) {
    stderr.writeln(
      'FAIL: the annotation was not seen before the edit, so the check never '
      'exercised the cache.',
    );
    exit(1);
  }
  if (annotatedAfter) {
    stderr.writeln(
      'FAIL: a stale cached answer survived the edit. The memoization in '
      'lib/src/cache.dart is unsound.',
    );
    exit(1);
  }
  stdout.writeln(
    'OK: editing a file yields fresh elements, so no cached answer can be '
    'read back for changed source.',
  );
}

/// Returns the `field` element of `Subject` in the unit at [path].
Future<Element?> _fieldOf(AnalysisContext context, String path) async {
  final result = await context.currentSession.getResolvedUnit(path);
  if (result is! ResolvedUnitResult) {
    stderr.writeln('FAIL: could not resolve $path');
    exit(1);
  }
  final subject = result.libraryElement.getClass('Subject');
  if (subject == null) {
    stderr.writeln('FAIL: no class Subject');
    exit(1);
  }
  return subject.getField('field')?.baseElement;
}
