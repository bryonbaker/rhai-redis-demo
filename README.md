# Redis Global Cache with Application Interconnect

This repository demonstrates how Application Interconnect can be used to create a cross-Kubernetes-cluster replicated cache with a master cache on premises using traditional infrastructure.

This is a common pattern used to protect core infrastructure from Internet-scale workloads.

The Redis cache is replicated from on-premises to Sydney, London and and New York. To run this cluster you need at least two OpenShift clusters.

[Demo script](./doc/demo-script.md)
