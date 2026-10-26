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
import treesitter from "shetautnetjer/goose-treesitter@v0.1.1";
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

See `examples/unwraps.goose`. A local checkout can be used directly with
`import treesitter from "../goose-treesitter";` in a program's root file.
Use `git clone --recurse-submodules` when cloning the package yourself:
the runtime and most grammars are pinned submodules under `vendor/`.
The CUDA grammar's sources are copied in, as described below.

## Package and build boundary

The pattern matcher, capture/template handling and search worker pool are
Goose code in `treesitter.goose`. The parser engine, generated grammars and
FFI shim are C. This is an independently importable Goose package with a C
parser backend, not a rewrite of tree-sitter in Goose. It needs no Swan,
SQLite, SCIP indexer, language server, Node or Rust toolchain to search text.

Plan for **all ten bundled grammars** (TypeScript and TSX count separately),
their scanners and the tree-sitter runtime to compile on a cold build.
With the installed Goose v2026.3 compiler, even an otherwise unused
`treesitter` import triggers that native build; using only
`language_of_path` does not avoid it. Choosing `"rust"` or `"python"` in
`compile` selects the parser at run time; it does not reduce the set of C
sources in `treesitter.build`. The package does not currently offer
per-grammar build selection.

Goose keeps native build artifacts in its cache (`GOOSE_HOME`, otherwise
`~/.goose`) and reuses them while the cache inputs and toolchain match.
Deleting that cache or changing its inputs can require rebuilding native
code. The Goose matcher still participates in each consumer's Goose build,
and an executable still links the required native library. A warm build
therefore avoids repeated grammar compilation; it is not a zero-cost build
or a prebuilt package download.

`compile` replaces the current pattern, and `search` replaces the current
match/capture state. Read match accessors and fill templates inside the
callback; copy any text that must outlive it. Do not nest `compile` or
`search` inside a search callback. `search_files` manages its own worker
threads and returns matches in input-file order. A failed `compile` must be
handled before searching. These APIs expose syntax, not type resolution or
compiler diagnostics.

## Standalone tests

With Goose v2026.3 and a C compiler already installed:

```bash
GOOSE=/path/to/goose scripts/test.sh
```

The test program imports this checkout via `from ".."` and builds offline;
it does not fetch a released package. The runner uses `.test-build/` for its executable and
temporary fixture files, and defaults `GOOSE_HOME` to `.test-cache/`.
Override `GOOSE_HOME` or `TEST_BUILD_DIR` to keep artifacts elsewhere. The
first run compiles the native parser bundle; later runs can reuse it.

The suite checks every grammar on a small valid snippet, exact captures,
zero-based positions and byte ranges, rewrite templates, repeated and
anonymous metavariables, empty variadic captures, nonmatches, rejected
patterns and recovery, and worker output ordering with a missing file.
It uses no external indexers or servers. These are package contract checks;
they do not establish full ast-grep parity or validate the target languages
with their compilers. Swan's separate integration suite covers its use of
the package in a code map.

## Licenses

This package: MIT. tree-sitter and every grammar under `vendor/` are MIT
(their own LICENSE files). The CUDA grammar's generated sources are copied in
(`vendor/tree-sitter-cuda/SOURCE` says from where) rather than a submodule,
because its repository holds a nested submodule a recursive clone cannot
follow. The pattern syntax and matching rules follow
ast-grep (MIT); no ast-grep code is used. Swan
(https://github.com/shetautnetjer/Swan) is its first user, and checks its
matches against ast-grep's.
