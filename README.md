# render-markdown.kak

Improve viewing Markdown in Kakoune

![1](./assets/1.png)
![2](./assets/2.png)
![3](./assets/3.png)

## How to install

- NB: You need to have a nerdfont installed and set for your terminal

Copy [render-markdown.kak](./render-markdown.kak) into kakoune's `autoload` directory

Add this to your kakrc file
```kak
hook global WinSetOption filetype=markdown %{
  render-markdown-enable
}
```

## Quick test

From the repo root, open a sample with the plugin loaded and rendering
enabled:

kak -n -e 'source render-markdown.kak; render-markdown-enable' example.md

`example.md` covers all rendered constructs; `test/fixtures/mixed.md` is a
larger sample. The render happens automatically a moment after opening (the
update runs on NormalIdle), so no other setup is needed — just a terminal
with a nerd-font glyph set.

Only the lines on screen are rendered, so in a long file the rest fills in
as you scroll; code fences are the exception (their markers are found
across the whole buffer, since a block can outlive the screen).

The full automated suite is `dash test/run.sh` (see Testing below).

## Rendering Support

Currently the plugin supports rendering
- Headings
- Codeblocks
- Checkboxes
- List markers (bullets, and ordered numbers kept in place)
- Thematic breaks (`---`, `***`, `___`, and spaced forms such as `- - -`)
- Blockquotes
- Links
- Strikethroughs
- Italics
- Bold text
- Inline code
- Tables (box-drawing grid: │ bars, ├ ┼ ┤ ─ separator line)

Every matcher but the code fence scan looks only at the lines on screen (see
Quick test), which keeps the update cheap on large files.

## Customisation

All rendered faces are set with `render_markdown_*` options
You can make changes to them according to your taste

## Table commands

- `render-markdown-table-select` — select the table enclosing the cursor
- `render-markdown-table-format` — align that table: pads each column to its
  widest cell and rewrites separator rows as dash runs (at least three dashes).
  Works with uneven rows; the indentation of the first line is kept.

Tables are rendered as a connecting grid: each `|` becomes a `│` bar and the
separator row becomes a `├─┼─┤` line. All replacement glyphs are single-width,
so column alignment is never disturbed. Header/content cell text is left
untouched (no inline markdown inside cells).

## Testing

Local, POSIX-only test suite (verified under `dash`):

```sh
dash test/run.sh [unit|integration|smoke|bless|lint|all]
```

- `unit` — pure-shell tests for the classifier library (no Kakoune needed)
- `integration` — runs each fixture through a headless Kakoune session
  (`kak -ui json`, no terminal needed) and diffs the emitted range-specs
  against committed goldens. A fixture may carry a `<fixture>.cursor` file
  naming the line to render from, which covers scrolled viewports
- `smoke` — checks the replace-ranges highlighter really renders glyphs
- `bless` — regenerates goldens from current output (use when behaviour
  intentionally changes)
- `lint` — shellcheck on all shell scripts

Requires `kak` for the integration and smoke tests. The shell scripts are
POSIX-only and verified under `dash` (any POSIX sh will also run them).
When a golden changes, review the diff and re-bless only if the change is
intended.

## Known Issues
- Inline formatting inside headings (bold, italic, code, links) renders at one
  level only — nested emphasis spans inside headings are not parsed
- Inline markdown inside table cells is not rendered (cells show the raw text)
- `***text***` (bold and italics together) is not rendered
- `---` is also the YAML front-matter delimiter and the setext heading
  underline, so front matter and setext underlines render as thematic breaks
- Setext headings (`Title` underlined with `===` or `---`) are not rendered
- Fences of four or more backticks are not supported: the inner fence is
  treated as a fence of its own

## Reference
- https://github.com/MeanderingProgrammer/render-markdown.nvim
