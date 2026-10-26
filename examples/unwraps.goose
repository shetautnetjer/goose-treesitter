// goose build examples/unwraps.goose -o unwraps && ./unwraps
import std;
import treesitter from "..";

fn main() {
    var why: u8[>..] = [];
    guard treesitter::compile("rust", "$X.unwrap()", why) else { abort(str(why)); }
    var out: u8[>..] = [];
    treesitter::search("fn f() { let a = foo().unwrap(); let b = x.y.unwrap(); }") { node =>
        format(out, treesitter::match_text(node));
        treesitter::each_binding() { name, text => format(out, " ", name, "=", text); };
        out.push('\n');
    };
    print(out);
    assert(out == "foo().unwrap() X=foo()\nx.y.unwrap() X=x.y\n");
}
