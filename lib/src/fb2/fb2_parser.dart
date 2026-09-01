// FB2 reader: a DOM path for parse() — which needs the whole tree anyway —
// and a separate event-streaming path for parseMetadata(), so the cheap
// method never builds nodes over the body or any <binary> but the cover.
// The two paths must agree field by field, which the metadata-invariant test
// guards.

import 'dart:convert';
import 'dart:typed_data';

import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import '../book_document.dart';
import '../book_metadata.dart';
import '../book_parser.dart';
import '../language_codes.dart';
import '../parse_result.dart';
import '../segmentation/rule_based_segmenter.dart';
import '../segmentation/text_segmenter.dart';
import 'fb2_encoding.dart';

/// Parses `.fb2` files.
class Fb2Parser implements IBookParser {
  @override
  Future<ParseResult<BookDocument>> parse(
    Uint8List bytes, {
    required String fallbackLanguageCode,
    TextSegmenter? segmenter,
  }) async {
    final fallback =
        normalizeLanguageCode(null, fallback: fallbackLanguageCode);
    final String content;
    try {
      content = decodeFb2Bytes(bytes);
    } on UnsupportedEncodingException catch (e) {
      return ParseErr(ParseFailure(
        ParseFailureKind.encoding,
        'FB2: declared encoding "${e.name}" has no codec in this package',
        cause: e,
      ));
    }
    final XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } catch (e) {
      return ParseErr(ParseFailure(
        ParseFailureKind.corrupt,
        'FB2: not well-formed XML',
        cause: e,
      ));
    }
    try {
      final root = document.rootElement;
      if (root.name.local != 'FictionBook') {
        return ParseErr(ParseFailure(
          ParseFailureKind.unsupportedFormat,
          'FB2: root element is <${root.name.local}>, not <FictionBook>',
        ));
      }
      final binaries = _binaryIndex(root);
      final metadata = _metadataFromDom(root, binaries, fallback);
      final effectiveSegmenter = segmenter ??
          RuleBasedSegmenter(languageCode: metadata.sourceLanguageCode);
      final chapters = <Chapter>[];
      for (final body in _childrenNamed(root, 'body')) {
        _appendBody(body, chapters, binaries, effectiveSegmenter);
      }
      if (chapters.isEmpty) {
        return const ParseErr(ParseFailure(
          ParseFailureKind.emptyDocument,
          'FB2: parsing produced no content blocks in any section',
        ));
      }
      return ParseOk(BookDocument(metadata: metadata, chapters: chapters));
    } catch (e) {
      return ParseErr(ParseFailure(
        ParseFailureKind.corrupt,
        'FB2: failed to read the document structure',
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
    final String content;
    try {
      content = decodeFb2Bytes(bytes);
    } on UnsupportedEncodingException catch (e) {
      return ParseErr(ParseFailure(
        ParseFailureKind.encoding,
        'FB2: declared encoding "${e.name}" has no codec in this package',
        cause: e,
      ));
    }
    try {
      return ParseOk(_streamMetadata(content, fallback));
    } on _NotFictionBook {
      return const ParseErr(ParseFailure(
        ParseFailureKind.unsupportedFormat,
        'FB2: root element is not <FictionBook>',
      ));
    } catch (e) {
      return ParseErr(ParseFailure(
        ParseFailureKind.corrupt,
        'FB2: metadata reader failed before the end of <description>',
        cause: e,
      ));
    }
  }

  // ---------------------------------------------------------------- DOM path

  void _appendBody(
    XmlElement body,
    List<Chapter> chapters,
    Map<String, XmlElement> binaries,
    TextSegmenter segmenter,
  ) {
    // Body-level content outside any section — a body <title>, an epigraph,
    // an opening image — becomes a preamble chapter so no text is lost.
    String? bodyTitle;
    final preamble = <Block>[];
    for (final child in body.childElements) {
      if (child.name.local == 'section') continue;
      if (child.name.local == 'title') {
        bodyTitle ??= _nonEmpty(_titleText(child));
      }
      _blocksFromElement(child, preamble, 0, binaries, segmenter);
    }
    if (preamble.isNotEmpty) {
      chapters.add(Chapter(
        index: chapters.length,
        title: bodyTitle,
        level: 0,
        blocks: preamble,
      ));
    }
    for (final child in body.childElements) {
      if (child.name.local == 'section') {
        _appendSection(child, chapters, 0, binaries, segmenter);
      }
    }
  }

  /// One chapter per `<section>`; a nested section becomes its own chapter
  /// at the deeper level. A chapter that ends up with no blocks is dropped,
  /// keeping `Chapter.index` dense.
  void _appendSection(
    XmlElement section,
    List<Chapter> chapters,
    int level,
    Map<String, XmlElement> binaries,
    TextSegmenter segmenter,
  ) {
    String? title;
    final own = <Block>[];
    for (final child in section.childElements) {
      if (child.name.local == 'section') continue;
      if (child.name.local == 'title') {
        title ??= _nonEmpty(_titleText(child));
      }
      _blocksFromElement(child, own, level, binaries, segmenter);
    }
    if (own.isNotEmpty) {
      chapters.add(Chapter(
        index: chapters.length,
        title: title,
        level: level,
        blocks: own,
      ));
    }
    for (final child in section.childElements) {
      if (child.name.local == 'section') {
        _appendSection(child, chapters, level + 1, binaries, segmenter);
      }
    }
  }

  /// Maps one FB2 construct onto the three block variants. Text is
  /// preserved, structure is not; a construct not handled explicitly keeps
  /// its text as a paragraph rather than being dropped.
  void _blocksFromElement(
    XmlElement element,
    List<Block> out,
    int level,
    Map<String, XmlElement> binaries,
    TextSegmenter segmenter,
  ) {
    void addParagraph(String text) {
      if (text.isNotEmpty) {
        out.add(ParagraphBlock(text: text, segmenter: segmenter));
      }
    }

    switch (element.name.local) {
      case 'p' || 'v' || 'text-author' || 'code':
        addParagraph(_normalize(element.innerText));
      case 'title':
        final text = _titleText(element);
        if (text.isNotEmpty) {
          out.add(HeadingBlock(text: text, level: level + 1));
        }
      case 'subtitle':
        final text = _normalize(element.innerText);
        if (text.isNotEmpty) {
          out.add(HeadingBlock(text: text, level: level + 2));
        }
      case 'empty-line':
        break;
      case 'stanza':
        final lines = _childrenNamed(element, 'v')
            .map((v) => _normalize(v.innerText))
            .where((t) => t.isNotEmpty);
        addParagraph(lines.join('\n'));
      case 'poem':
        for (final child in element.childElements) {
          if (child.name.local == 'title') {
            final text = _titleText(child);
            if (text.isNotEmpty) {
              out.add(HeadingBlock(text: text, level: level + 2));
            }
          } else {
            _blocksFromElement(child, out, level, binaries, segmenter);
          }
        }
      case 'epigraph' || 'cite' || 'annotation':
        for (final child in element.childElements) {
          _blocksFromElement(child, out, level, binaries, segmenter);
        }
      case 'table':
        // Rows of a nested table are skipped: their text already reaches
        // the outer cell through innerText, and taking them again would
        // duplicate it.
        for (final tr in element.descendantElements.where((e) =>
            e.name.local == 'tr' && _enclosingTable(e) == element)) {
          final cells = tr.childElements
              .where((c) => c.name.local == 'td' || c.name.local == 'th')
              .map((c) => _normalize(c.innerText))
              .where((t) => t.isNotEmpty)
              .join(' ');
          addParagraph(cells);
        }
      case 'image':
        final image = _resolveImage(element, binaries);
        if (image != null) out.add(ImageBlock(image: image));
      default:
        addParagraph(_normalize(element.innerText));
    }
  }

  BookMetadata _metadataFromDom(
    XmlElement root,
    Map<String, XmlElement> binaries,
    String fallback,
  ) {
    final description = _firstChild(root, 'description');
    final titleInfo =
        description == null ? null : _firstChild(description, 'title-info');
    String? title;
    final authors = <String>[];
    String? lang;
    ImageData? cover;
    if (titleInfo != null) {
      title = _nonEmpty(
        _normalize(_firstChild(titleInfo, 'book-title')?.innerText ?? ''),
      );
      for (final author in _childrenNamed(titleInfo, 'author')) {
        final name = _authorName(
          first: _childText(author, 'first-name'),
          middle: _childText(author, 'middle-name'),
          last: _childText(author, 'last-name'),
          nickname: _childText(author, 'nickname'),
        );
        if (name.isNotEmpty) authors.add(name);
      }
      lang = _nonEmpty(_firstChild(titleInfo, 'lang')?.innerText.trim() ?? '');
      final coverpage = _firstChild(titleInfo, 'coverpage');
      final imageEl =
          coverpage == null ? null : _firstChild(coverpage, 'image');
      if (imageEl != null) cover = _resolveImage(imageEl, binaries);
    }
    return BookMetadata(
      title: title,
      authors: authors,
      sourceLanguageCode: normalizeLanguageCode(lang, fallback: fallback),
      cover: cover,
    );
  }

  Map<String, XmlElement> _binaryIndex(XmlElement root) {
    final index = <String, XmlElement>{};
    for (final binary in _childrenNamed(root, 'binary')) {
      final id = binary.getAttribute('id');
      if (id != null) index[id] ??= binary;
    }
    return index;
  }

  /// Resolves an `<image>` reference to its `<binary>` bytes plus the
  /// declared content type, or null when it cannot be resolved — an
  /// unresolvable image is skipped rather than failing the parse.
  ImageData? _resolveImage(
    XmlElement imageEl,
    Map<String, XmlElement> binaries,
  ) {
    String? href;
    for (final attr in imageEl.attributes) {
      if (attr.name.local == 'href') {
        href = attr.value;
        break;
      }
    }
    if (href == null || !href.startsWith('#')) return null;
    final binary = binaries[href.substring(1)];
    if (binary == null) return null;
    final bytes = _decodeBase64(binary.innerText);
    if (bytes == null) return null;
    return ImageData(
      bytes: bytes,
      mediaType:
          binary.getAttribute('content-type') ?? 'application/octet-stream',
    );
  }

  // ------------------------------------------------------------ stream path

  /// The event-based metadata reader: captures `<title-info>` while inside
  /// `<description>`, then reads the one `<binary>` the coverpage names, and
  /// stops. No node is built for the body, and no binary but the cover has
  /// its base64 payload decoded. A named cover binary not seen by the end of
  /// the first pass gets a second targeted pass, so element order cannot
  /// separate this path from the DOM one.
  BookMetadata _streamMetadata(String content, String fallback) {
    var sawRoot = false;
    var inTitleInfo = false;
    var inCoverpage = false;
    var descriptionDone = false;
    // First-wins flags: the DOM path reads the *first* title-info,
    // book-title, lang, coverpage, image and matching binary, so this path
    // must lock onto the first occurrence too — even an empty one.
    var titleInfoDone = false;
    var sawBookTitle = false;
    var sawLang = false;
    var sawCoverpage = false;
    var sawCoverImage = false;
    var coverBinaryTried = false;
    final earlyBinaryIds = <String>{};
    String? title;
    final authors = <String>[];
    String? lang;
    String? coverId;
    Uint8List? coverBytes;
    String? coverMediaType;

    Map<String, String>? authorParts;
    StringBuffer? capture;
    String? captureName;
    var captureDepth = 0;
    StringBuffer? binaryCapture;

    final path = <String>[];

    void handleCaptureEnd() {
      final value = _normalize(capture.toString());
      switch (captureName) {
        case 'book-title':
          title = _nonEmpty(value);
        case 'lang':
          lang = _nonEmpty(value);
        default:
          if (authorParts != null && captureName != null) {
            authorParts[captureName!] = value;
          }
      }
      capture = null;
      captureName = null;
    }

    for (final event in parseEvents(content)) {
      if (event is XmlStartElementEvent) {
        final name = event.localName;
        final parent = path.isEmpty ? null : path.last;
        if (!sawRoot) {
          if (name != 'FictionBook') throw const _NotFictionBook();
          sawRoot = true;
        }
        if (capture != null && !event.isSelfClosing) captureDepth++;
        // Structure is matched by depth, mirroring the DOM path's
        // direct-child lookups: /FictionBook/description is depth 2,
        // its title-info's children depth 3, and so on. A latch alone would
        // also accept the same element name nested deeper, which the DOM
        // path never reads.
        // A self-closing <description/> emits no end event, so the done
        // flag is set right here — otherwise a later sibling description
        // would be read, and the early exit below would never fire.
        if (path.length == 1 &&
            name == 'description' &&
            event.isSelfClosing) {
          descriptionDone = true;
        }
        if (path.length == 2 &&
            parent == 'description' &&
            name == 'title-info' &&
            !titleInfoDone &&
            !descriptionDone) {
          titleInfoDone = true;
          if (!event.isSelfClosing) inTitleInfo = true;
        }
        if (inTitleInfo) {
          if (path.length == 3 && parent == 'title-info' && name == 'author') {
            authorParts = {};
          }
          if (path.length == 3 &&
              parent == 'title-info' &&
              name == 'coverpage' &&
              !sawCoverpage) {
            sawCoverpage = true;
            if (!event.isSelfClosing) inCoverpage = true;
          }
          if (inCoverpage &&
              path.length == 4 &&
              parent == 'coverpage' &&
              name == 'image' &&
              !sawCoverImage) {
            // The first <image> decides, exactly like the DOM path — even
            // one whose href does not resolve to a local binary. And within
            // it, the first href-named attribute decides, even one that is
            // not a local `#` reference.
            sawCoverImage = true;
            String? imageHref;
            for (final attr in event.attributes) {
              if (attr.localName == 'href') {
                imageHref = attr.value;
                break;
              }
            }
            if (imageHref != null && imageHref.startsWith('#')) {
              coverId = imageHref.substring(1);
            }
          }
          if (capture == null) {
            var wanted = false;
            if (path.length == 3 &&
                parent == 'title-info' &&
                name == 'book-title' &&
                !sawBookTitle) {
              sawBookTitle = true;
              wanted = true;
            } else if (path.length == 3 &&
                parent == 'title-info' &&
                name == 'lang' &&
                !sawLang) {
              sawLang = true;
              wanted = true;
            } else if (authorParts != null &&
                path.length == 4 &&
                parent == 'author' &&
                (name == 'first-name' ||
                    name == 'middle-name' ||
                    name == 'last-name' ||
                    name == 'nickname') &&
                !authorParts.containsKey(name)) {
              wanted = true;
            }
            if (wanted) {
              if (event.isSelfClosing) {
                // A self-closing element is the first occurrence with empty
                // text; record it so a later sibling cannot take its place.
                if (authorParts != null && name != 'book-title' &&
                    name != 'lang') {
                  authorParts[name] = '';
                }
              } else {
                capture = StringBuffer();
                captureName = name;
                captureDepth = 0;
              }
            }
          }
        }
        if (path.length == 1 && name == 'binary') {
          // Attribute names are matched fully qualified, mirroring the DOM
          // path's getAttribute: an `xml:id` is not an `id`.
          String? id;
          String? mediaType;
          for (final attr in event.attributes) {
            if (attr.name == 'id') id ??= attr.value;
            if (attr.name == 'content-type') mediaType ??= attr.value;
          }
          if (coverId == null) {
            // The cover id is not known yet; remember the id so that a later
            // duplicate cannot shadow this earlier binary — the DOM index
            // takes the first, and the second targeted pass will too.
            if (id != null) earlyBinaryIds.add(id);
          } else if (!coverBinaryTried &&
              id == coverId &&
              !earlyBinaryIds.contains(id)) {
            // The first binary with the cover's id decides, like the DOM
            // index does; a failed decode is a missing cover, not a cue to
            // try a later duplicate.
            coverBinaryTried = true;
            coverMediaType = mediaType;
            if (!event.isSelfClosing) binaryCapture = StringBuffer();
          }
        }
        if (!event.isSelfClosing) path.add(name);
      } else if (event is XmlTextEvent) {
        capture?.write(event.value);
        binaryCapture?.write(event.value);
      } else if (event is XmlCDATAEvent) {
        capture?.write(event.value);
        binaryCapture?.write(event.value);
      } else if (event is XmlEndElementEvent) {
        if (path.isNotEmpty) path.removeLast();
        final name = event.localName;
        if (capture != null) {
          if (captureDepth > 0) {
            captureDepth--;
          } else {
            handleCaptureEnd();
          }
        }
        // Depth checks mirror the start-side ones: the end event fires after
        // its own name is popped, so the element's parent chain is what
        // remains on the stack.
        if (name == 'author' && authorParts != null && path.length == 3) {
          final author = _authorName(
            first: authorParts['first-name'] ?? '',
            middle: authorParts['middle-name'] ?? '',
            last: authorParts['last-name'] ?? '',
            nickname: authorParts['nickname'] ?? '',
          );
          if (author.isNotEmpty) authors.add(author);
          authorParts = null;
        }
        if (name == 'coverpage' && path.length == 3) inCoverpage = false;
        if (name == 'title-info' && inTitleInfo && path.length == 2) {
          inTitleInfo = false;
        }
        if (name == 'description' && path.length == 1) descriptionDone = true;
        // Only the root-level </binary> ends the capture: a stray child
        // element inside the binary contributes its text and nothing else,
        // which is what the DOM path's innerText does.
        if (name == 'binary' && binaryCapture != null && path.length == 1) {
          coverBytes = _decodeBase64(binaryCapture.toString());
          binaryCapture = null;
        }
        // Leaving while binaryCapture is still open would drop the capture:
        // a stray child inside the binary produces an end event of its own
        // before the binary closes.
        if (descriptionDone &&
            binaryCapture == null &&
            (coverId == null ||
                coverBinaryTried ||
                earlyBinaryIds.contains(coverId))) {
          break;
        }
      }
    }
    if (!sawRoot) {
      // No root element at all: the DOM path's XmlDocument.parse throws on
      // such input, mapping to corrupt — not to unsupportedFormat, which is
      // reserved for a well-formed document with the wrong root.
      throw const FormatException('FB2: the document has no root element');
    }

    if (coverId != null && !coverBinaryTried) {
      // The named binary preceded </description>: a second targeted pass
      // streams straight to it — still no DOM over the body. The first
      // binary carrying the id decides, matching the DOM index.
      final wanted = coverId;
      var capturing = false;
      var depth = 0;
      var innerDepth = 0;
      final buffer = StringBuffer();
      for (final event in parseEvents(content)) {
        if (event is XmlStartElementEvent) {
          if (capturing) {
            // A stray child inside the binary: its text still reaches the
            // buffer, matching the DOM path's innerText.
            if (!event.isSelfClosing) innerDepth++;
            continue;
          }
          // Only a root-level <binary> counts, matching the DOM index built
          // over the root's direct children; attribute names are matched
          // fully qualified, mirroring getAttribute.
          if (event.localName == 'binary' && depth == 1) {
            String? id;
            String? mediaType;
            for (final attr in event.attributes) {
              if (attr.name == 'id') id ??= attr.value;
              if (attr.name == 'content-type') mediaType ??= attr.value;
            }
            if (id == wanted) {
              coverMediaType = mediaType;
              if (event.isSelfClosing) break;
              capturing = true;
              continue;
            }
          }
          if (!event.isSelfClosing) depth++;
        } else if (event is XmlEndElementEvent) {
          if (!capturing) {
            depth--;
          } else if (innerDepth > 0) {
            innerDepth--;
          } else {
            coverBytes = _decodeBase64(buffer.toString());
            break;
          }
        } else if (capturing &&
            (event is XmlTextEvent || event is XmlCDATAEvent)) {
          buffer.write(
            event is XmlTextEvent
                ? event.value
                : (event as XmlCDATAEvent).value,
          );
        }
      }
    }

    return BookMetadata(
      title: title,
      authors: authors,
      sourceLanguageCode: normalizeLanguageCode(lang, fallback: fallback),
      cover: coverBytes == null
          ? null
          : ImageData(
              bytes: coverBytes,
              mediaType: coverMediaType ?? 'application/octet-stream',
            ),
    );
  }

  // ----------------------------------------------------------------- shared

  /// The heading text of a `<title>`: its `<p>` lines joined by a space.
  String _titleText(XmlElement titleEl) {
    final parts = _childrenNamed(titleEl, 'p')
        .map((p) => _normalize(p.innerText))
        .where((t) => t.isNotEmpty);
    final joined = parts.join(' ');
    return joined.isNotEmpty ? joined : _normalize(titleEl.innerText);
  }

  /// Author display name, identical for the DOM and stream paths: name parts
  /// joined by spaces, the nickname as the fallback.
  String _authorName({
    required String first,
    required String middle,
    required String last,
    required String nickname,
  }) {
    final parts = [first, middle, last]
        .map(_normalize)
        .where((p) => p.isNotEmpty)
        .join(' ');
    return parts.isNotEmpty ? parts : _normalize(nickname);
  }

  Uint8List? _decodeBase64(String raw) {
    final cleaned = raw.replaceAll(_whitespaceRun, '');
    if (cleaned.isEmpty) return null;
    try {
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  XmlElement? _firstChild(XmlElement parent, String localName) {
    for (final child in parent.childElements) {
      if (child.name.local == localName) return child;
    }
    return null;
  }

  /// The nearest ancestor `<table>` of [element], by local name.
  XmlElement? _enclosingTable(XmlElement element) {
    for (XmlNode? node = element.parent; node != null; node = node.parent) {
      if (node is XmlElement && node.name.local == 'table') return node;
    }
    return null;
  }

  /// Direct children matched by local name, so a document that prefixes the
  /// FB2 namespace (`<fb:binary>`) reads the same as the usual default-xmlns
  /// form. The whole DOM path matches local names — nothing here may use
  /// `findElements`, which matches qualified names.
  Iterable<XmlElement> _childrenNamed(XmlElement parent, String localName) =>
      parent.childElements.where((e) => e.name.local == localName);

  String _childText(XmlElement parent, String localName) =>
      _firstChild(parent, localName)?.innerText ?? '';

  String? _nonEmpty(String value) => value.isEmpty ? null : value;

  String _normalize(String text) => text.replaceAll(_whitespaceRun, ' ').trim();
}

final RegExp _whitespaceRun = RegExp(r'\s+');

class _NotFictionBook implements Exception {
  const _NotFictionBook();
}
