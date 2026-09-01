// The package's own EPUB reader: container lookup, OPF, navigation, and
// chapter XHTML — no epubx.
//
// An EPUB chapter is a navigation entry, not a spine item: a spine item
// holding several entries is split at its anchors. Unnavigated spine items
// are kept as untitled chapters, except one the format declares to be the
// table of contents.

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../book_document.dart';
import '../book_metadata.dart';
import '../book_parser.dart';
import '../language_codes.dart';
import '../parse_result.dart';
import '../segmentation/rule_based_segmenter.dart';
import '../segmentation/text_segmenter.dart';
import 'container_reader.dart';
import 'navigation_reader.dart';
import 'package_reader.dart';
import 'xhtml_blocks.dart';

/// Parses `.epub` files.
class EpubParser implements IBookParser {
  @override
  Future<ParseResult<BookDocument>> parse(
    Uint8List bytes, {
    required String fallbackLanguageCode,
    TextSegmenter? segmenter,
  }) async {
    final fallback =
        normalizeLanguageCode(null, fallback: fallbackLanguageCode);
    final opened = _openContainer(bytes);
    if (opened is ParseFailure) return ParseErr(opened);
    final (container, opf) = opened as (EpubContainer, OpfPackage);
    try {
      final metadata = _metadata(opf, container, fallback);
      final effectiveSegmenter = segmenter ??
          RuleBasedSegmenter(languageCode: metadata.sourceLanguageCode);
      final chapters = _chapters(opf, container, effectiveSegmenter);
      if (!chapters.any((c) => c.blocks.isNotEmpty)) {
        return const ParseErr(ParseFailure(
          ParseFailureKind.emptyDocument,
          'EPUB: parsing produced no content blocks in any chapter',
        ));
      }
      return ParseOk(BookDocument(metadata: metadata, chapters: chapters));
    } catch (e) {
      return ParseErr(ParseFailure(
        ParseFailureKind.corrupt,
        'EPUB: failed to read the package contents',
        cause: e,
      ));
    }
  }

  @override
  Future<ParseResult<BookMetadata>> parseMetadata(
    Uint8List bytes, {
    required String fallbackLanguageCode,
  }) async {
    final fallback =
        normalizeLanguageCode(null, fallback: fallbackLanguageCode);
    final opened = _openContainer(bytes);
    if (opened is ParseFailure) return ParseErr(opened);
    final (container, opf) = opened as (EpubContainer, OpfPackage);
    try {
      return ParseOk(_metadata(opf, container, fallback));
    } catch (e) {
      return ParseErr(ParseFailure(
        ParseFailureKind.corrupt,
        'EPUB: failed to read the package metadata',
        cause: e,
      ));
    }
  }

