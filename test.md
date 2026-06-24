# A file to go through and confirm all faces are loading correctly

## Headings

# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6

## Inline code

This is `text` with inline `code`

## Code blocks

```txt
# Don't render markdown in code blocks that aren't markdown

------

> block

- [ ] checkbox

- list item

```

```
# Markdown will still render in blocks that don't have a defined language
```

```lua
print("Hello, world\n")
```

```sh
echo "hello world"
```

```c
int main(){
  printf("Hello, world\n")
}
```

## Check Boxes

- [x] checked
- [ ] unchecked

## List Bullets

* Bullet 1
- Bullet 2

## Dashed line

------
******
______
> ------

## Block Quotes

> This is a block quote
> that spans
> multiple lines

> Block quote with code
> ```sh
>  testing
> ```

> With Bullet lists
> - TEST
>   - TEST 2

> Nested block quotes
> > Hello
> > ```sh
> > eho hello
> > ```

## Links

- ![image](test.png)
- [markdown file](test.md)
- [python file](test.py)
- [website](https://test.com)
- <user@test.com>

## Text Transforms
~~strike~~
*italic*
_italic_
**bold**
__bold__
~~strike~~ *italic* _italic_ **bold** __bold__
\~~strike~~ \*italic* \_italic_ \**bold** \__bold__
.__bold__.
.**bold**.
._italic_.
.*italic*.
should_not_match
should*not*match
should__not__match
should**not**match
