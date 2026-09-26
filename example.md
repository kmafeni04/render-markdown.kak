---
title: render-markdown.kak example
tags: [markdown, kakoune]
---

# Example *markdown* file

A quick overview of what [render-markdown.kak](./render-markdown.kak) replaces.

## Headings

Headings can contain inline formatting; the markers are replaced inline:

# Heading with **bold** and *italic*
## With `code` and a [link](https://example.com)
### And an ![image](assets/1.png)
#### Closing hashes are stripped ####

Setext heading level 1
==============

Setext heading level 2
--------------

## Emphasis

`inline code`, **bold**, *italic*, _also italic_, __also bold__, ~~strikethrough~~,
and a [web link](https://kakoune.org).
``code with a ` backtick``

<!-- hidden HTML comment: concealed by the plugin -->

## Lists

* plain bullet
* second bullet

1. first ordered item
2. second ordered item

## Checkboxes

- [x] checked task
- [ ] unchecked task
- [~] inapplicable task (GitLab)
- [/] task in progress (Obsidian)
- [-] cancelled task (Obsidian)

## Horizontal rules

------
******

## Blockquotes

> Quoted line that spans
> multiple lines

> Nested quote
> > inner quote

## Callouts

> [!NOTE]
> The type marker is replaced by an icon.

> [!TIP] With a custom title
> GitLab's optional title is kept after the icon.

> [!IMPORTANT]
> The type set is shared by GitHub, GitLab and Forgejo/Gitea.

> [!WARNING]
> Types are matched case-insensitively.

> [!CAUTION]
> Only the marker line is styled; the body stays plain.

> [!UNKNOWN]
> An unrecognised type stays literal.

## Links

- ![example image](./assets/1.png)
- [markdown file](example.md)
- [reference style][ref]
- <user@example.com>
- <https://kakoune.org>

[ref]: https://example.com

## Tables

Tables redraw their pipes and separator row as a box grid, and inline markup
inside cells is rendered in place.

| Column A | Column B           |
|----------|--------------------|
| a        | bb                 |
| **bold** | [link](example.md) |
| c        |                    |

## Code blocks

``` txt
# This heading is NOT rendered (fenced with a non-markdown language)
```

```lua
print("the info string becomes a language label")
```

```markdown
# This one IS rendered (markdown-tagged fence)
```
