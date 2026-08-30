---
title: "ebook_parser — Dart-пакет разбора EPUB и FB2"
doc_kind: specification
doc_function: canonical
purpose: "Спецификация выноса парсеров книг из TeaderBook в самостоятельный пакет для pub.dev."
status: draft
audience: humans_and_agents
---

# ebook_parser

Вынос `lib/src/data/book_parsing/` из TeaderBook в отдельный пакет.
Кода здесь нет — это план.

## 1. Имя

**`ebook_parser`** — свободно на pub.dev (проверено).

Почему это, а не альтернативы:

| Вариант | Свободно | Почему не он |
|---|---|---|
| `fb2` | да | Занижает: пакет разбирает и EPUB. И приглашает вопрос «почему fb2-пакет парсит epub» |
| `epub_parser` | **нет** | Занято |
| `epub` | **нет** | Занято |
| `epub_fb2` | да | Максимально ищется, но имя ломается при добавлении третьего формата |
| `biblio`, `libris` | да | Красиво и непонятно. На pub.dev ищут по «epub», «fb2», «ebook» — эти слова должны быть в имени |
| **`ebook_parser`** | да | Говорит, что делает; ищется; переживёт добавление MOBI или TXT |

Формат имени pub.dev — `lowercase_with_underscores`, поэтому папка репозитория
называется так же, в отличие от `react-native-matrix` рядом.

## 2. Чем пакет ценен

FB2-парсеров на Dart практически нет — это реальный дефицит, а не ещё одна
обёртка. EPUB-пакеты есть, но каждый возвращает свою модель.

Ценность именно в связке: **два формата сходятся в одну модель документа**,
поэтому весь код над парсингом пишется один раз и не ветвится по формату.
Плюс то, что уже сделано в TeaderBook и обычно отсутствует в аналогах:

- определение формата по magic-байтам, когда расширение врёт или отсутствует;
- `.fb2.zip` — штатный способ распространения FB2 — распаковывается прозрачно;
- дешёвый путь только для метаданных: заголовок, автор, язык, обложка без обхода глав;
- ленивая сегментация на предложения и слова — по абзацу, при первом обращении,
  а не по всей книге вперёд.

Последний пункт стоит вынести в README отдельно: он и есть причина, по которой
книга на несколько мегабайт открывается быстро.

## 3. Публичный API

Экспортируется ровно это, остальное — `src/`.

```dart
// Определение формата и выбор парсера
IBookParser? bookParserFor(String filePath, Uint8List bytes);
const supportedBookExtensions;    // ['epub', 'fb2']
const importableBookExtensions;   // + 'zip'

// Порт
abstract interface class IBookParser {
  Future<ParseResult<BookDocument>> parse(Uint8List bytes,
      {required String fallbackLanguageCode});
  Future<ParseResult<BookMetadata>> parseMetadata(Uint8List bytes,
      {required String fallbackLanguageCode});
}

// Модель
class BookDocument { title, author, chapters, sourceLanguageCode, coverImage }
class Chapter { index, title, blocks }
sealed class Block {}
class ParagraphBlock extends Block { text; List<Sentence> get sentences; }
class HeadingBlock extends Block { text, level }
class ImageBlock extends Block { bytes }
class Sentence { text, start, end, words }
class Word { text, start, end }

// Утилита
String sampleTextOf(BookDocument document, {int maxChars = 4000});
```

`sealed class Block` сохраняем: он заставляет потребителя обработать все
варианты и ломает сборку при добавлении нового — это фича, а не строгость.

## 4. Что поменять при выносе

| Что | Действие |
|---|---|
| Импорты `package:readtolearn/...` | Заменить на относительные внутри пакета |
| `Result<T>` из `core/types/result.dart` | Своя `ParseResult<T>` внутри пакета. Тянуть в зависимости чужой Result нельзя, а бросать исключения на ожидаемых ошибках — регресс относительно текущего поведения |
| `FailureKind.bookParse` | Свой `ParseFailure` с причинами: `corrupt`, `unsupportedFormat`, `encoding`, `emptyDocument` |
| Ссылки на `memory_bank/adr/...` в комментариях | Убрать пути, оставить сам довод. Комментарий, ссылающийся в никуда, хуже отсутствующего |
| Ссылки на `FT-001`, `FT-017`, `FT-019` | Убрать — вне TeaderBook это шум |
| `sentence_segmenter.dart` | Переносится в пакет: без него `ParagraphBlock.sentences` не работает |
| Зависимости | Оставить минимум: `archive` (zip), `xml`, `path`. Никакого Flutter — пакет должен ставиться в чистый Dart-проект |