  /// The shared front of both methods: zip, DRM declaration, container.xml,
  /// OPF. Returns the failure or the opened pair. Nothing here touches a
  /// spine item, which is what keeps `parseMetadata` cheap — the zip's
  /// entries are decompressed only when read.
  Object _openContainer(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      return ParseFailure(
        ParseFailureKind.corrupt,
        'EPUB: not a readable zip archive',
        cause: e,
      );
    }
    try {
      final container = EpubContainer(archive);
      if (isDrmProtected(container)) {
        return const ParseFailure(
          ParseFailureKind.drmProtected,
          'EPUB: the container declares encryption over publication '
          'resources (META-INF/encryption.xml or rights.xml)',
        );
      }
      final opfPath = opfPathOf(container);
      if (opfPath == null) {
        return const ParseFailure(
          ParseFailureKind.corrupt,
          'EPUB: META-INF/container.xml is missing or names no rootfile',
        );
      }
      final opfXml = container.readString(opfPath);
      if (opfXml == null) {
        return ParseFailure(
          ParseFailureKind.corrupt,
          'EPUB: the container.xml rootfile "$opfPath" is not in the archive',
        );
      }
      return (container, readOpf(opfXml, opfPath));
    } on XmlException catch (e) {
      return ParseFailure(
        ParseFailureKind.corrupt,
        'EPUB: the OPF package document is not well-formed XML',
        cause: e,
      );
    } catch (e) {
      return ParseFailure(
        ParseFailureKind.corrupt,
        'EPUB: failed to open the container',
        cause: e,
      );
    }
  }

  BookMetadata _metadata(
    OpfPackage opf,
    EpubContainer container,
    String fallback,
  ) {
    ImageData? cover;
    final coverItem = _coverItem(opf);
    if (coverItem != null) {
      final coverBytes = container.readBytes(opf.resolve(coverItem.href));
      if (coverBytes != null) {
        cover = ImageData(
          bytes: coverBytes,
          mediaType: coverItem.mediaType.isNotEmpty
              ? coverItem.mediaType
              : _guessMediaType(coverItem.href),
        );
      }
    }
    return BookMetadata(
      title: opf.title,
      authors: opf.authors,
      sourceLanguageCode:
          normalizeLanguageCode(opf.language, fallback: fallback),
      cover: cover,
    );
  }

  /// The cover manifest item: `properties="cover-image"`, else the
  /// `<meta name="cover">` idref, else a manifest id of `cover`. The two
  /// id-based conventions must name an image item — an id of `cover` is
  /// often the cover *page*, whose text is not what this field carries.
  ManifestItem? _coverItem(OpfPackage opf) {
    for (final item in opf.manifestById.values) {
      if (item.properties.contains('cover-image')) return item;
    }
    ManifestItem? imageItem(String? id) {
      final item = id == null ? null : opf.manifestById[id];
      if (item == null) return null;
      return item.mediaType.startsWith('image/') ? item : null;
    }

    return imageItem(opf.metaCoverId) ?? imageItem('cover');
  }

  List<Chapter> _chapters(
    OpfPackage opf,
    EpubContainer container,
    TextSegmenter segmenter,
  ) {
    // Reading order is the spine, then document order; navigation supplies
    // titles, depth and split points, never order.
    final spinePaths = <String>[];
    for (final idref in opf.spineIdrefs) {
      final item = opf.manifestById[idref];
      if (item == null) continue;
      spinePaths.add(opf.resolve(item.href));
    }

    final navigation = _navigation(opf, container);
    final entries = navigation?.entries ?? const <NavEntry>[];

    // Spine items the format declares to be the table of contents.
    final tocPaths = <String>{...?navigation?.tocDeclaredPaths};
    for (final ref in opf.guide) {
      if (ref.type.toLowerCase() == 'toc') {
        tocPaths.add(opf.resolve(splitFragment(ref.href).path));
      }
    }
    for (final item in opf.manifestById.values) {
      if (item.properties.contains('nav')) {
        tocPaths.add(opf.resolve(item.href));
      }
    }

    final entriesBySpine = <int, List<NavEntry>>{};
    for (final entry in entries) {
      final index = spinePaths.indexOf(entry.path);
      // An entry pointing outside the spine is not in reading order, so it
      // cannot become a chapter.
      if (index < 0) continue;
      (entriesBySpine[index] ??= []).add(entry);
    }

    final chapters = <_ProtoChapter>[];
    var lastLevel = 0;
    for (var s = 0; s < spinePaths.length; s++) {
      final path = spinePaths[s];
      final itemEntries = entriesBySpine[s] ?? const <NavEntry>[];
      if (itemEntries.isEmpty && tocPaths.contains(path)) {
        // A declared table-of-contents page would restate as prose what the
        // chapter list already carries. Only a declaration counts; a page
        // that merely looks like a contents page stays.
        continue;
      }
      final xhtml = container.readString(path);
      if (xhtml == null) {
        // The spine names an entry the archive does not hold. Navigation
        // entries still yield their chapters, empty.
        for (final entry in itemEntries) {
          chapters.add(_ProtoChapter(entry.label, entry.depth, const []));
          lastLevel = entry.depth;
        }
        continue;
      }
      final parsed = blocksFromXhtml(
        xhtml,
        segmenter: segmenter,
        resolveImage: (href) =>
            _resolveImage(opf, container, p.url.dirname(path), href),
      );
      if (itemEntries.isEmpty) {
        // An unnavigated spine item becomes an untitled chapter at the level
        // of the nearest preceding entry — dropped when empty, since it was
        // not produced by a navigation entry.
        if (parsed.blocks.isNotEmpty) {
          chapters.add(_ProtoChapter(null, lastLevel, parsed.blocks));
        }
        continue;
      }
      if (itemEntries.length == 1) {
        // The common case: no splitting, byte-identical to spine
        // granularity. A chapter produced by a navigation entry survives
        // empty.
        final entry = itemEntries.single;
        chapters.add(_ProtoChapter(entry.label, entry.depth, parsed.blocks));
        lastLevel = entry.depth;
        continue;
      }

      // Several entries into one document: split before the block containing
      // each anchor, in document order.
      final resolved = <(NavEntry, int)>[];
      for (final entry in itemEntries) {
        final fragment = entry.fragment;
        // The fragment half of an href is a URI too: a non-ASCII id arrives
        // percent-encoded, while the anchor map is keyed by ids as written —
        // so the raw form is tried first and the decoded form second.
        final int? point = (fragment == null || fragment.isEmpty)
            ? 0
            : parsed.anchors[fragment] ??
                parsed.anchors[_decodedOrRaw(fragment)];
        // An anchor that resolves to nothing drops its entry and produces
        // no split.
        if (point == null) continue;
        resolved.add((entry, point));
      }
      if (resolved.isEmpty) {
        if (parsed.blocks.isNotEmpty) {
          chapters.add(_ProtoChapter(null, lastLevel, parsed.blocks));
        }
        continue;
      }
      // Stable by split point, so entries sharing one keep navigation order.
      final order = List<int>.generate(resolved.length, (i) => i)
        ..sort((a, b) {
          final byPoint = resolved[a].$2.compareTo(resolved[b].$2);
          return byPoint != 0 ? byPoint : a.compareTo(b);
        });
      final sorted = [for (final i in order) resolved[i]];

      // Content before the first anchor: an untitled chapter, dropped when
      // empty — the usual case where the first anchor sits on the document's
      // own heading.
      final firstPoint = sorted.first.$2;
      if (firstPoint > 0) {
        final before = parsed.blocks.sublist(0, firstPoint);
        if (before.isNotEmpty) {
          chapters.add(_ProtoChapter(null, lastLevel, before));
        }
      }
      for (var k = 0; k < sorted.length; k++) {
        final (entry, point) = sorted[k];
        // Entries whose anchors share a split point each still produce a
        // chapter: the shallower ones carry title and level with no blocks,
        // and the last one in navigation order takes the content.
        final lastAtPoint = k + 1 >= sorted.length || sorted[k + 1].$2 != point;
        var end = parsed.blocks.length;
        for (var m = k + 1; m < sorted.length; m++) {
          if (sorted[m].$2 > point) {
            end = sorted[m].$2;
            break;
          }
        }
        chapters.add(_ProtoChapter(
          entry.label,
          entry.depth,
          lastAtPoint ? parsed.blocks.sublist(point, end) : const [],
        ));
        lastLevel = entry.depth;
      }
    }

    return [
      for (var i = 0; i < chapters.length; i++)
        Chapter(
          index: i,
          title: chapters[i].title == null || chapters[i].title!.isEmpty
              ? null
              : chapters[i].title,
          level: chapters[i].level,
          blocks: chapters[i].blocks,
        ),
    ];
  }

  /// The navigation source: the EPUB 3 nav document when the manifest
  /// declares one, else the NCX.
  EpubNavigation? _navigation(OpfPackage opf, EpubContainer container) {
    for (final item in opf.manifestById.values) {
      if (item.properties.contains('nav')) {
        final path = opf.resolve(item.href);
        final xhtml = container.readString(path);
        if (xhtml != null) return readNavDoc(xhtml, p.url.dirname(path));
      }
    }
    ManifestItem? ncxItem;
    final tocId = opf.spineTocId;
    if (tocId != null) ncxItem = opf.manifestById[tocId];
    if (ncxItem == null) {
      for (final item in opf.manifestById.values) {
        if (item.mediaType == 'application/x-dtbncx+xml') {
          ncxItem = item;
          break;
        }
      }
    }
    if (ncxItem == null) return null;
    final path = opf.resolve(ncxItem.href);
    final xml = container.readString(path);
    if (xml == null) return null;
    try {
      return readNcx(xml, p.url.dirname(path));
    } on XmlException {
      // A broken NCX degrades to no navigation rather than failing the book.
      return null;
    }
  }

  ImageData? _resolveImage(
    OpfPackage opf,
    EpubContainer container,
    String baseDir,
    String href,
  ) {
    final path = resolveEpubHref(baseDir, splitFragment(href).path);
    final bytes = container.readBytes(path);
    if (bytes == null) return null;
    String? mediaType;
    for (final item in opf.manifestById.values) {
      if (opf.resolve(item.href) == path && item.mediaType.isNotEmpty) {
        mediaType = item.mediaType;
        break;
      }
    }
    return ImageData(
      bytes: bytes,
      mediaType: mediaType ?? _guessMediaType(path),
    );
  }

  String _decodedOrRaw(String fragment) {
    try {
      return Uri.decodeFull(fragment);
    } catch (_) {
      return fragment;
    }
  }

  String _guessMediaType(String path) =>
      switch (p.url.extension(path).toLowerCase()) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.gif' => 'image/gif',
        '.svg' => 'image/svg+xml',
        '.webp' => 'image/webp',
        _ => 'application/octet-stream',
      };
}

class _ProtoChapter {
  const _ProtoChapter(this.title, this.level, this.blocks);

  final String? title;
  final int level;
  final List<Block> blocks;
}
