#!/bin/bash
#
# Copyright (c) 2024 BlueRock Security, Inc.
#
# This software is distributed under the terms of the BlueRock Open-Source
# License. See the LICENSE-BlueRock file at the repository root for details.
#

set -euf -o pipefail

public_only=0
do_help=0
protocol="https://"

while getopts "phs" opt
do
  case $opt in
  (p) public_only=1 ;;
  (h) do_help=1;;
  (s) protocol="ssh://git@";;
  (*) printf "Illegal option '-%s'\n" "$opt" && exit 1 ;;
  esac
done

if [ "$do_help" = "1" ]; then
    echo "Setup the BlueRock FM Workspace"
    echo ""
    echo "Options"
    echo " -p     only install public dependencies"
    echo " -h     show this message"
    echo " -s     pull dependencies using ssh"
    exit
fi


# Git base URL.
PRIVATE_REPO="github.com/bluerock-io"
PUBLIC_REPO="github.com/bluerock-io"

# Directory where to clone the FM dependencies.
FMDEPS_DIR="${PWD}/fmdeps"

# Minimum required opam version.
MIN_OPAM_VERSION="2.2.1"

# Version of the FM dependencies.
FMDEPS_VERSION="2025-02-26"

# Configured opam repositories. Convention: "<NAME>!<URL>".
OPAM_REPOS=(
  "iris-dev!git+https://gitlab.mpi-sws.org/iris/opam.git"
)

# Selected opam repositories at switch creation.
OPAM_SELECTED_REPOS="iris-dev,default"

# Repositories to clone. Convention: "<REPO_PATH>[><PATH>]:<MAIN_BRANCH>".
PUBLIC_REPOS=(
  "BRiCk>cpp2v-core:master"
  "coq:br-master"
  "stdpp:br-master"
  "rocq-stdlib>stdlib:br-master"
  "iris:br-master"
  "coq-ext-lib:br-master"
  "coq-equations:br-main"
  "elpi:br-master"
  "coq-elpi:br-master"
  "vscoq:br-main"
  "fm-ci:main"
  "coq-lsp:br-main"
)

# Repositories that are internal
PRIVATE_REPOS=(
  "auto>cpp2v:master"
  "fm-docs:main"
)

# Creating the directory where repos will be cloned.
if [[ ! -d "${FMDEPS_DIR}" ]]; then
  echo "Creating directory [${FMDEPS_DIR}]."
  mkdir "${FMDEPS_DIR}"
else
  echo "Directory [${FMDEPS_DIR}] already exists."
fi

pull() {
    local repo="$1"
    local REPO_BASE="$2"
    if [[ $repo == *">"* ]]; then
          repo_path=$(echo ${repo} | cut -d':' -f1)
          repo_target=$(echo ${repo_path} | cut -d'>' -f2)
          repo_path=$(echo ${repo_path} | cut -d'>' -f1)
    else
          repo_path=$(echo ${repo} | cut -d':' -f1)
          repo_target=$repo_path
    fi


    repo_name=$(basename ${repo_path})
    repo_branch=$(echo ${repo} | cut -d':' -f2)
    repo_url="${protocol}${REPO_BASE}/${repo_path}"
    repo_dir="${FMDEPS_DIR}/${repo_target}"

    if [[ ! -d "${repo_dir}" ]]; then
        echo "Cloning ${repo_url}#${repo_branch} to [${repo_dir}]."
        echo "git clone --branch ${repo_branch} ${repo_url} \"${repo_dir}\""

        git clone --branch ${repo_branch} ${repo_url} "${repo_dir}"
    else
        echo "Directory [${repo_dir}] already exists, updating repo ${repo_path} instead of recloning."
        cd "${repo_dir}"
        git remote set-url origin ${repo_url}
        git fetch
        git checkout ${repo_branch}
        git pull --rebase
        cd -
    fi
}

# Cloning the configured repositories.
for repo in ${PUBLIC_REPOS[@]}; do
    pull "$repo" "${PUBLIC_REPO}"
done

if [[ "$public_only" = "0" ]]; then
    # Cloning the private repositories
    for repo in ${PRIVATE_REPOS[@]}; do
        pull "$repo" "${PRIVATE_REPO}"
    done
fi

# Checking that opam is installed.
if ! type opam 2> /dev/null > /dev/null; then
  echo "Could not find opam, see https://opam.ocaml.org/doc/Install.html."
  exit 1
fi

