#!/bin/sh
# Bring up ethernet for VirtualBox NAT so sshd is reachable.
# Strategy: load NIC drivers, raise interfaces, let NetworkManager try DHCP,
# and finally fall back to the static VirtualBox NAT addressing.
for mod in virtio_net virtio_pci e1000 e1000e pcnet32; do modprobe "$mod" 2>/dev/null; done
sleep 1

IFACE=""
for i in eth0 enp0s3 enp0s8 ens3; do
    if [ -d "/sys/class/net/$i" ]; then
        IFACE="$i"
        break
    fi
done
[ -n "$IFACE" ] || exit 0

ip link set "$IFACE" up

# Give NetworkManager a chance to manage the device and DHCP.
if command -v nmcli >/dev/null 2>&1; then
    nmcli device set "$IFACE" managed yes >/dev/null 2>&1 || true
    nmcli device connect "$IFACE" >/dev/null 2>&1 || true
fi

# Wait briefly for an IPv4 lease.
n=0
while [ $n -lt 10 ]; do
    if ip -4 addr show "$IFACE" | grep -q inet; then
        exit 0
    fi
    sleep 1
    n=$((n + 1))
done

# Fallback: static VirtualBox NAT configuration.
ip -4 addr flush dev "$IFACE" 2>/dev/null
ip -4 addr add 10.0.2.15/24 dev "$IFACE"
ip -4 route replace default via 10.0.2.2 dev "$IFACE"
printf 'nameserver 10.0.2.3\n' > /etc/resolv.conf
