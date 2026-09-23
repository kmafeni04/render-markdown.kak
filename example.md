# Example *markdown* file

A quick overview of what [render-markdown.kak](./render-markdown.kak) replaces.

## Headings

Headings can contain inline formatting; the markers are replaced inline:

# Heading with **bold** and *italic*
## With `code` and a [link](https://example.com)
### And an ![image](assets/1.png)

## Emphasis

`inline code`, **bold**, *italic*, _also italic_, __also bold__, ~~strikethrough~~,
and a [web link](https://kakoune.org).

## Lists

- [x] checked task
- [ ] unchecked task
* plain bullet
* nested bullet

## Horizontal rules

------
******

## Blockquotes

> Quoted line that spans
> multiple lines

## Links

- ![example image](./assets/1.png)
- [markdown file](example.md)
- [reference style][ref]
- <user@example.com>

[ref]: https://example.com

## Tables

Tables render their pipes and separator rows; cell content stays as typed.

| Column A | Column B |
|----------|----------|
| a        | bb       |
| c        |          |

## Code blocks

``` txt
# This heading is NOT rendered (fenced with a non-markdown language)
```

```markdown
# This one IS rendered (markdown-tagged fence)
```