// Tests this checkout as a package, independently of Swan and remote tags.
import std;
import os;
import treesitter from "..";

var checks = 0;

fn check(ok: bool, label: const u8[:]) {
    if !ok { abort(str("FAIL: ", label)); }
    checks++;
    print("ok: ", label);
}

fn compile_ok(lang: const u8[:], pattern: const u8[:]) {
    var why: u8[>..] = [];
    if !treesitter::compile(lang, pattern, why) {
        abort(str("compile ", lang, " pattern ", pattern, ": ", why));
    }
}

fn check_parse(lang: const u8[:], source: const u8[:]) {
    var nodes: i32[>..] = [];
    check(treesitter::parse(lang, source, nodes), str(lang, " parser is linked"));
    check(nodes.len >= 8 && nodes.len % 8 == 0 && nodes[2] == 0 && nodes[3] == source.len,
          str(lang, " root spans the source"));
    var errors = 0;
    for i in 0..nodes.len / 8 {
        if (nodes[i * 8 + 1] & 4) != 0 { errors++; }
    }
    check(errors == 0, str(lang, " valid snippet has no error/missing node"));
}

fn main() {
    let a = args();
    check(a.len == 2, "runner supplies a scratch directory");
    check(treesitter::language_of_path("src/main.ts") == "typescript", "TypeScript extension");
    check(treesitter::language_of_path("src/main.cuh") == "cuda", "CUDA header extension");
    check(treesitter::language_of_path("build.gradle.kts") == "kotlin", "Kotlin script extension");
    check(treesitter::language_of_path("README.md") == "", "unsupported extension");

    check_parse("typescript", "const answer: number = 42;");
    check_parse("tsx", "const view = <span>hello</span>;");
    check_parse("javascript", "const answer = 42;");
    check_parse("python", "def answer():\n    return 42\n");
    check_parse("rust", "fn answer() -> i32 { 42 }");
    check_parse("java", "class Answer { int value() { return 42; } }");
    check_parse("kotlin", "fun answer(): Int = 42\n");
    check_parse("c", "int answer(void) { return 42; }");
    check_parse("cpp", "class Answer { public: int value() { return 42; } };");
    check_parse("cuda", "__global__ void kernel(int *x) { x[0] = 1; } void f(int *x) { kernel<<<1, 32>>>(x); }");

    compile_ok("rust", "$X.unwrap()");
    let source = "fn f() {\n    foo().unwrap();\n    x.y.unwrap();\n}";
    var matches: u8[>..] = [];
    var captures: u8[>..] = [];
    var rewrites: u8[>..] = [];
    var positions: u8[>..] = [];
    treesitter::search(source) { node =>
        format(matches, treesitter::match_text(node), "\n");
        check(source[treesitter::match_start(node)..treesitter::match_end(node)] == treesitter::match_text(node),
              "match byte range slices the original source");
        format(positions, treesitter::match_row(node), ":", treesitter::match_col(node), "\n");
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
        treesitter::fill_template("$X.expect(\"present\")", rewrites);
        rewrites.push('\n');
    };
    check(matches == "foo().unwrap()\nx.y.unwrap()\n", "Rust expressions match in source order");
    check(captures == "X=foo()\nX=x.y\n", "single metavariable captures exact text");
    check(positions == "1:4\n2:4\n", "rows and columns are zero based");
    check(rewrites == "foo().expect(\"present\")\nx.y.expect(\"present\")\n", "rewrite fills captures");

    var count = 0;
    treesitter::search("fn f() { value.expect(\"present\"); }") { node => count++; };
    check(count == 0, "nonmatching source yields no callback");

    compile_ok("typescript", "$A === $A");
    matches.clear();
    treesitter::search("left === right; same === same;") { node => format(matches, treesitter::match_text(node)); };
    check(matches == "same === same", "repeated metavariable requires equal captured text");

    compile_ok("typescript", "console.log($$$A)");
    captures.clear();
    rewrites.clear();
    treesitter::search("console.log(); console.log(first, second);") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
        treesitter::fill_template("trace($$$A)", rewrites);
        rewrites.push('\n');
    };
    check(captures == "A=\nA=first, second\n", "variadic capture accepts empty and multiple arguments");
    check(rewrites == "trace()\ntrace(first, second)\n", "variadic rewrite preserves argument text");

    compile_ok("rust", "$_.unwrap()");
    count = 0;
    var bindings = 0;
    treesitter::search("fn f() { value.unwrap(); }") { node =>
        count++;
        treesitter::each_binding() { name, text => bindings++; };
    };
    check(count == 1 && bindings == 0, "anonymous metavariable matches without capturing");

    var why: u8[>..] = [];
    check(!treesitter::compile("unknown", "$X", why) && why.len > 0, "unsupported language reports failure");
    why.clear();
    check(!treesitter::compile("rust", "fn (((", why) && why.len > 0, "malformed pattern reports failure");
    compile_ok("python", "$X.append($Y)");
    matches.clear();
    treesitter::search("items.append(value)\nother.extend(value)\n") { node => format(matches, treesitter::match_text(node)); };
    check(matches == "items.append(value)", "successful compile recovers after a rejected pattern");

    // Exercise the worker pool using files owned by the test runner. The
    // missing middle file must not renumber later matches or lose ordering.
    compile_ok("rust", "$X.unwrap()");
    let first_path = str(a[1], "/first file.rs");
    let last_path = str(a[1], "/last.rs");
    check(write_file(first_path, "fn f() { first.unwrap(); }"), "write first scratch fixture");
    check(write_file(last_path, "fn f() { last.unwrap(); }"), "write last scratch fixture");
    let paths = str(first_path, "\n", a[1], "/missing.rs\n", last_path, "\n");
    var file_results: u8[>..] = [];
    treesitter::search_files(paths) { idx, start, end, row, col, caps =>
        format(file_results, idx, ":", row, ":", col, ":", caps, "\n");
    };
    check(file_results == "0:0:9:X\x1ffirst\x1e\n2:0:9:X\x1flast\x1e\n", "worker results preserve file order, indexes and captures");
    print("PASS: ", checks, " standalone tree-sitter checks");
}
