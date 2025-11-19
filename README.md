# EVPN OpenShift Virtualization Demo

A demonstration of EVPN (Ethernet VPN) with VXLAN for OpenShift Virtualization, showcasing how to stretch Layer 2 overlay networks across multiple infrastructure components using BGP and modern data center networking techniques.

## Motivation

Traditional OpenShift deployments are often limited to Layer 3 networking within their cluster boundaries. However, virtualization workloads frequently require Layer 2 connectivity that spans beyond a single cluster or integrates with existing infrastructure.

This project demonstrates how to:

- **Extend Layer 2 networks** across OpenShift clusters and traditional infrastructure using EVPN-VXLAN
- **Enable hybrid cloud networking** where OpenShift VMs can communicate seamlessly with external hosts as if on the same LAN
- **Leverage standard protocols** (BGP, EVPN) instead of proprietary SDN solutions
- **Integrate OpenShift Virtualization** with modern data center fabric architectures
- **Support VM mobility** and east-west traffic patterns across different infrastructure zones

This approach is particularly valuable for organizations migrating from traditional virtualization platforms to OpenShift while maintaining network compatibility with existing infrastructure.

## Goals

This demo aims to:

1. **Demonstrate EVPN-VXLAN Implementation**: Show a working EVPN control plane with BGP and VXLAN data plane encapsulation
2. **Showcase OpenShift Integration**: Integrate OpenShift Virtualization with EVPN fabrics using OpenPERouter
3. **Illustrate Best Practices**: Implement modern data center networking patterns including VRF segmentation
4. **Provide Hands-On Learning**: Offer a complete, reproducible environment for learning EVPN concepts
5. **Enable Testing**: Create a sandbox for testing Layer 2 stretched network scenarios with OpenShift VMs

## Network Topology

```
                        ┌─────────────────────────────────────┐
                        │      Spine Router                   │
                        │      AS: 64612                      │
                        │      192.168.1.3 (to provider leaf) │
                        │      192.168.1.4 (to OCP leaf)      │
                        └────────┬──────────┬─────────────────┘
                                 │          │
                        BGP EVPN │          │ BGP EVPN
                     192.168.1.2 │          │ 192.168.1.5
                                 │          │
         ┌───────────────────────┴──┐    ┌──┴───────────────────────────┐
         │   Prov-Leaf              │    │        Leaf-OCP              │
         │   AS: 64520 (underlay)   │    │        AS: 64512             │
         │   AS: 64512 (VRF red)    │    │        192.168.11.2          │
         │                          │    └───────────────┬──────────────┘
         │   VTEP: 100.64.0.1/32    │                    │
         │   VNI 100 (L3 VRF)       │                    │ 192.168.11.0/24
         │   VNI 110 (L2 Bridge)    │                    │ BGP (AS 64514)
         └──────────┬───────────────┘                    │
                    │                                    │
       192.168.10.2 │                                    │
                    │                                    │
         ┌──────────▼───────────────┐        ┌───────────▼────────────────────────┐
         │   Host (RHEL9)           │        │   OpenShift Cluster                │
         │   192.170.1.2            │        │   (fedecluster)                    │
         │                          │        │                                    │
         │   Connected to VNI 110   │        │   - ctlplane-0: 192.168.11.3       │
         │   (Layer 2 Bridge)       │        │   - worker-0:   192.168.11.4       │
         └───────────▲──────────────┘        │   - worker-1:   192.168.11.5       │
                     ║                       │                                    │
                     ╚══════════════════════►│   OpenPERouter:                    │
            VXLAN Tunnels (VNI 110)          │   Manages VXLAN/EVPN               │
            Layer 2 Overlay Network          │   on cluster nodes                 │
                                             └────────────────────────────────────┘

BGP Peering Sessions:
- Spine ↔ Prov-Leaf: eBGP (AS 64612 ↔ AS 64520) - EVPN routes exchanged
- Spine ↔ Leaf-OCP:  eBGP (AS 64612 ↔ AS 64512) - EVPN routes exchanged
- Leaf-OCP ↔ OCP Nodes: eBGP (AS 64512 ↔ AS 64514) - Dynamic peering

VXLAN Tunnels:
- VNI 100: Layer 3 VRF for routed traffic (VRF "red")
- VNI 110: Layer 2 bridge for stretched LAN (Host ↔ OCP VMs)
```

