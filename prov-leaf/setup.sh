#!/bin/bash
#

# VTEP IP
ip addr add 100.64.0.1/32 dev lo

# Leaf - spine leg
#ip addr add 192.168.1.2/24 dev eth0

# L3 VRF
ip link add red type vrf table 1100

# Leaf - host leg
#ip addr add 192.168.10.2/24 dev eth1
#ip r add 192.168.10.0/24 dev eth1 vrf red

ip link set red up
ip link add br100 type bridge
ip link set br100 master red addrgenmode none
ip link set br100 addr aa:bb:cc:00:00:65
ip link add vni100 type vxlan local 100.64.0.1 dstport 4789 id 100 nolearning
ip link set vni100 master br100 addrgenmode none
ip link set vni100 type bridge_slave neigh_suppress on learning off
ip link set vni100 up
ip link set br100 up


ip link add br110 type bridge
ip link set br110 master red addrgenmode none
ip link set br110 addr aa:bb:cc:00:00:67
ip link add vni110 type vxlan local 100.64.0.1 dstport 4789 id 110 nolearning
ip link set vni110 master br110 addrgenmode none
ip link set vni110 type bridge_slave neigh_suppress on learning off
ip link set vni110 up
ip link set br110 up
ip link set eth1 master br110
