{ pkgs, ... }:

let
    parsers = with pkgs.tree-sitter-grammars; [
        tree-sitter-python
    ];

    localParsers = pkgs.runCommand "local-tree-sitter-parsers" {} ''
        mkdir -p $out
        for p in ${pkgs.lib.concatStringSep " " (map (x: x + "/lib/tree-sitter") parsers)}; do
            cp $p/*.so $out/
        done
    '';
in
localParsers