## Architecture Overview

### Components

| Component | Role | AS Number | Key IP Addresses | VNI |
|-----------|------|-----------|------------------|-----|
| **Spine** | Central BGP Router | 64612 | 192.168.1.3, 192.168.1.4 | - |
| **Prov-Leaf** | Provider Gateway & VTEP | 64520 (underlay)<br>64512 (VRF red) | 192.168.1.2<br>VTEP: 100.64.0.1 | 100, 110 |
| **Leaf-OCP** | OpenShift Gateway | 64512 | 192.168.1.5, 192.168.11.2 | - |
| **OCP Nodes** | Cluster Nodes with VXLAN | 64514 | 192.168.11.3-5 | Managed by OpenPERouter |
| **Host** | External RHEL9 Host | - | 192.170.1.2 (Stretched L2) | - |

### Network Segments

- **prov-leaf-spine**: 192.168.1.2/31 (Prov-Leaf ↔ Spine)
- **leafocp-spine**: 192.168.1.4/31 (Leaf-OCP ↔ Spine)
- **prov-leaf-host**: 192.168.10.2/31 (Prov-Leaf ↔ Host)
- **leafocp-node**: 192.168.11.0/24 (Leaf-OCP ↔ OpenShift Cluster)

### VNI Assignments

- **VNI 100**: Layer 3 VRF "red" for routed traffic
- **VNI 110**: Layer 2 bridge for stretched LAN connectivity

## How It Works

### Control Plane: BGP EVPN

1. **Leaf / Spine Topology**: The spine router acts as a central eBGP peer that exchanges EVPN routes between the leaf routers
2. **EVPN Routes**: MAC addresses, IP bindings, and VTEP information are distributed via BGP L2VPN EVPN address family
3. **Multi-AS Design**: Different AS numbers demonstrate realistic enterprise/data center topologies
4. **Dynamic Peering**: OpenShift nodes dynamically peer with Leaf-OCP using BGP listen ranges

### Data Plane: VXLAN

1. **Encapsulation**: Layer 2 Ethernet frames are encapsulated in VXLAN for transport across Layer 3 networks
2. **VTEP**: Virtual Tunnel Endpoints (VTEPs) handle encapsulation/decapsulation
3. **Control Plane Learning**: MAC learning happens via EVPN (not data plane flooding) - `nolearning` mode enabled
4. **Neighbor Suppression**: Reduces ARP/ND flooding by using EVPN-learned information

### Traffic Flow Example

1. VM in OpenShift cluster sends Layer 2 frame
2. OpenPERouter on worker node encapsulates frame in VXLAN (VNI 110)
3. VXLAN packet routed to Leaf-OCP router
4. Leaf-OCP forwards to Spine via BGP-learned EVPN route
5. Spine routes the packet to Prov-Leaf
6. Prov-Leaf decapsulates VXLAN and forwards the frame to external Host
7. Host receives frame as native Layer 2 traffic

## Prerequisites

- **kcli**: Kubernetes/KVM CLI tool for infrastructure provisioning
- **OpenShift Pull Secret**: Saved as `openshift_pull.json`
- **RHEL9 Base Image**: Available in your kcli image repository
- **System Resources**:
  - Minimum 64GB RAM
  - 8+ CPU cores
  - 200GB+ disk space
- **Nested Virtualization**: Enabled if running on a VM

## Installation

### 1. Deploy Infrastructure and OpenShift Cluster

```bash
./setup_vms.sh
```

This script will:
- Delete any existing deployment
- Create network segments (prov-leaf-spine, prov-leaf-host, leafocp-spine, leafocp-node)
- Deploy router VMs (spine, prov-leaf, leafocp) with FRR routing software
- Deploy external host VM
- Install OpenShift 4.20 cluster (1 control plane + 2 workers)
- Configure OpenShift with IP forwarding and BGP capabilities

