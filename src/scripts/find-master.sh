#! /bin/bash

oc exec pod/$1 -c redis -- redis-cli info replication | grep master_host
