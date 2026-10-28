// Compiled under a name of its own: the package's objects are named after their sources.
// Its shared scanner header (common/scanner.h) includes "tree_sitter/..." headers
// it does not sit beside, so this grammar's own copies are included first.
#include "../vendor/tree-sitter-php/php/src/tree_sitter/parser.h"
#include "../vendor/tree-sitter-php/php/src/tree_sitter/alloc.h"
#include "../vendor/tree-sitter-php/php/src/tree_sitter/array.h"
#include "../vendor/tree-sitter-php/php/src/scanner.c"