### 2. Install OpenPERouter on OpenShift

```bash
export KUBECONFIG=~/.kcli/clusters/fedecluster/auth/kubeconfig
./scripts/scripts/deploy_openperouter/install.sh
```

This installs the OpenPERouter operator which provides:
- Custom resources for EVPN/VXLAN configuration (L2VNI, L3VNI, Underlay)
- FRR routing daemon on cluster nodes
- BGP peering with Leaf-OCP router
- VXLAN tunnel management

### 3. Install OpenShift Virtualization components

```bash
export KUBECONFIG=~/.kcli/clusters/fedecluster/auth/kubeconfig
./scripts/install-cnv.sh
```

This installs the HyperConverged operator which provides:
- KubeVirt - The core virtualization runtime that allows VMs to run as Kubernetes resources
- Containerized Data Importer (CDI) - For importing and managing VM disk images
- VM lifecycle management - Creation, scheduling, migration of VMs
- Storage integration - Integration with persistent volumes for VM disks
- Network integration - Connecting VMs to various network types

### 4. Verify Installation

Check that all components are running:

```bash
# Check OpenShift cluster and fabric
kcli list vms

# Verify BGP peering on Leaf-OCP
kcli ssh leafocp "sudo vtysh -c 'show bgp summary'"

# Check EVPN routes on Spine
kcli ssh spine "sudo vtysh -c 'show bgp l2vpn evpn'"

# Verify OpenPERouter deployment
oc get pods -n openperouter-system
oc get crds | grep openperouter
```

## Configuration Files

- **plan.yaml**: kcli infrastructure definition for routers and networks
- **config.yaml**: OpenShift cluster configuration
- **{router}/frr.conf**: FRR BGP/EVPN configuration for each router
- **{router}/setup.sh**: VXLAN and bridge setup scripts
- **scripts/install-openperouter-openshift.sh**: OpenPERouter deployment script

## Use Cases

This demo environment supports:

- **Testing VM Migration**: Evaluate live migration scenarios across Layer 2 stretched networks
- **Hybrid Cloud POCs**: Prototype OpenShift Virtualization integration with existing infrastructure
- **Network Training**: Learn EVPN, VXLAN, and BGP in a containerized/virtualized environment
- **CNV Development**: Develop and test Container-native Virtualization (OpenShift Virtualization) networking features
- **Multi-Cluster Networking**: Explore patterns for connecting multiple OpenShift clusters at Layer 2

## Troubleshooting

### Check BGP Sessions

```bash
kcli ssh leafocp "sudo vtysh -c 'show bgp neighbors'"
```

### Verify VXLAN Interfaces

```bash
kcli ssh prov-leaf "ip -d link show type vxlan"
```

### Check EVPN Routes

```bash
kcli ssh spine "sudo vtysh -c 'show bgp l2vpn evpn route'"
```

## Architecture Decisions

### Why Leaf / Spine Topology?

Using a spine router as a central eBGP peer simplifies BGP configuration and scales better than full mesh peering between all leaves.

### Why Different AS Numbers?

Multi-AS design demonstrates realistic enterprise topologies where different network zones use different AS numbers.

### Why VRF on Prov-Leaf?

VRF "red" demonstrates tenant/service isolation patterns common in data center fabrics.

It will be used in the future to wrap over the L2VNI and provide direct routed ingress to the workload from a provider network.

### Why OVN Routing Via Host?

OpenShift's OVN-Kubernetes must forward traffic to the host network stack to enable FRR (running on the host) to handle BGP routing and VXLAN encapsulation.

## References

- [EVPN RFC 7432](https://datatracker.ietf.org/doc/html/rfc7432)
- [VXLAN RFC 7348](https://datatracker.ietf.org/doc/html/rfc7348)
- [FRR Documentation](https://docs.frrouting.org/)
- [OpenShift Virtualization](https://docs.openshift.com/container-platform/latest/virt/about_virt/about-virt.html)

## License

This project is provided as-is for demonstration and educational purposes.
