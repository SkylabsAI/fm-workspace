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
domain_separator="/"

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
fi


# Git base URL.
PRIVATE_REPO="gitlab.com${domain_separator}bedrocksystems"
PUBLIC_REPO="github.com${domain_separator}bluerock-io"

# Directory where to clone the FM dependencies.
FMDEPS_DIR="${PWD}/fmdeps"

# Minimum required opam version.
MIN_OPAM_VERSION="2.2.1"

# Version of the FM dependencies.
FMDEPS_VERSION="2024-11-01"

# Configured opam repositories. Convention: "<NAME>!<URL>".
OPAM_REPOS=(
  "coq-released!https://coq.inria.fr/opam/released"
  "iris-dev!git+https://gitlab.mpi-sws.org/iris/opam.git"
)

# Selected opam repositories at switch creation.
OPAM_SELECTED_REPOS="iris-dev,default,coq-released"

# Repositories to clone. Convention: "<REPO_PATH>[><PATH>]:<MAIN_BRANCH>".
PUBLIC_REPOS=(
  "BRiCk>cpp2v-core:master"
  "coq:br-master"
  "stdpp:br-master"
  "iris:br-master"
  "coq-ext-lib:br-master"
  "coq-equations:br-main"
  "elpi:br-master"
  "coq-elpi:br-master"
  "vscoq:br-main"
  "coq-lsp:br-main"
)

# Repositories that are internal
PRIVATE_REPOS=(
  "cpp2v:master"
)

# Creating the directory where repos will be cloned.
if [[ ! -d "${FMDEPS_DIR}" ]]; then
  echo "Creating directory [${FMDEPS_DIR}]."
  mkdir "${FMDEPS_DIR}"
else
  echo "Directory [${FMDEPS_DIR}] already exists."
fi

# Cloning the configured repositories.
for repo in ${PUBLIC_REPOS[@]}; do
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
    repo_url="${protocol}${PUBLIC_REPO}/${repo_path}"
    repo_dir="${FMDEPS_DIR}/${repo_name}"

    if [[ ! -d "${repo_dir}" ]]; then
        echo "Cloning ${repo_url}#${repo_branch} to [${repo_dir}]."
        echo "git clone --branch ${repo_branch} ${repo_url} \"${repo_dir}\""

        git clone --branch ${repo_branch} ${repo_url} "${repo_dir}"
    else
        echo "Directory [${repo_dir}] already exists, skipping repo ${repo_path}."
        (cd "${repo_dir}"; git fetch; git checkout ${repo_branch}; git pull)
    fi
done

if [[ "$public_only" = "0" ]]; then
    # Cloning the private repositories
    for repo in ${PRIVATE_REPOS[@]}; do
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
        repo_url="${protocol}${PRIVATE_REPO}/${repo_path}"
        repo_dir="${FMDEPS_DIR}/${repo_name}"

        if [[ ! -d "${repo_dir}" ]]; then
            echo "Cloning ${repo_url}#${repo_branch} to [${repo_dir}]."
            git clone --branch ${repo_branch} ${repo_url} "${repo_dir}"
        else
            echo "Directory [${repo_dir}] already exists, skipping repo ${repo_path}."
            (cd "${repo_dir}"; git fetch; git checkout ${repo_branch}; git pull)
        fi
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
      "$(echo -e '${OPAM_VERSION}\n2.2.1' | sort -V | head -n1)" ]]; then
  echo "Your version of opam (${OPAM_VERSION}) is too old."
  echo "Version ${MIN_OPAM_VERSION} at least is required."
  echo "See https://opam.ocaml.org/doc/Install.html for upgrade instructions."
fi

SWITCH_CREATED=false
OPAM_SWITCH_NAME="br-${FMDEPS_VERSION}"
if opam switch list --short | grep "^${OPAM_SWITCH_NAME}$" > /dev/null; then
  echo "The opam switch ${OPAM_SWITCH_NAME} already exists."
else
  # Adding the opam repositories (this is idempotent).
  for opam_repo in ${OPAM_REPOS[@]}; do
    opam_repo_name=$(echo ${opam_repo} | cut -d'!' -f1)
    opam_repo_url=$(echo ${opam_repo} | cut -d'!' -f2)
    opam repo add --dont-select "${opam_repo_name}" "${opam_repo_url}"
  done

  # Creating the new switch.
  echo "Creating opam switch ${OPAM_SWITCH_NAME}."
  opam switch create --empty --repositories="${OPAM_SELECTED_REPOS}" \
    "${OPAM_SWITCH_NAME}"
  eval $(opam env --switch="${OPAM_SWITCH_NAME}")
  opam update
  opam install ${FMDEPS_DIR}/fm-ci/fm-deps/br-fm-deps.opam
  SWITCH_CREATED=true
fi

# Check SWI-Prolog version.

if ! pkg-config --modversion swipl > /dev/null; then
  echo "It seems that SWI-Prolog is not installed on your system."
  echo "Command [pkg-config --modversion swipl] filed."
  exit 1
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

CUR_VER=$(pkg-config --modversion swipl)
PL_CUR_VER=$(version_to_int ${CUR_VER})

MIN_VER="9.0.0"
MAX_VER="9.3.8"

PL_MIN_VER=$(version_to_int ${MIN_VER})
PL_MAX_VER=$(version_to_int ${MAX_VER})

if [[ $PL_CUR_VER -lt $PL_MIN_VER || $PL_CUR_VER -gt $PL_MAX_VER ]]; then
  echo -e "\033[0;31mError: SWI-prolog version ${CUR_VER} is not supported."
  echo -e "You need a version between ${MIN_VER} and ${MAX_VER}.\033[0m"
  exit 1
else
  echo "Using SWI-Prolog version ${CUR_VER}."
fi

# Check LLVM version.
CLANG_MIN_MAJOR_VER="16"
CLANG_MAX_MAJOR_VER="18"
CLANG_RECOMMENDED_VER="18"

if ! type clang 2> /dev/null > /dev/null; then
  echo "Could not find clang."
  echo "See https://apt.llvm.org/. We recommend version ${CLANG_RECOMMENDED_VER}."
  exit 1
fi

CLANG_VER="$(clang --version | \
               grep "clang version" | \
               sed 's/^.*clang version \([0-9.]\+\).*$/\1/' | \
               cut -d' ' -f3)"
CLANG_MAJOR_VER="$(echo ${CLANG_VER} | cut -d'.' -f1)"

if seq ${CLANG_MIN_MAJOR_VER} ${CLANG_MAX_MAJOR_VER} | grep -q "${CLANG_MAJOR_VER}"; then
  echo "Using clang version ${CLANG_VER}."
else
  echo -e "\033[0;31mError: clang version ${CLANG_VER} is not supported."
  echo -e "The major version is expected to be between ${MIN_MAJOR_VER} and \
    ${MAX_MAJOR_VER}.\033[0m"
  exit 1
fi

# Remind to configure opam.

if [[ ${SWITCH_CREATED} = "true" ]]; then
  echo
  echo -e "\033[0;36mNew opam switch created, you may need to run:\033[0m"
  echo -e \
    "  \033[0;1meval \$(opam env --switch=\"${OPAM_SWITCH_NAME}\")\033[0m"
fi
