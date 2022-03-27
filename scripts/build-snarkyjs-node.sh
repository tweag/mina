SNARKY_JS_PATH=$1
[ -z "$SNARKY_JS_PATH" ] && echo "Usage: ./build-snarkyjs-node.sh [/path/to/snarkyjs]" && exit 1
# TODO: once snarkyjs is a git submodule of mina, change these scripts to not require a path to snarkyjs (it could stay optional though)

dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js
cp _build/default/src/lib/crypto/kimchi_bindings/js/node_js/plonk_wasm* "$SNARKY_JS_PATH"/src/node_bindings/
cp _build/default/src/lib/snarky_js_bindings/snarky_js_node*.js "$SNARKY_JS_PATH"/src/node_bindings/

# better error messages
# TODO: find a less hacky way to make adjustments to jsoo compiler output
# `s` is the jsoo representation of the error message string, and `s.c` is the actual JS string
sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw joo_global_object.Error(s.c)/' "$SNARKY_JS_PATH"/src/node_bindings/snarky_js_node.bc.js
sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw joo_global_object.Error(s.c)/' "$SNARKY_JS_PATH"/src/node_bindings/snarky_js_node.bc.js
sed -i 's/return \[0,Exn,t\]/return joo_global_object.Error(t.c)/' "$SNARKY_JS_PATH"/src/node_bindings/snarky_js_node.bc.js

pushd "$SNARKY_JS_PATH"/src/node_bindings
  wasm-opt --detect-features --enable-mutable-globals -O4 plonk_wasm_bg.wasm -o plonk_wasm_bg.wasm.opt
  mv plonk_wasm_bg.wasm.opt plonk_wasm_bg.wasm
popd