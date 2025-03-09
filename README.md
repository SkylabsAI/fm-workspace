BlueRock FM Workspace Setup
===========================

To prepare an FM workspace, run the following command.
```sh
./setup-fmdeps.sh
```
This will do the following:
- Create an `fmdeps` folder and clone all the BlueRock FM deps into it.
- Create an `opam` switch named `br-${FMDEPS_VERSION}`.
- Install all the external dependencies (`ocaml`, `dune`, ...) in the switch.
- Check that SWI-Prolog is installed, and that the version is supported.
- Check that Clang is installed, and that the version is supported.


**Note:** you should be able to run the script again, as it is defensive.


After installation, you can build Coq and cpp2v via the following command:

```sh
make -C fmdeps/cpp2v ast-prepare
dune build @fmdeps/coq/install @cpp2v \
  _build/default/fmdeps/coq/dev/shim/coqtop \
  _build/default/fmdeps/coq/dev/shim/coqidetop.opt
```

You can compile all the FM dependencies by running the
following command:
```sh
dune build @@default
```

## Editor Setup

As Coq is built as part of the `dune` workspace, a bit of extra setup is
required.


### PG

You additionally need to run emacs with `emacs -l dev/fmdev.el`.

### VSCoq Legacy

Go to "Settings -> Workspace -> coqtop bin path” and use the following path:
```/path/to/fm-workspace/_build/default/fmdeps/coq/dev/shim```

### VSCoq 2

Build the `vscoqtop` Coq binary via
```
dune build fmdeps/vscoq
```

Go to "Settings -> Workspace -> Vscoq: Path:" and use the following path:
```
/path/to/fm-workspace/_build/install/default/bin/vscoqtop
```

Or alternatively
```
dune exec -- vscoqtop
```

### Coq-LSP

XXX: Currently this does not work well enough. Current instructions for attempts:

Build the `coq-lsp` Coq binary via
```
dune build fmdeps/coq-lsp
```

Go to "Settings -> Workspace -> Coq-lsp: Path" and use the following path:

```
/path/to/fm-workspace/_build/install/default/bin/coq-lsp
```

or alternatively,
```
"coq-lsp.path": "dune",
"coq-lsp.args": [
    "exec",
    "--",
    "coq-lsp"
],
```
