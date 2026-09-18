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

## Rendering Support

Currently the plugin supports rendering
- Headings
- Codeblocks
- Checkboxes
- List bullets
- Horizontal rules
- Blockquotes
- Links
- Strikethroughs
- Italics
- Bold text
- Inline code

## Customisation

All rendered faces are set with `render_markdown_*` options
You can make changes to them according to your taste

## Testing

Local, POSIX-only test suite (verified under `dash`):

```sh
dash test/run.sh [unit|integration|smoke|bless|lint|all]
```

- `unit` — pure-shell tests for the classifier library (no Kakoune needed)
- `integration` — runs each fixture through a headless Kakoune session
  (via tmux) and diffs the emitted range-specs against committed goldens
- `smoke` — checks the replace-ranges highlighter really renders glyphs
- `bless` — regenerates goldens from current output (use when behaviour
  intentionally changes)
- `lint` — shellcheck on all shell scripts

Requires `dash`, `kak` and `tmux`. When a golden changes, review the diff
and re-bless only if the change is intended.

## Known Issues
- Inline formatting inside headings (bold, italic, code, links) renders at one
  level only — nested emphasis spans inside headings are not parsed
- No rendering for tables (Not really planned)

## Reference
- https://github.com/MeanderingProgrammer/render-markdown.nvim
