# goose-treesitter

Structural search and rewrite for [Goose](https://aardappel.github.io/goose/)
programs, ast-grep style, on [tree-sitter](https://tree-sitter.github.io)
trees: TypeScript/TSX, JavaScript, Python, Rust, Java, Kotlin, C, C++ and
CUDA.

A pattern is code in the target's language with metavariables: `$X` for any
one named node, `$$$X` for any run of siblings (none included), `$_` and
names starting with `_` to match without capturing. A name used twice must
match the same text. Matching follows ast-grep's default ("smart") rules:
punctuation in the target that the pattern leaves out is skipped, and a
pattern's last sibling may be followed by more (`if ($C) { $$$B }` matches
an if with an else).

## Use

In your root file:

```goose
import treesitter from "shetautnetjer/goose-treesitter@v0.1.0";
```

```goose
var why: u8[>..] = [];
guard treesitter::compile("rust", "$X.unwrap()", why) else { abort(str(why)); }
treesitter::search(text) { node =>
    print(treesitter::match_row(node) + 1, ": ", treesitter::match_text(node));
    treesitter::each_binding() { name, captured => print("  $", name, " = ", captured); };
};
```

- `compile(lang, pattern, why)`: languages `typescript`, `tsx`, `javascript`,
  `python`, `rust`, `java`, `kotlin`, `c`, `cpp`, `cuda`;
  `language_of_path(path)` picks one by file name.
- `search(text) { node => }` and, inside it, `match_start`, `match_end`,
  `match_row`, `match_col` (0-based), `match_text`, `each_binding`, and
  `fill_template(rewrite, out)` for a rewrite with `$X` filled in.
- `search_files(paths) { idx, start, end, row, col, captures => }` searches
  many files (one path per line) on a pool of Goose worker threads; files
  without the pattern's words are never parsed.
- `parse(lang, text, nodes)` gives the raw tree as flat ints, 8 per node
  (symbol, flags, start and end byte, row, column, first child, next sibling).

See `examples/unwraps.goose`. Fetch with submodules: the grammars are git
submodules under `vendor/`, each pinned to a release tag; Goose builds them
once per C compiler and caches them.

## Licenses

This package: MIT. tree-sitter and every grammar under `vendor/` are MIT
(their own LICENSE files). The CUDA grammar's generated sources are copied in
(`vendor/tree-sitter-cuda/SOURCE` says from where) rather than a submodule,
because its repository holds a nested submodule a recursive clone cannot
follow. The pattern syntax and matching rules follow
ast-grep (MIT); no ast-grep code is used. Swan
(https://github.com/shetautnetjer/Swan) is its first user, and checks its
matches against ast-grep's.
