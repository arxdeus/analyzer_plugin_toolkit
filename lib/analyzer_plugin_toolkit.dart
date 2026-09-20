/// Shared building blocks for annotation-driven Dart analyzer plugins.
///
/// These are the pieces every such plugin needs and none of them should have
/// to write twice: recognising *your* annotation rather than a same-named one
/// from somebody else's package, doing that fast enough to run on every node
/// of every file, comparing elements that the analyzer hands back in more than
/// one shape, and following a value through the local aliases it hides behind.
///
/// No harness for asserting what a quick fix produces ships here: one has to
/// depend on `package:test`, which a plugin's `lib/` may not pull in.
library;

export 'package:analyzer_plugin_toolkit/src/aliases.dart';
export 'package:analyzer_plugin_toolkit/src/annotation_finder.dart';
export 'package:analyzer_plugin_toolkit/src/cache.dart';
export 'package:analyzer_plugin_toolkit/src/declarations.dart';
export 'package:analyzer_plugin_toolkit/src/elements.dart';
