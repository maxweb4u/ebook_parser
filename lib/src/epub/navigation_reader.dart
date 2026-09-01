// Navigation: the EPUB 2 NCX navMap and the EPUB 3 navigation document.
// Navigation supplies titles, depth, and split points — never order.

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import 'container_reader.dart';
import 'xhtml_blocks.dart';

/// One navigation entry: a label pointing into a container entry, at a
/// nesting depth (`0` at the top).
class NavEntry {
  const NavEntry({
    required this.label,
    required this.path,
    required this.fragment,
    required this.depth,
  });

  final String label;

  /// The target container entry path, resolved and normalized.
  final String path;

  /// The fragment (anchor id) of the target, or null for a whole document.
  final String? fragment;

  final int depth;
}

/// A parsed navigation source: entries in navigation order, plus the paths
/// the navigation itself declares to be the table of contents.
class EpubNavigation {
  const EpubNavigation({required this.entries, required this.tocDeclaredPaths});

  final List<NavEntry> entries;

  /// Container entry paths declared as the table of contents by a
  /// `landmarks` link with `epub:type="toc"`.
  final List<String> tocDeclaredPaths;
}

/// Parses an NCX document; hrefs resolve against [ncxDir]. Throws
/// [XmlException] on malformed XML.
EpubNavigation readNcx(String xml, String ncxDir) {
  final document = XmlDocument.parse(xml);
  final entries = <NavEntry>[];

  void visit(XmlElement navPoint, int depth) {
    String? label;
    String? src;
    for (final child in navPoint.childElements) {
      switch (child.name.local) {
        case 'navLabel':
          for (final text in child.findElements('text', namespaceUri: '*')) {
            label = _normalize(text.innerText);
            break;
          }
        case 'content':
          src = child.getAttribute('src');
      }
    }
    if (src != null && src.isNotEmpty) {
      final target = splitFragment(src);
      entries.add(NavEntry(
        label: label ?? '',
        path: resolveEpubHref(ncxDir, target.path),
        fragment: target.fragment,
        depth: depth,
      ));
    }
    for (final child in navPoint.childElements) {
      if (child.name.local == 'navPoint') visit(child, depth + 1);
    }
  }

  for (final navMap in document.findAllElements('navMap', namespaceUri: '*')) {
    for (final navPoint in navMap.childElements) {
      if (navPoint.name.local == 'navPoint') visit(navPoint, 0);
    }
    break;
  }
  return EpubNavigation(entries: entries, tocDeclaredPaths: const []);
}

/// Parses an EPUB 3 navigation document; hrefs resolve against [navDir].
EpubNavigation readNavDoc(String xhtml, String navDir) {
  final document = html_parser.parse(expandSelfClosingRcdata(xhtml));
  final navs = document.getElementsByTagName('nav');

  dom.Element? tocNav;
  dom.Element? landmarksNav;
  for (final nav in navs) {
    // epub:type and role carry space-separated token lists, so
    // `epub:type="toc frontmatter"` still marks the toc nav.
    final epubTypes = _tokens(nav.attributes['epub:type']);
    final roles = _tokens(nav.attributes['role']);
    if (tocNav == null &&
        (epubTypes.contains('toc') || roles.contains('doc-toc'))) {
      tocNav = nav;
    }
    if (landmarksNav == null && epubTypes.contains('landmarks')) {
      landmarksNav = nav;
    }
  }
  tocNav ??= navs.isNotEmpty ? navs.first : null;

  final entries = <NavEntry>[];
  void visitList(dom.Element ol, int depth) {
    for (final li in ol.children.where((e) => e.localName == 'li')) {
      for (final child in li.children) {
        if (child.localName == 'a') {
          final href = child.attributes['href'];
          if (href != null && href.isNotEmpty) {
            final target = splitFragment(href);
            entries.add(NavEntry(
              label: _normalize(child.text),
              path: resolveEpubHref(navDir, target.path),
              fragment: target.fragment,
              depth: depth,
            ));
          }
        } else if (child.localName == 'ol') {
          // A heading <span> has no target and produces no entry; its
          // nested list is still walked at the deeper depth.
          visitList(child, depth + 1);
        }
      }
    }
  }

  if (tocNav != null) {
    for (final ol in tocNav.children.where((e) => e.localName == 'ol')) {
      visitList(ol, 0);
    }
  }

  final tocDeclared = <String>[];
  if (landmarksNav != null) {
    for (final a in landmarksNav.getElementsByTagName('a')) {
      if (_tokens(a.attributes['epub:type']).contains('toc')) {
        final href = a.attributes['href'];
        if (href != null && href.isNotEmpty) {
          tocDeclared.add(resolveEpubHref(navDir, splitFragment(href).path));
        }
      }
    }
  }

  return EpubNavigation(entries: entries, tocDeclaredPaths: tocDeclared);
}

final RegExp _whitespace = RegExp(r'\s+');

String _normalize(String text) => text.replaceAll(_whitespace, ' ').trim();

Set<String> _tokens(String? value) => (value ?? '')
    .split(_whitespace)
    .where((t) => t.isNotEmpty)
    .toSet();