# Check opam version.
OPAM_VERSION=$(opam --version)
if [[ "${MIN_OPAM_VERSION}" != \
      "$(echo -e "${OPAM_VERSION}\n${MIN_OPAM_VERSION}" | sort -V | head -n1)" ]]; then
  echo "Your version of opam (${OPAM_VERSION}) is too old."
  echo "Version ${MIN_OPAM_VERSION} at least is required."
  echo "See https://opam.ocaml.org/doc/Install.html for upgrade instructions."
fi

OPAM_SWITCH_NAME="br-${FMDEPS_VERSION}"
opam_file=${FMDEPS_DIR}/fm-ci/fm-deps/br-fm-deps.opam
if opam switch list --short | grep "^${OPAM_SWITCH_NAME}$" > /dev/null; then
  echo -e "\033[0;36mThe opam switch ${OPAM_SWITCH_NAME} already exists, we assume dependencies have been installed. In case of trouble, try rerunning:\033[0m"
  echo -e "\topam install ${opam_file}"
else
  # Adding the opam repositories (this is idempotent).
  for opam_repo in ${OPAM_REPOS[@]}; do
    opam_repo_name=$(echo ${opam_repo} | cut -d'!' -f1)
    opam_repo_url=$(echo ${opam_repo} | cut -d'!' -f2)
    opam repo add --dont-select "${opam_repo_name}" "${opam_repo_url}"
  done

  # Creating the new switch.
  echo "Creating opam switch ${OPAM_SWITCH_NAME}."
  # This makes the new switch the global default
  opam switch create --empty --repositories="${OPAM_SELECTED_REPOS}" \
    "${OPAM_SWITCH_NAME}"
  # Clear any user-chosen OPAMSWITCH, so that we use the new switch instead in this script
  unset OPAMSWITCH
  # Avoid --set-switch here, it would hide misconfigurations from the $(opam switch show) test
  eval $(opam env)
  opam update
  # We skip this step, and assume fm-ci's opam file is up-to-date.
  # dune build ${opam_file}
  if ! opam install ${opam_file}; then
    echo -e "\033[0;36mInstalling opam dependencies failed! Your opam switch is now in an inconsistent state!\033[0m"
    echo -e "Please troubleshoot `opam install ${opam_file}` until it succeeds, or ask for assistance."
  fi
fi

errors=0

# Check SWI-Prolog version.

if ! pkg-config --modversion swipl > /dev/null; then
  echo "It seems that SWI-Prolog is not installed on your system."
  echo "Command [pkg-config --modversion swipl] failed."
  errors=1
fi

function version_to_int() {
  local vmaj
  local vmin
  local vpch
  local v=$1
  vmaj=${v%.*.*}
  v=${v#*.}
  vmin=${v%.*}
  vpch=${v#*.}
  let "res = ${vmaj} * 10000 + ${vmin} * 100 + ${vpch}"
  echo "${res}"
}

# Check LLVM version.
CLANG_MIN_MAJOR_VER="18"
CLANG_MAX_MAJOR_VER="20"
CLANG_RECOMMENDED_VER="19"

if type clang 2> /dev/null > /dev/null; then
  CLANG_VER="$(clang --version | \
                grep "clang version" | \
                sed -r 's/^.*clang version ([0-9.]+).*$/\1/' | \
                cut -d' ' -f3)"
  CLANG_MAJOR_VER="$(echo ${CLANG_VER} | cut -d'.' -f1)"

  if seq ${CLANG_MIN_MAJOR_VER} ${CLANG_MAX_MAJOR_VER} | grep -q "${CLANG_MAJOR_VER}"; then
    echo "Using clang version ${CLANG_VER}."
  else
    echo -e "\033[0;31mError: clang version ${CLANG_VER} is not supported."
    echo -e "The major version is expected to be between ${CLANG_MIN_MAJOR_VER} and \
      ${CLANG_MAX_MAJOR_VER}.\033[0m"
    errors=1
  fi
else
  echo "Could not find clang."
  echo "See https://apt.llvm.org/. We recommend version ${CLANG_RECOMMENDED_VER}."
  errors=1
fi

# Remind to configure opam.

echo "<<< Caveats >>>"
if [[ ! `opam switch show` = ${OPAM_SWITCH_NAME} ]]; then
  echo
  echo -e "\033[0;36mCurrent switch is not ${OPAM_SWITCH_NAME}, you need to run the following in each shell:\033[0m"
  echo -e \
    "  \033[0;1meval \$(opam env --switch=\"${OPAM_SWITCH_NAME}\" --set-switch)\033[0m"
else
  echo -e "\033[0;36mYou need to run the following in each shell:\033[0m"
  echo -e \
    "  \033[0;1meval \$(opam env)\033[0m"
fi

exit $errors
