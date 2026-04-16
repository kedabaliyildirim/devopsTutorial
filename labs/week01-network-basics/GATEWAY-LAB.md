# Advanced Gateway and NAT Lab (Week 1)

This guide provides a comprehensive look at gateway concepts, Network Address Translation (NAT), and hands-on routing exercises within our multi-network lab environment.

## 1. Network Architecture

The lab uses three separate networks to demonstrate real-world segmentation. Traffic between these segments MUST pass through the **Gateway VM**.

```
┌─────────────────────────────────────────────────────────────┐
│                      External Network                        │
│                   192.168.210.0/24 (vagrant-security)        │
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  ┌────────┐ │
│  │ Attacker │  │LogServer │  │   Gateway    │  │ Proxy  │ │
│  │  .10     │  │   .30    │  │ .5 / .5 / .5 │  │  .21   │ │
│  └──────────┘  └──────────┘  └──────┬───────┘  └────┬───┘ │
│                                      │                │       │
└──────────────────────────────────────┼────────────────┼───────┘
                                        │                │
        ┌───────────────────────────────┴──┬─────────────┘
        │                                  │
┌───────▼────────────────┐  ┌─────────────▼──────────────────┐
│  Internal Network      │  │      DMZ Network               │
│  192.168.220.0/24      │  │   192.168.230.0/24             │
│  (vagrant-internal)    │  │   (vagrant-dmz)                │
│                        │  │                                 │
│  ┌──────────┐         │  │   ┌────────────┐     ┌────────┐│
│  │ Defender │         │  │   │ Webserver  │     │ Proxy  ││
│  │   .11    │         │  │   │    .20     │     │  .21   ││
│  └──────────┘         │  │   └────────────┘     └────────┘│
└────────────────────────┘  └─────────────────────────────────┘
```

### VM Placement & Roles

| VM | Networks | IP Addresses | Purpose |
|----|----------|--------------|---------|
| **Gateway** | All 3 | 192.168.210.5 / .220.5 / .230.5 | Routes traffic, performs NAT |
| **Attacker** | External | 192.168.210.10 | External threat simulation |
| **Defender** | Internal | 192.168.220.11 | Protected internal host |
| **Webserver** | DMZ | 192.168.230.20 | Public-facing service |

---

## 2. Gateway and NAT Theory

### What is a Gateway?
A gateway is a network node that serves as an access point to another network.
- **Default Gateway**: The router IP that forwards traffic to destinations outside the local subnet.
- **Routing**: Forwards packets between different networks at Layer 3.

### Network Address Translation (NAT)
NAT modifies IP address information in packet headers while in transit.
- **Source NAT (SNAT/Masquerading)**: Hides internal IPs behind the gateway's external IP for outbound traffic.
- **Destination NAT (DNAT/Port Forwarding)**: Directs external traffic (e.g., port 8080) to an internal server (e.g., webserver:80).

---

## 3. Hands-On Exercises

### Exercise A: Enable IP Forwarding
IP forwarding allows the Linux kernel to act as a router.

1. **Check status**: `sysctl net.ipv4.ip_forward`
2. **Enable (temporary)**: `sudo sysctl -w net.ipv4.ip_forward=1`
3. **Verify from Defender**: `ping -c 3 192.168.210.10` (should now work if gateway is routing).

### Exercise B: Source NAT (Masquerading)
Allow the Internal Network to reach the "Internet" (External Network).

1. **On Gateway**, check rules: `sudo nft list table ip nat`
2. **Add Masquerade rule**:
   ```bash
   sudo nft add rule ip nat postrouting ip saddr 192.168.220.0/24 oifname "eth1" masquerade
   ```
3. **Verify on Gateway**: `sudo conntrack -L` while pinging from Defender.

### Exercise C: Destination NAT (Port Forwarding)
Expose the DMZ Webserver to the External Network.

1. **On Gateway**, add DNAT rule:
   ```bash
   sudo nft add rule ip nat prerouting iifname "eth1" tcp dport 8080 dnat to 192.168.230.20:80
   ```
2. **From Attacker**, test connectivity:
   ```bash
   curl http://192.168.210.5:8080
   ```

---

## 4. Troubleshooting & Monitoring

### Common Commands
- **View Routing Table**: `ip route show`
- **Monitor Real-time Traffic**: `sudo tcpdump -i any -n 'not port 22'`
- **Check NAT Connections**: `sudo conntrack -L`
- **Gateway Status Script**: `./gateway-config/status.sh` (on Gateway VM)

### Success Criteria
- [ ] I can ping between all network segments using the gateway.
- [ ] I understand how SNAT hides my internal IP.
- [ ] I can access the DMZ webserver from the external network via port forwarding.
- [ ] I can explain the difference between a Layer 3 Gateway and a Layer 7 Proxy.

> **Note:** For advanced firewall security policies and persistent configurations, proceed to **Week 2: Firewalls**.
