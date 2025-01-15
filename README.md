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


After installation, you can compile all the FM dependencies by running the
following command:
```sh
make -C fmdeps/cpp2v ast-prepare
dune build
```

## Editor Setup

As Coq is build as part of the `dune` workspace, a bit of extra setup is
required. First, to ensure that `coqtop` (used by PG) and `coqidetop.opt`
(used by vscoq) are available, you need to run the following.
```
dune build _build/default/fmdeps/coq/dev/shim/coqtop
dune build _build/default/fmdeps/coq/dev/shim/coqidetop.opt 
```

### PG

You additionally need to run emacs with `emacs -l dev/fmdev.el`.

### VSCoq Legacy

Go to "Settings -> Workspace -> coqtop bin path” and use the following path:
```/path/to/fm-workspace/_build/default/fmdeps/coq/dev/shim```
