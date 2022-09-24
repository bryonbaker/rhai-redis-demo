#! /bin/bash

export KUBECONFIG=$HOME/.kube/config-nyc-cloud
export PS1="NEW-YORK: \[$(tput setaf 2)\]\u@\h\[$(tput setaf 7)\]:\$(parse_git_branch)\[$(tput setaf 6)\]\W\\$ \[$(tput setaf 7)\]\[$(tput sgr0)\]"
