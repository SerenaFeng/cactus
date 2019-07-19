#!/bin/bash

ip route add 10.244.32.0/20 dev istio2_admin
ip route add 192.168.32.0/20 dev istio2_admin
iptables -I FORWARD -i istio2_admin -j ACCEPT
iptables -I FORWARD -o istio2_admin -j ACCEPT

ip route add 10.244.96.0/20 dev istio_admin
ip route add 192.168.96.0/20 dev istio_admin
iptables -I FORWARD -i istio_admin -j ACCEPT
iptables -I FORWARD -o istio_admin -j ACCEPT

