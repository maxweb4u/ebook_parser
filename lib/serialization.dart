/// Opt-in JSON serialization for the ebook_parser document model.
///
/// A separate library, so a caller that only parses never sees it. The
/// encoded shape is a compatibility promise versioned by
/// [kBookDocumentSchemaVersion]; image bytes stay out of the json and are
/// handed back to the caller — see [encodeBookDocument].
library;

export 'src/codec/book_document_codec.dart'
    show
        decodeBlock,
        decodeBookDocument,
        encodeBlock,
        encodeBookDocument,
        kBookDocumentSchemaVersion;
