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

. ./scripts/env-setup-local.sh

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
pe "skupper gateway expose skupper-redis-on-prem-server-0 127.0.0.1 6379 26379 --type podman"

pe "skupper gateway status"

pe "oc get svc,pods"

pe "oc apply -f yaml/redis-reader-on-prem-dep.yaml"

pe "watch oc get svc,pods"

pe "oc logs deployment/redis-read-tester -f"

pe "oc apply -f yaml/redis-on-prem-ocp-dep.yaml"

pe "watch oc get svc,pods"

cmd

pe "skupper expose deployment skupper-redis-server-1 --port 6379,26379"

pe "oc get svc,pod"

cmd

pe "skupper network status"

pe "skupper gateway status"

pe "oc get cm"

pe "oc edit cm/redis-reader-app-config"

pe "oc delete pod -l application=redis-read-tester"

pe "watch oc get pods"

pe "oc logs deployment/redis-read-tester -f"
