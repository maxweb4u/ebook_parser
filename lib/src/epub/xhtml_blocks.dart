// Chapter XHTML to blocks, tracking anchor positions so a spine item holding
// several navigation entries can be split at them.
//
// Parsed with `html`, not with `xml`: real books do not guarantee well-formed
// XML. Text is preserved, structure is not — every textual construct becomes
// a paragraph, a heading, or an image, and CSS is never read.

import '../book_document.dart';
import '../book_metadata.dart';
import '../segmentation/text_segmenter.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// The blocks of one chapter document, plus where each anchor id landed:
/// `anchors[id]` is the index of the block the anchor's own or nearest
/// enclosing block became, i.e. the index a split at that anchor happens
/// before.
class XhtmlBlocks {
  const XhtmlBlocks({required this.blocks, required this.anchors});

  final List<Block> blocks;
  final Map<String, int> anchors;
}

/// Elements whose content never reaches the model.
const Set<String> _skippedTags = {
  'script', 'style', 'template', 'noscript', 'iframe', 'object', 'embed',
  'audio', 'video', 'source', 'track', 'math', 'head', 'title', 'link',
  'meta', 'base', 'rt', 'rp', 'select', 'option', 'textarea', 'button',
};

/// Elements treated as flow containers or handled structurally; everything
/// not listed here or in [_skippedTags] contributes inline text.
const Set<String> _blockTags = {
  'p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'div', 'section', 'article',
  'aside', 'blockquote', 'ul', 'ol', 'li', 'dl', 'dt', 'dd', 'table',
  'figure', 'figcaption', 'header', 'footer', 'main', 'nav', 'hr', 'pre',
  'address', 'details', 'summary', 'form', 'fieldset',
};

/// Extracts blocks from chapter XHTML in document order.
///
/// [resolveImage] turns an `src`/`href` as written in the document into
/// image data, or null when the image cannot be resolved — an unresolvable
/// image is skipped rather than failing the parse.
XhtmlBlocks blocksFromXhtml(
  String xhtml, {
  required TextSegmenter segmenter,
  ImageData? Function(String href)? resolveImage,
}) {
  final document = html_parser.parse(expandSelfClosingRcdata(xhtml));
  final builder = _Builder(segmenter, resolveImage);
  final body = document.body;
  if (body != null) builder.visitContainer(body);
  builder.flushRun();
  return XhtmlBlocks(blocks: builder.blocks, anchors: builder.anchors);
}

class _Builder {
  _Builder(this.segmenter, this.resolveImage);

  final TextSegmenter segmenter;
  final ImageData? Function(String href)? resolveImage;
  final blocks = <Block>[];
  final anchors = <String, int>{};

  StringBuffer? _run;

  void recordAnchor(dom.Element element) {
    final id = element.id;
    if (id.isNotEmpty) anchors[id] ??= blocks.length;
    if (element.localName == 'a') {
      final name = element.attributes['name'];
      if (name != null && name.isNotEmpty) anchors[name] ??= blocks.length;
    }
  }

  void visitContainer(dom.Element element) {
    for (final node in element.nodes) {
      if (node is dom.Text) {
        _appendText(node.data);
      } else if (node is dom.Element) {
        final tag = node.localName ?? '';
        if (_skippedTags.contains(tag)) {
          recordAnchor(node);
          continue;
        }
        if (_blockTags.contains(tag) ||
            tag == 'img' ||
            tag == 'image' ||
            tag == 'svg') {
          flushRun();
          _visitBlock(node, tag);
        } else {
          _appendInline(node);
        }
      }
    }
    flushRun();
  }

  void _visitBlock(dom.Element element, String tag) {
    recordAnchor(element);
    switch (tag) {
      case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
        final text = _inlineText(element);
        if (text.isNotEmpty) {
          blocks.add(HeadingBlock(
            text: text,
            level: int.tryParse(tag.substring(1)) ?? 2,
          ));
        }
      // Lists take the default container walk: each li is a block tag of its
      // own — one paragraph per item, its id recorded as an anchor — and a
      // stray non-li child keeps its text instead of being dropped.
      case 'table':
        _visitTable(element);
      case 'img' || 'image':
        _emitImage(element);
      case 'svg':
        // Inline SVG is dropped, except an image it merely wraps.
        for (final image in element.getElementsByTagName('image')) {
          _emitImage(image);
        }
      case 'hr':
        break;
      default:
        visitContainer(element);
    }
  }

  void _visitTable(dom.Element table) {
    // Walked in document order so every id inside the table — on the
    // caption, a row group, a column, a row, or anything in a cell — is
    // recorded at the index of the block its region became. The caption is
    // a paragraph of its own (its text is in no row); each row is one
    // paragraph, cells joined by a single space. Rows of a nested table are
    // skipped: their text already reaches the outer cell through
    // [_inlineText], and taking them again would duplicate it.
    for (final child in table.children) {
      switch (child.localName) {
        case 'caption':
          recordAnchor(child);
          final text = _inlineText(child);
          if (text.isNotEmpty) {
            blocks.add(ParagraphBlock(text: text, segmenter: segmenter));
          }
        case 'thead' || 'tbody' || 'tfoot':
          recordAnchor(child);
          for (final row in child.children.where(
            (e) => e.localName == 'tr',
          )) {
            _visitRow(row);
          }
        case 'tr':
          _visitRow(child);
        case 'colgroup':
          recordAnchor(child);
          for (final col in child.children) {
            recordAnchor(col);
          }
        default:
          recordAnchor(child);
      }
    }
  }