Последнее — принципиально. Если в зависимостях окажется `flutter`, пакет нельзя
будет использовать в серверном или CLI-коде, а это половина потенциальных
пользователей.

## 5. Структура

```
ebook_parser/
  lib/
    ebook_parser.dart          # единственный публичный экспорт
    src/
      book_document.dart
      book_metadata.dart
      parse_result.dart
      book_parser.dart          # интерфейс IBookParser
      book_parser_factory.dart
      epub_parser.dart
      fb2_parser.dart
      book_archive.dart
      sentence_segmenter.dart
  test/
    fixtures/                   # маленькие книги обоих форматов + битые файлы
  example/
    main.dart                   # открыть файл, напечатать оглавление
  README.md
  CHANGELOG.md
  LICENSE                       # MIT
  pubspec.yaml
```

`example/` для pub.dev не формальность — он влияет на pub points.

## 6. pubspec.yaml

```yaml
name: ebook_parser
description: >-
  Parses EPUB and FB2 e-books into one format-agnostic document model.
  Detects format by magic bytes, unwraps .fb2.zip, and segments sentences lazily.
version: 0.1.0
repository: https://github.com/maxweb4u/ebook_parser
issue_tracker: https://github.com/maxweb4u/ebook_parser/issues
topics: [epub, fb2, ebook, parser, reader]

environment:
  sdk: ^3.7.0

dependencies:
  archive: ^4.0.0
  xml: ^6.5.0
  path: ^1.9.0

dev_dependencies:
  test: ^1.25.0
  lints: ^5.0.0
```

`description` — 60–180 символов, иначе pub.dev снимает баллы. `topics` — то, по
чему пакет находят поиском.

## 7. Как подключают другие

После публикации:

```yaml
dependencies:
  ebook_parser: ^0.1.0
```

До публикации, из git:

```yaml
dependencies:
  ebook_parser:
    git:
      url: https://github.com/maxweb4u/ebook_parser.git
      ref: main
```

Использование:

```dart
final bytes = await File('book.fb2').readAsBytes();
final parser = bookParserFor('book.fb2', bytes);
if (parser == null) return;

final result = await parser.parse(bytes, fallbackLanguageCode: 'ru');
switch (result) {
  case Ok(:final value):
    print('${value.title} — ${value.chapters.length} глав');
  case Err(:final failure):
    print('не разобрали: ${failure.kind}');
}
```

## 8. Тесты

Минимум, ниже которого публиковать не стоит:

- по одной валидной книге каждого формата — заголовок, автор, число глав, первый абзац;
- `.fb2.zip` даёт тот же результат, что распакованный `.fb2`;
- определение формата по magic-байтам при неверном расширении;
- битый файл возвращает `Err`, а не бросает исключение;
- книга без объявленного языка получает `fallbackLanguageCode`;
- `sentences` считаются лениво: до обращения к геттеру сегментация не запускалась.

Последний тест защищает главное продающее свойство пакета — без него оно
сломается при первом же рефакторинге.

## 9. Порядок

1. Скопировать код в структуру выше, вычистить импорты и ссылки на TeaderBook.
2. Написать `ParseResult` и `ParseFailure`.
3. Тесты с фикстурами.
4. README: чем отличается от существующих EPUB-пакетов, пример, таблица поддержки форматов.
5. `dart pub publish --dry-run`, починить замечания.
6. Публикация.
7. **TeaderBook переключить на пакет.** Пока приложение живёт на своей копии,
   пакет становится мёртвым форком, а расхождение обнаружится в худший момент.

Шаг 7 — не необязательный: он и есть доказательство, что вынос сделан правильно.

## 10. Открытый вопрос

`sentence_segmenter.dart` сегментирует по правилам, зависящим от языка. Насколько
он language-agnostic сейчас — надо посмотреть до публикации: пакет, который
хорошо режет русский и плохо английский, должен сказать об этом в README, а не
делать вид, что работает везде одинаково.
