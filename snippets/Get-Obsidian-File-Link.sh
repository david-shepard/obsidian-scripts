#!/usr/bin/env bash
realpath() {
  if [[ -x $(command -v realpath) ]]; then
    realpath "$1"
  else
    $(brew --prefix)/bin/python3 -c 'import sys,os; print(os.path.realpath(sys.argv[1]));' "$1"
  fi
}