  void _visitRow(dom.Element row) {
    for (final el in row.querySelectorAll('[id]')) {
      recordAnchor(el);
    }
    recordAnchor(row);
    final cells = row.children
        .where((c) => c.localName == 'td' || c.localName == 'th')
        .map(_inlineText)
        .where((t) => t.isNotEmpty)
        .join(' ');
    if (cells.isNotEmpty) {
      blocks.add(ParagraphBlock(text: cells, segmenter: segmenter));
    }
  }

  void _emitImage(dom.Element element) {
    final resolve = resolveImage;
    if (resolve == null) return;
    // A namespaced attribute such as `xlink:href` is keyed by an
    // AttributeName object rather than a plain string, so the lookup has to
    // scan.
    String? src;
    element.attributes.forEach((key, value) {
      final name = key.toString();
      if (name == 'src') src ??= value;
    });
    if (src == null) {
      element.attributes.forEach((key, value) {
        final name = key.toString();
        if (name == 'href' || name.endsWith(':href')) src ??= value;
      });
    }
    final href = src;
    if (href == null || href.isEmpty) return;
    final image = resolve(href);
    if (image != null) blocks.add(ImageBlock(image: image));
  }

  void _appendInline(dom.Element element) {
    recordAnchor(element);
    final tag = element.localName ?? '';
    switch (tag) {
      case 'br':
        (_run ??= StringBuffer()).write('\n');
      case 'img' || 'image':
        // An image inside flowing text still becomes its own block.
        flushRun();
        _emitImage(element);
      case 'ruby':
        // Base text only; the reading is dropped.
        for (final node in element.nodes) {
          if (node is dom.Text) {
            _appendText(node.data);
          } else if (node is dom.Element &&
              node.localName != 'rt' &&
              node.localName != 'rp') {
            _appendInline(node);
          }
        }
      default:
        for (final node in element.nodes) {
          if (node is dom.Text) {
            _appendText(node.data);
          } else if (node is dom.Element) {
            final childTag = node.localName ?? '';
            if (_skippedTags.contains(childTag)) {
              recordAnchor(node);
            } else if (_blockTags.contains(childTag)) {
              // Block content nested in an inline element: real books do
              // this; flush and handle it structurally.
              flushRun();
              _visitBlock(node, childTag);
            } else {
              _appendInline(node);
            }
          }
        }
    }
  }

  void _appendText(String data) {
    if (data.isEmpty) return;
    final collapsed = data.replaceAll(_whitespace, ' ');
    if (collapsed == ' ' && (_run == null || _run!.isEmpty)) return;
    (_run ??= StringBuffer()).write(collapsed);
  }

  void flushRun() {
    final run = _run;
    _run = null;
    if (run == null) return;
    final lines = run
        .toString()
        .split('\n')
        .map((line) => line.replaceAll(_whitespace, ' ').trim())
        .where((line) => line.isNotEmpty);
    final text = lines.join('\n');
    if (text.isNotEmpty) {
      blocks.add(ParagraphBlock(text: text, segmenter: segmenter));
    }
  }

  /// The flattened text of [element]: inside a heading or a table cell
  /// everything becomes text, and a `<br>` becomes a space rather than a
  /// line break. A block-level child gets a space on each side, so compact
  /// markup with no inter-tag whitespace cannot fuse words across what a
  /// reader sees as separate lines; the collapse below removes any doubling.
  String _inlineText(dom.Element element) {
    final buffer = StringBuffer();
    void walk(dom.Element el) {
      for (final node in el.nodes) {
        if (node is dom.Text) {
          buffer.write(node.data);
        } else if (node is dom.Element) {
          recordAnchor(node);
          final tag = node.localName ?? '';
          if (_skippedTags.contains(tag)) continue;
          if (tag == 'br') {
            buffer.write(' ');
            continue;
          }
          final isBlock =
              _blockTags.contains(tag) || _tableStructureTags.contains(tag);
          if (isBlock) buffer.write(' ');
          walk(node);
          if (isBlock) buffer.write(' ');
        }
      }
    }

    walk(element);
    return buffer.toString().replaceAll(_whitespace, ' ').trim();
  }
}

/// Table-structure tags that are block boundaries for [_Builder._inlineText]
/// but are not in [_blockTags] (there they are handled inside the table
/// walk, not as flow containers).
const Set<String> _tableStructureTags = {
  'tr', 'td', 'th', 'caption', 'thead', 'tbody', 'tfoot',
};

final RegExp _whitespace = RegExp(r'\s+');

// The attribute part admits `>` inside quoted values — well-formed XHTML —
// so `<title data-x="a>b"/>` still expands instead of swallowing the body.
final RegExp _selfClosingRcdata = RegExp(
  '''<(title|script|style|textarea)(\\s(?:[^<>"']|"[^"]*"|'[^']*')*)?/>''',
);

/// XHTML allows `<title/>`, but under HTML parsing rules title, script,
/// style and textarea are raw-text elements: a self-closing one is read as
/// an opening tag that swallows the rest of the document. Real conversion
/// pipelines emit `<title/>` in every chapter head, so the form is expanded
/// before the HTML parser sees it.
String expandSelfClosingRcdata(String xhtml) =>
    xhtml.replaceAllMapped(
      _selfClosingRcdata,
      (m) => '<${m[1]}${m[2] ?? ''}></${m[1]}>',
    );
