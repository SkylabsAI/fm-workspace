BlueRock FM Workspace Setup
===========================

To prepare an FM workspace, run the following command.
```sh
./setup-fmdeps.sh
```
This will do the following:
- Create an `opam` switch named `bedrock-${FMDEPS_VERSION}`.
- Install all the external dependencies (`ocaml`, `coq`, ...) in the switch.
- Check that SWI-Prolog is installed, and that the version is supported.
- Check that Clang is installed, and that the version is supported.


**Note:** you should be able to run the script again, as it is defensive.


After installation, you can compile all the FM dependencies by running the
following command:
```sh
dune build
```
