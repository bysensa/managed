import 'package:managed/annotations.dart';

@ManagedType(scope: ScopeType.cached)
class MarkdownStyle {
  MarkdownStyle({required this.headingPrefix});

  final String headingPrefix;
}

@ManagedType(scope: ScopeType.unique)
class MarkdownHeading {
  MarkdownHeading(this.title);

  final String title;
}

@ManagedType(scope: ScopeType.unique)
class MarkdownTemplate {
  MarkdownTemplate(this.style, this.heading, {required this.includeAuthor});

  final MarkdownStyle style;
  final MarkdownHeading heading;
  final bool includeAuthor;

  String render(String body, String author) => [
        '${style.headingPrefix} ${heading.title}',
        '',
        body,
        if (includeAuthor) ...['', '— $author'],
      ].join('\n');
}
