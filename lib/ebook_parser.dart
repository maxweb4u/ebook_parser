/// Parse EPUB and FB2 ebooks into one shared document model — with lazy
/// sentence and word segmentation, a cheap metadata-only path, and
/// transparent `.fb2.zip` handling.
///
/// The entry point is [bookParserFor]: pass the file path and the bytes you
/// hold, get back an [IBookParser] or `null`. Everything a parse returns is
/// the shared model rooted at [BookDocument]; expected failures arrive as
/// [ParseErr], never as exceptions.
///
/// JSON serialization is a separate opt-in import:
/// `package:ebook_parser/serialization.dart`.
library;

export 'src/book_archive.dart'
    show
        ArchiveContent,
        EpubArchive,
        NoBookInside,
        NotAnArchive,
        SeveralBooksInside,
        WrappedBook,
        inspectBookArchive,
        isZipArchive;
export 'src/book_document.dart'
    show
        Block,
        BookDocument,
        BookDocumentSample,
        Chapter,
        HeadingBlock,
        ImageBlock,
        ParagraphBlock,
        Sentence,
        Word;
export 'src/book_metadata.dart' show BookMetadata, ImageData;
export 'src/book_parser.dart' show IBookParser;
export 'src/book_parser_factory.dart'
    show bookParserFor, importableBookExtensions, supportedBookExtensions;
export 'src/language_codes.dart' show normalizeLanguageCode;
export 'src/parse_result.dart'
    show ParseErr, ParseFailure, ParseFailureKind, ParseOk, ParseResult;
export 'src/segmentation/rule_based_segmenter.dart' show RuleBasedSegmenter;
export 'src/segmentation/text_segmenter.dart' show TextSegmenter;
