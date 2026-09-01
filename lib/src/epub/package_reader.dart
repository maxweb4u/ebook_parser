// The OPF package document: metadata, manifest, spine, and guide.

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'container_reader.dart';

/// One `<item>` of the OPF manifest.
class ManifestItem {
  const ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String id;

  /// The href as written in the OPF, unresolved.
  final String href;

  final String mediaType;

  /// Space-separated `properties` values, such as `nav` or `cover-image`.
  final Set<String> properties;
}

/// One `<reference>` of the EPUB 2 `<guide>`.
class GuideReference {
  const GuideReference({required this.type, required this.href});

  final String type;
  final String href;
}

/// The parsed OPF package document.
class OpfPackage {
  const OpfPackage({
    required this.opfDir,
    required this.title,
    required this.authors,
    required this.language,
    required this.manifestById,
    required this.spineIdrefs,
    required this.spineTocId,
    required this.guide,
    required this.metaCoverId,
  });

  /// The directory of the OPF inside the container, `''` at the root. All
  /// manifest hrefs resolve against it.
  final String opfDir;

  final String? title;
  final List<String> authors;
  final String? language;
  final Map<String, ManifestItem> manifestById;
  final List<String> spineIdrefs;

  /// The `toc` attribute of `<spine>`, naming the NCX manifest item.
  final String? spineTocId;

  final List<GuideReference> guide;

  /// The idref of `<meta name="cover" content="…"/>`, the EPUB 2 cover
  /// convention.
  final String? metaCoverId;

  /// Resolves a manifest [href] to a container entry path.
  String resolve(String href) => resolveEpubHref(opfDir, href);
}

/// Parses the OPF at [opfPath]. Throws [XmlException] on malformed XML; the
/// caller maps that to a corrupt-file failure.
OpfPackage readOpf(String xml, String opfPath) {
  final document = XmlDocument.parse(xml);
  final root = document.rootElement;
  final opfDir = p.url.dirname(opfPath);

  String? title;
  final authors = <String>[];
  String? language;
  String? metaCoverId;
  for (final metadata in root.findElements('metadata', namespaceUri: '*')) {
    for (final child in metadata.childElements) {
      final text = _normalize(child.innerText);
      switch (child.name.local) {
        case 'title':
          if (title == null && text.isNotEmpty) title = text;
        case 'creator':
          if (text.isNotEmpty) authors.add(text);
        case 'language':
          if (language == null && text.isNotEmpty) language = text;
        case 'meta':
          if (child.getAttribute('name') == 'cover') {
            final content = child.getAttribute('content');
            if (content != null && content.isNotEmpty) metaCoverId = content;
          }
      }
    }
    break;
  }

  final manifestById = <String, ManifestItem>{};
  for (final manifest in root.findElements('manifest', namespaceUri: '*')) {
    for (final item in manifest.findElements('item', namespaceUri: '*')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) continue;
      manifestById[id] = ManifestItem(
        id: id,
        href: href,
        mediaType: item.getAttribute('media-type') ?? '',
        properties: (item.getAttribute('properties') ?? '')
            .split(_whitespace)
            .where((v) => v.isNotEmpty)
            .toSet(),
      );
    }
    break;
  }

  final spineIdrefs = <String>[];
  String? spineTocId;
  for (final spine in root.findElements('spine', namespaceUri: '*')) {
    spineTocId = spine.getAttribute('toc');
    for (final itemref in spine.findElements('itemref', namespaceUri: '*')) {
      // linear="no" is deliberately ignored: the item is a chapter in spine
      // order like any other.
      final idref = itemref.getAttribute('idref');
      if (idref != null) spineIdrefs.add(idref);
    }
    break;
  }

  final guide = <GuideReference>[];
  for (final guideEl in root.findElements('guide', namespaceUri: '*')) {
    for (final ref in guideEl.findElements('reference', namespaceUri: '*')) {
      final type = ref.getAttribute('type');
      final href = ref.getAttribute('href');
      if (type != null && href != null) {
        guide.add(GuideReference(type: type, href: href));
      }
    }
    break;
  }

  return OpfPackage(
    opfDir: opfDir == '.' ? '' : opfDir,
    title: title,
    authors: authors,
    language: language,
    manifestById: manifestById,
    spineIdrefs: spineIdrefs,
    spineTocId: spineTocId,
    guide: guide,
    metaCoverId: metaCoverId,
  );
}

final RegExp _whitespace = RegExp(r'\s+');

String _normalize(String text) => text.replaceAll(_whitespace, ' ').trim();
