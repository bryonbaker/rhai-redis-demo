#!/usr/bin/env bash

#################################
# include the -=magic=-
# you can pass command line args
#
# example:
# to disable simulated typing
# . ../demo-magic.sh -d
#
# pass -h to see all options
#################################
. $HOME/bin/demo-magic.sh

. ./scripts/env-setup-syd.sh

########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
# TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W ${COLOR_RESET}"
# Display git branch in prompt
DEMO_PROMPT=$PS1


# text color
# DEMO_CMD_COLOR=$BLACK

# hide the evidence
clear

# enters interactive mode and allows newly typed command to be executed
cmd

# Expose the gateway
pe "oc apply -f yaml/redis-reader-sydney-dep.yaml"

pe "watch oc get svc,pods"

pe "oc logs deployment/redis-read-tester -f"

pe "oc apply -f yaml/redis-syd-ocp-dep.yaml"

pe "watch oc get svc,pods"

pe "skupper expose deployment skupper-redis-syd-server-2  --port 6379,26379"

pe "oc get svc,pod"

pe "oc logs deployment/redis-read-tester -f"
