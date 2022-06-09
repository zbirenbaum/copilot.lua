#!/usr/bin/env bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
wget -O $SCRIPT_DIR/copilot/dist/agent.js https://raw.githubusercontent.com/github/copilot.vim/release/copilot/dist/agent.js
