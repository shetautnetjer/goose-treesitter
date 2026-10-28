/* Never used for its content: each grammar wrapper under grammars/ includes
   its own tree_sitter/parser.h first, and grammars differ in its version.
   This file only lets a shared scanner header (common/scanner.h) find the
   name; landing here without the guard set is a wiring mistake. */
#ifndef TREE_SITTER_PARSER_H_
#error "include the grammar's own tree_sitter/parser.h first (see grammars/)"
#endif
