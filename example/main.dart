// Opens a book, prints its contents, and shows lazy sentence segmentation —
// the reason to take this package, not just its table of contents.
//
// Usage: dart run example/main.dart path/to/book.epub

import 'dart:io';
import 'dart:typed_data';

import 'package:ebook_parser/ebook_parser.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run example/main.dart <book.epub|book.fb2|book.fb2.zip>');
    exit(2);
  }
  final path = args.first;
  final bytes = Uint8List.fromList(File(path).readAsBytesSync());

  // Pass the path and the bytes you hold; magic bytes decide the format,
  // and a .fb2.zip is unwrapped transparently.
  final parser = bookParserFor(path, bytes);
  if (parser == null) {
    stderr.writeln('Not a supported book format.');
    exit(1);
  }

  // The cheap path: title, authors, language, cover — no chapter is read.
  final metaResult =
      await parser.parseMetadata(bytes, fallbackLanguageCode: 'en');
  if (metaResult case ParseOk(value: final meta)) {
    print('Title:    ${meta.title ?? '(none declared)'}');
    print('Authors:  ${meta.authors.join(', ')}');
    print('Language: ${meta.sourceLanguageCode}');
    print('Cover:    ${meta.cover == null ? 'none' : '${meta.cover!.mediaType}, ${meta.cover!.bytes.length} bytes'}');
  }

  // The full parse. CPU-bound: on a large book, run it through Isolate.run.
  final result = await parser.parse(bytes, fallbackLanguageCode: 'en');
  switch (result) {
    case ParseErr(:final failure):
      // Branch on the kind for user-facing text; the message is for logs.
      stderr.writeln('Could not parse (${failure.kind.name}): ${failure.message}');
      exit(1);
    case ParseOk(value: final document):
      print('\nContents:');
      for (final chapter in document.chapters) {
        final indent = '  ' * chapter.level;
        print('  $indent${chapter.title ?? '(untitled)'} '
            '(${chapter.blocks.length} blocks)');
      }

      // Sentences are segmented lazily, on first access, per paragraph.
      final paragraph = document.chapters
          .expand((c) => c.blocks)
          .whereType<ParagraphBlock>()
          .firstOrNull;
      if (paragraph != null) {
        print('\nFirst paragraph, segmented:');
        for (final sentence in paragraph.sentences.take(3)) {
          print('  [${sentence.start}..${sentence.end}] ${sentence.text}');
        }
      }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
