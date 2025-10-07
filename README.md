BlueRock FM Workspace Setup
===========================

To prepare an FM workspace, run the following command, and follow instructions in its output.
```sh
./setup-fmdeps.sh
```
This will do the following:
- Create an `fmdeps` folder and clone all the BlueRock FM deps into it.
- Create an `opam` switch named `br-${FMDEPS_VERSION}` -- here and below,
  `${FMDEPS_VERSION}` will be the current release number (currently
  `2025-02-26`).
- Install all the external dependencies (`ocaml`, `dune`, ...) in the switch.
- Check that SWI-Prolog is installed, and that the version is supported.
- Check that Clang is installed, and that the version is supported.


**Note:** you should be able to run the script again, as it is defensive.

## Opam environment setup

You will **have to** configure your shell to use the tools from the new `opam` switch!
This configuration is local to a running shell process, so **it must be repeated for each shell**.
`setup-fmdeps.sh` will list the correct instructions, typically something like `eval $(opam env)`
or `eval $(opam env --switch="br-${FMDEPS_VERSION}" --set-switch)`; read the script output for the actual command line!

You can configure `opam` to make this automatic, by adding a hook into your
shell; you will need to run `opam switch br-${FMDEPS_VERSION}` to make our new
switch the default, and follow instructions at `opam init --reinit`.

## Building fmdeps

After installation and configuring your environment, you can build Coq and cpp2v via the following command:

```sh
dune build @fmdeps/install @cpp2v \
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
