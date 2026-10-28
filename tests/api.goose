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
    check_parse("lua", "local function answer() return 42 end\n");
    check_parse("glsl", "#version 450\nvoid main() { gl_Position = vec4(0.0); }\n");
    check_parse("hlsl", "float4 main(float4 p : POSITION) : SV_POSITION { return p; }\n");
    check_parse("wgsl", "@vertex fn main() -> @builtin(position) vec4<f32> { return vec4<f32>(0.0); }\n");
    check_parse("gdscript", "extends Node\n\nfunc answer():\n\treturn 42\n");
    check_parse("csharp", "class Answer { int Value() { return 42; } }\n");
    check_parse("php", "<?php\nfunction answer() { return 42; }\n");
    check(treesitter::language_of_path("shaders/lit.frag") == "glsl", "GLSL stage extension");
    check(treesitter::language_of_path("Assets/Player.cs") == "csharp", "C# extension");
    check(treesitter::language_of_path("scenes/player.gd") == "gdscript", "GDScript extension");

    // A pattern in each newly added language finds what it should.
    fn one(lang: const u8[:], pattern: const u8[:], source: const u8[:], want: const u8[:], label: const u8[:]) {
        var why: u8[>..] = [];
        let ok = treesitter::compile(lang, pattern, why);
        check(ok, str(label, ": pattern compiles ", why));
        var got: u8[>..] = [];
        if ok { treesitter::search(source) { node => got.append(treesitter::match_text(node)); got.push('\n'); }; }
        check(got == want, str(label, ": got [", got, "]"));
    }
    one("lua", "print($X)", "local a = 1\nprint(a) -- print(b)\nprint([[$Y]])\n", "print(a)\nprint([[$Y]])\n", "Lua call, comments and long strings");
    one("lua", "local $N = $V", "local x = 1\nlocal y = 'two'\n", "local x = 1\nlocal y = 'two'\n", "Lua locals");
    one("glsl", "texture($S, $UV)", "void main() { vec4 c = texture(tex, uv); }", "texture(tex, uv)\n", "GLSL texture call");
    one("hlsl", "mul($A, $B)", "float4 f(float4 p) { return mul(p, world); }", "mul(p, world)\n", "HLSL mul");
    one("wgsl", "textureSample($T, $S, $UV)", "fn f() -> vec4<f32> { return textureSample(t, s, uv); }", "textureSample(t, s, uv)\n", "WGSL textureSample");
    one("gdscript", "print($X)", "func _ready():\n\tprint(name) # print(x)\n", "print(name)\n", "GDScript call");
    one("csharp", "Debug.Log($X)", "class A { void F() { Debug.Log(\"hit\"); Debug.Log(x); } }", "Debug.Log(\"hit\")\nDebug.Log(x)\n", "C# Unity log");
    one("php", "echo $X;", "<?php\necho $name;\necho 'hi';\n", "echo $name;\necho 'hi';\n", "PHP echo with a PHP variable");
    one("csharp", "Load(@\"C:\\temp\\\", $X)", "class A { void F() { Load(@\"C:\\temp\\\", level); Load(@\"D:\\\", level); } }",
        "Load(@\"C:\\temp\\\", level)\n", "C# verbatim string with a trailing backslash");
    one("gdscript", "if $C:\n\tprint(\"\"\"a\nb\"\"\")", "func f():\n\tif ok:\n\t\tprint(\"\"\"a\nb\"\"\")\n",
        "if ok:\n\t\tprint(\"\"\"a\nb\"\"\")\n", "GDScript multi-line pattern keeps string newlines");
    one("php", "echo <<<'TXT'\n$X\nTXT;", "<?php\necho <<<'TXT'\n$X\nTXT;\necho <<<'TXT'\nother\nTXT;\n",
        "echo <<<'TXT'\n$X\nTXT;\n", "PHP nowdoc text is literal");

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

    // A `$` inside a string is text, not a metavariable.
    compile_ok("typescript", "log(\"$HOME\")");
    matches.clear();
    treesitter::search("log(\"$HOME\"); log(\"other\");") { node => format(matches, treesitter::match_text(node), "\n"); };
    check(matches == "log(\"$HOME\")\n", "a $ inside a string matches only that string");

    // A quote in a character literal or a comment does not start a string.
    compile_ok("rust", "foo('\"', $X)");
    captures.clear();
    treesitter::search("fn f() { foo('\"', value); }") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
    };
    check(captures == "X=value\n", "a quote in a character literal leaves later metavariables alone");
    compile_ok("typescript", "foo(/* \" */ $X)");
    count = 0;
    treesitter::search("foo(value);") { node => count++; };
    check(count == 1, "a quote in a pattern comment leaves later metavariables alone");

    // `//` is division in Python, and inside a string it is text: neither
    // starts a comment that would swallow the next metavariable.
    compile_ok("python", "foo($X // 2, $Y)");
    captures.clear();
    treesitter::search("foo(a // 2, b)\n") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
    };
    check(captures == "X=a\nY=b\n", "Python floor division is not a comment");
    compile_ok("typescript", "foo('https://example', $X)");
    captures.clear();
    treesitter::search("foo('https://example', value);") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
    };
    check(captures == "X=value\n", "a // inside a single-quoted string is not a comment");
    compile_ok("python", "foo('''it's text''', $X)");
    captures.clear();
    treesitter::search("foo('''it's text''', value)\n") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
    };
    check(captures == "X=value\n", "a Python triple-quoted string may hold its quote");
    compile_ok("kotlin", "foo(\"\"\"say \"hi\"\"\"\", $X)");
    captures.clear();
    treesitter::search("fun f() { foo(\"\"\"say \"hi\"\"\"\", value) }\n") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
    };
    check(captures == "X=value\n", "a Kotlin raw string may hold quotes");
    compile_ok("python", "foo(\"\"\"a\"\"\"\"\"\"b\"\"\", $X)");
    captures.clear();
    treesitter::search("foo(\"\"\"a\"\"\"\"\"\"b\"\"\", value)\n") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
    };
    check(captures == "X=value\n", "adjacent Python triple-quoted strings close at their first three quotes");
    compile_ok("java", "foo(\"\"\"\n text \\\"\"\" more\n\"\"\", $X)");
    captures.clear();
    treesitter::search("class C { void f() { foo(\"\"\"\n text \\\"\"\" more\n\"\"\", value); } }") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
    };
    check(captures == "X=value\n", "an escaped quote in a Java text block does not end it");
    compile_ok("rust", "foo(r#\"a \"b\" c\"#, $X)");
    captures.clear();
    treesitter::search("fn f() { foo(r#\"a \"b\" c\"#, value); }") { node =>
        treesitter::each_binding() { name, text => format(captures, name, "=", text, "\n"); };
    };
    check(captures == "X=value\n", "a Rust raw string may hold quotes");
    compile_ok("python", "f($X)  # a \" in a comment");
    count = 0;
    treesitter::search("f(value)\n") { node => count++; };
    check(count == 1, "a quote in a Python comment leaves the pattern alone");

    // Words in a pattern's comments are not required in the source.
    compile_ok("typescript", "foo(/* explanation */ $X)");
    count = 0;
    treesitter::search("foo(value);") { node => count++; };
    check(count == 1, "a pattern comment does not hide a match");

    // Captured source may hold the bytes the worker results once used as separators.
    compile_ok("rust", "$X.unwrap()");
    let odd_path = str(a[1], "/odd.rs");
    check(write_file(odd_path, "fn f() { s(\"a\x1db 1\x1f\").unwrap(); t.unwrap(); }"), "write control-byte fixture");
    file_results.clear();
    treesitter::search_files(str(odd_path, "\n")) { idx, start, end, row, col, caps =>
        format(file_results, idx, ":", col, ":", caps, "\n");
    };
    check(file_results == "0:9:X\x1fs(\"a\x1db 1\x1f\")\x1e\n0:31:X\x1ft\x1e\n", "control bytes in captures keep every match whole");

    // A path that cannot be read whole (a directory) parses to no tree.
    var handles: i64[>..] = [];
    var batch: u8[>..] = [];
    batch.append(a[1]); batch.push(0);
    batch.append(last_path); batch.push(0);
    check(treesitter::parse_files("rust", batch, handles) && handles.len == 2 && handles[0] == 0 && handles[1] != 0,
          "an unreadable path is skipped; the next file still parses");
    compile_ok("rust", "$X.unwrap()");
    treesitter::search_tree(handles[1], "fn f() { last.unwrap(); }") { node => count++; };
    print("PASS: ", checks, " standalone tree-sitter checks");
}
