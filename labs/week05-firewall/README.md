# Week 2 – Firewall Lab (nftables + K8s NetworkPolicies)

## Objectives

- Configure a basic host firewall using nftables
- Understand default deny vs allow-list
- Master Kubernetes NetworkPolicy for microsegmentation (in-depth)
- Harden and test realistic traffic patterns with logging and automation
- Practice attack/defense scenarios with multiple VMs
- Test firewall rules under real attack simulations
- Build defense-in-depth strategies
- Configure gateway firewalls (FORWARD chain) and NAT (integrated content)

## Estimated Time

⏱️ **3.5-4.5 hours** (comprehensive firewall and NetworkPolicy lab)

This lab covers:
- VM setup and verification (~10-15 minutes if VMs already downloaded)
- Host firewall configuration with nftables (~30-40 minutes)
- **Kubernetes NetworkPolicy in-depth** (~60-90 minutes - EXPANDED with 6 exercises)
- Advanced attack/defense scenarios (~30-45 minutes)
- Gateway configuration hands-on (~30-45 minutes)

**Note:** First-time Kubernetes setup may require additional time for Kind/Minikube installation.

## VM Setup for This Lab

Start the required VMs:
```bash
cd /path/to/devops-tutorial
vagrant up attacker defender webserver gateway
```

**VM Roles in This Lab:**
- **defender** (192.168.220.11) - Configure host firewall rules and observe defensive measures
- **attacker** (192.168.210.10) - Generate attack traffic to test firewall rules
- **webserver** (192.168.230.20) - Used for IP-based whitelisting exercises
- **gateway** (192.168.210.5 / 192.168.220.5 / 192.168.230.5) - You'll configure NAT and gateway firewall hands-on

**Lab Flow:**
1. Configure host firewall rules on **defender** (INPUT/OUTPUT chains)
2. Test and attack from **attacker**
3. Use **webserver** for advanced IP whitelisting scenarios
4. Configure gateway with IP forwarding, NAT, and FORWARD chain firewall
5. Test traffic routing between different network segments
6. Monitor and analyze logs on both host and gateway firewalls

See [VM Setup Guide](../../VM-SETUP.md) for detailed instructions.
See [Gateway and NAT Guide](../week01-network-basics/GATEWAY-LAB.md) for comprehensive gateway firewall documentation.

## Understanding: Host Firewalls vs Gateway Firewalls

Before diving into configuration, it's important to understand the difference.

**Prerequisites:** This section builds on gateway concepts from Week 1. If you haven't done Week 1, review the "Understanding Gateways and Routing" section there first to understand what gateways are and how routing works.

**Host Firewall (What you'll primarily use in this lab):**
- Protects a **single machine**
- Uses INPUT chain (traffic TO the host) and OUTPUT chain (traffic FROM the host)
- Example: Firewall on defender VM protects only defender
- Configuration: `/etc/nftables.conf` on each host

**Gateway Firewall (Optional exploration - builds on Week 1):**
- Protects an **entire network**
- Uses FORWARD chain (traffic THROUGH the gateway)
- Requires understanding of routing (covered in Week 1)
- Example: Firewall on gateway VM can filter traffic between attacker and webserver
- Configuration: `/etc/nftables-gateway.conf` on gateway VM
- NAT (Network Address Translation) configuration

| Feature | Host Firewall | Gateway Firewall |
|---------|---------------|------------------|
| **Scope** | Single machine | Entire network segment |
| **Chain** | INPUT/OUTPUT | FORWARD |
| **Location** | On each host | On network gateway |
| **Management** | Distributed | Centralized |
| **Use Case** | Protect individual servers | Network segmentation, perimeter defense |
| **Prerequisites** | None | Week 1 gateway concepts |

**When to use each:**
- **Host Firewall:** Always! Every server should have its own firewall (defense-in-depth)
- **Gateway Firewall:** When you want centralized control of traffic between network segments

**Learning Path:**
1. Week 1: Learn what gateways are, default gateway, basic routing
2. Week 2 (this week): Master host firewalls, optionally explore gateway firewalls and NAT

For detailed gateway firewall and NAT configuration, see the [Advanced Gateway and NAT Lab](../week01-network-basics/GATEWAY-LAB.md).

## 1. Host firewall (nftables)

### Part A: Basic Setup (Original Content)

**Note:** The `/vagrant` directory is disabled in this lab environment (see `config.vm.synced_folder ".", "/vagrant", disabled: true` in Vagrantfile). The `nftables.conf` file exists in the repository at `labs/week05-firewall/nftables.conf`, but you'll need to manually create it on the VM.

On the **defender** VM, create the nftables configuration (content matches the file in the repo):

```bash
vagrant ssh defender

# Create the nftables configuration file
sudo tee /etc/nftables.conf > /dev/null <<'EOF'
# flush ruleset: Clears all existing nftables rules before loading this configuration.
# This ensures a clean state and prevents conflicts with previously loaded rules.
# Safe to use in this lab environment; in production, review existing rules first.
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    # --- Base safe traffic ---

    # Allow loopback
    iif lo accept

    # Allow established/related connections (for SSH/HTTP/etc once opened)
    ct state { established, related } accept

    # Drop invalid packets early (malformed, corrupted, or stateless attacks)
    ct state invalid drop


    # --- ICMP (ping) ---

    # IPv4 ping
    ip protocol icmp icmp type echo-request accept

    # IPv6 ping (if you care about v6; harmless otherwise)
    ip6 nexthdr icmpv6 icmpv6 type echo-request accept


    # --- SSH (port 22) with brute-force protection ---

    # Allow NEW SSH connections, but rate-limit globally
    tcp dport 22 ct state new tcp flags syn limit rate 3/minute burst 5 packets \
      counter log prefix "SSH_NEW_ALLOW " accept

    # Anything beyond that is treated as brute force and dropped/logged
    tcp dport 22 ct state new tcp flags syn counter log prefix "SSH_DROP " drop


    # --- HTTP-like service on 8081 (open to everyone, but you can restrict later) ---

    # Allow NEW connections to 8081 (normal web traffic)
    tcp dport 8081 ct state new tcp flags syn limit rate 100/second burst 200 packets \
      counter log prefix "HTTP8081_NEW " accept


    # --- SYN flood protection (global, all ports) ---

    # Allow SYN packets up to a reasonable rate
    tcp flags syn limit rate 25/second burst 50 packets accept

    # Drop excessive SYN packets (likely attack)
    tcp flags syn counter drop


    # --- Final catch-all ---

    # Everything else gets logged (lightly) and dropped
    limit rate 2/second burst 10 packets counter log prefix "INPUT_DROP " drop
    counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;

    # No forwarding on this host; just log if it happens
    limit rate 2/second burst 5 packets counter log prefix "FW_DROP " drop
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF

# Verify the configuration was created correctly
cat /etc/nftables.conf

# Validate the configuration syntax before loading
sudo nft -c -f /etc/nftables.conf

# Load the configuration
sudo nft -f /etc/nftables.conf
sudo systemctl enable --now nftables
sudo nft list ruleset
```

Expected output hints:

- `sudo nft list ruleset` should print `table inet filter` with chains `input`, `forward`, and `output` and counters initialized to `0`.
- `systemctl status nftables` should show `Active: active (running)` after enabling the service.

Test:

- SSH still works
- Ping may or may not work depending on rules
- Try connecting to blocked ports

Example observations:

- A `curl localhost:8081` before adding allow rules should fail with `Connection refused` or `Connection timed out`; after adding, it returns the HTTP server directory listing.
- `journalctl -k | tail` should show log lines with prefixes like `IN=eth0 OUT=` and the `counter` increments when traffic hits logged rules.

### Part B: NEW - Multi-VM Attack/Defense Testing

1. **Baseline - Before Firewall:**

   On defender VM, start a test web service:
   ```bash
   vagrant ssh defender
   python3 -m http.server 8888 >/tmp/http8888.log 2>&1 &
   ```

   From attacker VM, verify connectivity:
   ```bash
   vagrant ssh attacker
   
   # Test HTTP service
   curl http://192.168.220.11:8888
   
   # Test SSH
   nc -zv 192.168.220.11 22
   
   # Port scan to see what's open
   nmap -sS -p 1-10000 --open 192.168.220.11
   ```

   Expected: All services are accessible. This is your "before" state.

2. **Deploy Default-Deny Firewall:**

   On defender VM, create and apply the default-deny configuration:
   ```bash
   vagrant ssh defender
   
   # Create the default-deny firewall configuration
   sudo tee /etc/nftables-default-deny.conf > /dev/null <<'EOF'
# flush ruleset: Clears all existing nftables rules before loading this configuration.
# This ensures a clean state and prevents conflicts with previously loaded rules.
# Safe to use in this lab environment; in production, review existing rules first.
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    # --- Base safe traffic ---

    # Allow loopback
    iif lo accept

    # Allow established/related connections (for SSH/HTTP/etc once opened)
    ct state { established, related } accept

    # Drop invalid packets early (malformed, corrupted, or stateless attacks)
    ct state invalid drop


    # --- ICMP (ping) ---

    # IPv4 ping
    ip protocol icmp icmp type echo-request accept

    # IPv6 ping (if you care about v6; harmless otherwise)
    ip6 nexthdr icmpv6 icmpv6 type echo-request accept


    # --- SSH (port 22) with brute-force protection ---

    # Allow NEW SSH connections, but rate-limit globally
    tcp dport 22 ct state new tcp flags syn limit rate 3/minute burst 5 packets \
      counter log prefix "SSH_NEW_ALLOW " accept

    # Anything beyond that is treated as brute force and dropped/logged
    tcp dport 22 ct state new tcp flags syn counter log prefix "SSH_DROP " drop


    # --- HTTP-like service on 8081 (open to everyone, but you can restrict later) ---

    # Allow NEW connections to 8081 (normal web traffic)
    tcp dport 8081 ct state new tcp flags syn limit rate 100/second burst 200 packets \
      counter log prefix "HTTP8081_NEW " accept


    # --- SYN flood protection (global, all ports) ---

    # Allow SYN packets up to a reasonable rate
    tcp flags syn limit rate 25/second burst 50 packets accept

    # Drop excessive SYN packets (likely attack)
    tcp flags syn counter drop


    # --- Final catch-all ---

    # Everything else gets logged (lightly) and dropped
    limit rate 2/second burst 10 packets counter log prefix "INPUT_DROP " drop
    counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;

    # No forwarding on this host; just log if it happens
    limit rate 2/second burst 5 packets counter log prefix "FW_DROP " drop
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF

   # Verify the configuration was created correctly
   cat /etc/nftables-default-deny.conf

   # Validate the configuration syntax before loading
   sudo nft -c -f /etc/nftables-default-deny.conf

   # Apply the configuration atomically (all rules loaded at once)
   sudo nft -f /etc/nftables-default-deny.conf

   # Verify rules are active
   sudo nft list ruleset
   ```

   **Why use a config file:** 
   - Configuration is loaded atomically - all rules applied at once, no lockout risk
   - SSH allow rule is already in place when policy drop takes effect
   - Easier to review, version control, and reuse
   - Matches best practices for nftables configuration
   - Eliminates the complexity of ordering individual commands

3. **Test from Attacker - What Gets Blocked:**

   ```bash
   vagrant ssh attacker
   
   # This should now FAIL (timeout)
   curl --max-time 5 http://192.168.220.11:8888
   
   # SSH should still work
   ssh vagrant@192.168.220.11 -o ConnectTimeout=5 -o StrictHostKeyChecking=no whoami
   
   # Ping should work
   ping -c 3 192.168.220.11
   
   # Port scan shows only allowed services
   nmap -sS -p 1-10000 --open 192.168.220.11
   ```

   Expected:
   - HTTP request times out (port 8888 blocked)
   - SSH connection succeeds (port 22 allowed)
   - Ping works (ICMP allowed)
   - nmap shows only port 22 open

4. **Monitor on Defender - See the Attacks:**

   In a separate terminal on defender:
   ```bash
   vagrant ssh defender
   
   # Watch firewall logs in real-time
   sudo journalctl -kf | grep -E "DROP|SSH_ALLOW|ICMP_ALLOW"
   ```

   You should see:
   - `DROP` logs for blocked HTTP attempts
   - `SSH_ALLOW` for successful SSH connections
   - `ICMP_ALLOW` for ping packets

5. **Advanced Attack Scenario - Port Scan Detection:**

   From attacker, run various scan types:
   ```bash
   vagrant ssh attacker
   
   # SYN scan (stealthy)
   sudo nmap -sS -p 1-1000 192.168.220.11
   
   # TCP connect scan
   nmap -sT -p 1-1000 192.168.220.11
   
   # UDP scan (slower)
   sudo nmap -sU -p 53,123,161 192.168.220.11
   
   # Version detection on open ports
   sudo nmap -sV -p 22 192.168.220.11
   ```

   Monitor logs on defender:
   ```bash
   vagrant ssh defender
   
   # Count dropped packets in last minute
   sudo journalctl -k --since "1 minute ago" | grep DROP | wc -l
   
   # Analyze source IPs
   sudo journalctl -k --since "1 minute ago" | grep DROP | grep -oP 'SRC=\K[^ ]+' | sort | uniq -c
   ```

   **Analysis:** High packet counts from single IP indicates scanning. This is how IDS/IPS systems detect reconnaissance.

6. **Advanced Monitoring: Beyond Log Files**

   While `journalctl` shows firewall logs, you need better tools for real-time traffic analysis:

   **Real-Time Traffic Visualization:**
   ```bash
   vagrant ssh defender
   
   # Install monitoring tools
   sudo apt install -y iftop tcptrack tshark
   
   # Monitor bandwidth per connection
   sudo iftop -i eth1 -f "not port 22"  # Exclude SSH noise
   
   # Track TCP connection states
   sudo tcptrack -i eth1
   ```

   **Combining Firewall Logs with Packet Analysis:**
   ```bash
   # Terminal 1: Capture packets that match DROP rules
   sudo tcpdump -i eth1 -w /tmp/firewall-drops.pcap 'not port 22' &
   TCPDUMP_PID=$!
   
   # Terminal 2: Generate some blocked traffic from attacker
   # (run this on attacker VM)
   # nmap -sS -p 1-1000 192.168.220.11
   
   # Terminal 1: Stop capture and analyze
   sleep 30
   # Using specific PID to terminate only our tcpdump process
   sudo kill -TERM $TCPDUMP_PID || echo "Process already terminated"
   
   # Analyze dropped traffic patterns
   tshark -r /tmp/firewall-drops.pcap -q -z io,phs
   tshark -r /tmp/firewall-drops.pcap -q -z conv,tcp
   
   # See which ports were targeted most
   tshark -r /tmp/firewall-drops.pcap -T fields -e tcp.dstport 2>/dev/null | \
     sort | uniq -c | sort -rn | head -20
   ```

   **Correlate Firewall Drops with nftables Counters:**
   ```bash
   # Before attack - record baseline
   sudo nft list ruleset > /tmp/nft-before.txt
   
   # During/after attack
   sudo nft list ruleset > /tmp/nft-after.txt
   
   # Compare counters
   diff /tmp/nft-before.txt /tmp/nft-after.txt
   
   # Or check specific rule counters
   sudo nft list ruleset | grep -A 1 "DROP"
   ```

   **Pro Tips for Firewall Monitoring:**
   - Use `iftop` during active attacks to see bandwidth impact
   - Use `tcptrack` to identify persistent connection attempts (potential backdoors)
   - Combine `journalctl` logs with `tshark` for complete attack timeline
   - Watch for patterns: sequential port scans show as rapid SYN packets to consecutive ports
   - High DROP counts from single IP = scanning; from many IPs = DDoS

### Advanced: Stateful policy + service hardening

**Using VMs (Enhanced):**

1. On defender, add a temporary HTTP service on port 8081 and configure selective access:

   ```bash
   vagrant ssh defender
   
   # Start service
   python3 -m http.server 8081 >/tmp/http8081.log 2>&1 &
   
   # Create updated firewall configuration with port 8081 allowed
   # Note: We use a config file for persistence, not `nft add rule`
   sudo tee /etc/nftables-with-8081.conf > /dev/null <<'EOF'
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    # Base safe traffic
    iif lo accept
    ct state { established, related } accept
    ct state invalid drop

    # ICMP (ping)
    ip protocol icmp icmp type echo-request accept
    ip6 nexthdr icmpv6 icmpv6 type echo-request accept

    # SSH with brute-force protection
    tcp dport 22 ct state new tcp flags syn limit rate 3/minute burst 5 packets \
      counter log prefix "SSH_NEW_ALLOW " accept
    tcp dport 22 ct state new tcp flags syn counter log prefix "SSH_DROP " drop

    # HTTP service on port 8081
    tcp dport 8081 ct state new tcp flags syn limit rate 100/second burst 200 packets \
      counter log prefix "HTTP8081_NEW " accept

    # SYN flood protection (global)
    tcp flags syn limit rate 25/second burst 50 packets accept
    tcp flags syn counter drop

    # Catch-all logging
    limit rate 2/second burst 10 packets counter log prefix "INPUT_DROP " drop
    counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
    limit rate 2/second burst 5 packets counter log prefix "FW_DROP " drop
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF

   # Apply the configuration
   sudo nft -c -f /etc/nftables-with-8081.conf
   sudo nft -f /etc/nftables-with-8081.conf
   ```

2. Test from attacker - should now work:

   ```bash
   vagrant ssh attacker
   curl http://192.168.220.11:8081
   ```

3. **NEW: IP-based whitelisting** - Only allow webserver to access the service:

   ```bash
   vagrant ssh defender
   
   # Create updated configuration with IP-based whitelisting
   # This approach is cleaner and more maintainable than adding/deleting rules
   sudo tee /etc/nftables-ip-whitelist.conf > /dev/null <<'EOF'
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    # Base safe traffic
    iif lo accept
    ct state { established, related } accept
    ct state invalid drop

    # ICMP (ping)
    ip protocol icmp icmp type echo-request accept
    ip6 nexthdr icmpv6 icmpv6 type echo-request accept

    # SSH with brute-force protection
    tcp dport 22 ct state new tcp flags syn limit rate 3/minute burst 5 packets \
      counter log prefix "SSH_NEW_ALLOW " accept
    tcp dport 22 ct state new tcp flags syn counter log prefix "SSH_DROP " drop

    # HTTP service on port 8081 - IP whitelisting
    # Only allow webserver (192.168.230.20)
    ip saddr 192.168.230.20 tcp dport 8081 counter log prefix "WEBSERVER_ALLOW " accept
    tcp dport 8081 counter log prefix "HTTP8081_DENY " drop

    # SYN flood protection (global)
    tcp flags syn limit rate 25/second burst 50 packets accept
    tcp flags syn counter drop

    # Catch-all logging
    limit rate 2/second burst 10 packets counter log prefix "INPUT_DROP " drop
    counter drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;
    limit rate 2/second burst 5 packets counter log prefix "FW_DROP " drop
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF

   # Apply the configuration
   sudo nft -c -f /etc/nftables-ip-whitelist.conf
   sudo nft -f /etc/nftables-ip-whitelist.conf
   ```
   
   **Why use configuration files instead of manual rule manipulation:**
   - Configuration files are **persistent** across reboots (when saved to /etc/nftables.conf)
   - Changes are **atomic** - entire ruleset loads at once, no partial state
   - Easier to **version control** and review
   - No risk of **SSH lockout** - rules load together
   - **Reproducible** - can apply same config on multiple hosts
   - **Safer** - validate with `nft -c -f` before applying
   
   **About `nft add/delete rule` commands:** These are only for temporary testing/debugging. 
   They are NOT persistent across reboots and can leave your firewall in an inconsistent state.
   Always use configuration files for production or learning environments.

   Test from different sources:
   ```bash
   # From attacker (should fail)
   vagrant ssh attacker
   curl --max-time 5 http://192.168.220.11:8081
   
   # From webserver (should succeed)
   vagrant ssh webserver
   curl http://192.168.220.11:8081
   ```

4. **NEW: Rate limiting with nftables:**

   Note: Rate limiting is already configured in our baseline firewall (3 SSH connections/minute).
   This exercise demonstrates adjusting those limits.

   ```bash
   vagrant ssh defender
   
   # View current rate limiting rules
   sudo nft list ruleset | grep -A 2 "SSH"
   
   # The baseline config already has SSH rate limiting:
   # tcp dport 22 ct state new tcp flags syn limit rate 3/minute burst 5 packets
   ```

   Test from attacker:
   ```bash
   vagrant ssh attacker
   
   # Rapid connection attempts
   for i in {1..10}; do ssh -o ConnectTimeout=2 vagrant@192.168.220.11 whoami 2>&1 | head -1; sleep 1; done
   ```

   Monitor on defender:
   ```bash
   vagrant ssh defender
   sudo journalctl -kf | grep SSH_DROP
   # After 3-5 connections, you'll see SSH_DROP messages
   ```
   
   **Note:** The rate limiting is already in place from the configuration file loaded earlier. 
   This demonstrates why configuration files are better than manual `nft add rule` - 
   all protections are defined in one place and load atomically.

5. **NEW: Protect web server from attacker:**

   On webserver VM, configure firewall to only allow defender access:
   ```bash
   vagrant ssh webserver
   
   # Create webserver firewall configuration
   sudo tee /etc/nftables-webserver.conf > /dev/null <<'EOF'
# flush ruleset: Clears all existing nftables rules before loading this configuration.
# This ensures a clean state and prevents conflicts with previously loaded rules.
# Safe to use in this lab environment; in production, review existing rules first.
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    # --- Base safe traffic ---

    # Allow loopback
    iif lo accept

    # Allow established/related connections
    ct state { established, related } accept


    # --- ICMP (ping) ---

    # IPv4 ping
    ip protocol icmp icmp type echo-request accept

    # IPv6 ping
    ip6 nexthdr icmpv6 icmpv6 type echo-request accept


    # --- SSH (port 22) with brute-force protection ---

    # Allow NEW SSH connections, but rate-limit globally
    tcp dport 22 ct state new tcp flags syn \
      limit rate 3/minute burst 5 packets \
      counter log prefix "SSH_NEW " accept

    # Anything beyond that is treated as brute force and dropped/logged
    tcp dport 22 ct state new tcp flags syn \
      counter log prefix "SSH_BRUTE " drop


    # --- HTTP (port 80) - restricted access ---

    # Allow HTTP only from defender
    ip saddr 192.168.220.11 tcp dport 80 ct state new \
      counter log prefix "HTTP_DEFENDER " accept

    # Allow HTTP from host (for testing via forwarded port)
    ip saddr 10.0.2.2 tcp dport 80 ct state new accept


    # --- Final catch-all ---

    # Everything else gets logged (lightly) and dropped
    limit rate 20/second burst 40 packets \
      counter log prefix "WEB_DROP " drop
  }

  chain forward {
    type filter hook forward priority 0; policy drop;

    # No forwarding on this host
    limit rate 10/second burst 20 packets \
      counter log prefix "FW_DROP " drop
  }

  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF
   
   # Validate the configuration syntax before loading
   sudo nft -c -f /etc/nftables-webserver.conf
   
   # Apply the configuration
   sudo nft -f /etc/nftables-webserver.conf
   
   # Verify rules
   sudo nft list ruleset
   ```

   Test:
   ```bash
   # From defender - should work
   vagrant ssh defender
   curl http://192.168.230.20
   
   # From attacker - should fail
   vagrant ssh attacker
   curl --max-time 5 http://192.168.230.20
   ```

6. **NEW: Simulated DDoS mitigation:**

   Note: SYN flood protection is already included in our baseline firewall configurations.
   Let's test it:

   ```bash
   vagrant ssh defender
   
   # View current SYN flood protection
   sudo nft list ruleset | grep -A 1 "syn"
   
   # You'll see rules like:
   # tcp flags syn limit rate 25/second burst 50 packets accept
   # tcp flags syn counter drop
   ```

   Attack from attacker VM:
   ```bash
   vagrant ssh attacker
   
   # Install hping3 if not available
   sudo apt-get update && sudo apt-get install -y hping3
   
   # Controlled SYN flood (for education only!)
   sudo hping3 -S -p 80 --flood --rand-source 192.168.220.11 -c 1000
   ```

   Observe mitigation on defender:
   ```bash
   vagrant ssh defender
   
   # Monitor firewall logs in real-time
   sudo journalctl -kf | grep "INPUT_DROP\|SYN"
   
   # Verify SSH still works despite the attack
   uptime
   ```
   
   **Key Learning:** The SYN flood protection was already active from our configuration file.
   This is why using complete configuration files is better than manual `nft add rule` commands -
   all protective rules are in place from the start.

### Advanced: Extra Hardening for Production

While nftables provides excellent packet filtering, production systems benefit from defense-in-depth with kernel tuning and application-level protection.

#### 1. Kernel-Level SYN Flood Protection

For real production environments, enable kernel-level TCP SYN cookie protection to complement nftables rules:

```bash
vagrant ssh defender

# Create kernel tuning configuration
sudo tee /etc/sysctl.d/99-synflood.conf > /dev/null <<'EOF'
# Enable SYN cookies (protection against SYN flood attacks)
net.ipv4.tcp_syncookies = 1

# Increase SYN backlog queue size
net.ipv4.tcp_max_syn_backlog = 4096

# Reduce SYN-ACK retries (faster timeout of half-open connections)
net.ipv4.tcp_synack_retries = 3

# Reduce SYN retries
net.ipv4.tcp_syn_retries = 3

# Abort connections when SYN backlog is full (rather than dropping silently)
net.ipv4.tcp_abort_on_overflow = 1
EOF

# Apply the settings immediately
sudo sysctl --system

# Verify settings are applied
sudo sysctl net.ipv4.tcp_syncookies
sudo sysctl net.ipv4.tcp_max_syn_backlog
```

**How This Works:**
- **SYN cookies**: When under SYN flood, the kernel encodes connection state in the initial sequence number, avoiding memory exhaustion
- **Larger backlog**: Can handle burst of legitimate connections during attack
- **Faster retries**: Reduces time holding half-open connections
- **Abort on overflow**: Provides explicit failure rather than silent drops

Test the impact:
```bash
# Before kernel tuning - check current limits
sysctl net.ipv4.tcp_max_syn_backlog

# After tuning - should show 4096
sysctl net.ipv4.tcp_max_syn_backlog
```

#### 2. Application-Level Brute-Force Protection

While firewall rate limiting helps, application-level tools like **fail2ban** or **CrowdSec** provide more sophisticated protection:

**Why use fail2ban/CrowdSec instead of just firewall logs?**
- Monitors application logs (`/var/log/auth.log`) not just packet headers
- Detects password failures, not just connection attempts
- Can ban IPs across multiple services simultaneously
- Provides temporary bans that auto-expire
- Shares threat intelligence (CrowdSec)

**Example fail2ban setup for SSH:**
```bash
vagrant ssh defender

# Install fail2ban
sudo apt-get update && sudo apt-get install -y fail2ban

# Create local jail configuration
sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
findtime = 600
bantime = 3600
EOF

# Start fail2ban
sudo systemctl enable --now fail2ban

# Check status
sudo fail2ban-client status sshd
```

Test fail2ban:
```bash
# From attacker VM, try failed SSH logins
vagrant ssh attacker

# This should trigger fail2ban after 3 attempts
for i in {1..5}; do 
  ssh wronguser@192.168.220.11 -o StrictHostKeyChecking=no -o ConnectTimeout=5
  sleep 1
done

# On defender, check fail2ban has banned the attacker
vagrant ssh defender
sudo fail2ban-client status sshd
# Should show banned IP: 192.168.210.10
```

#### 3. SSH Port Considerations

**Non-default SSH port:**
```bash
# Move SSH to port 2222 (in /etc/ssh/sshd_config)
Port 2222

# Update firewall configuration file accordingly
# Edit /etc/nftables.conf and change tcp dport 22 to tcp dport 2222
# Then reload:
sudo nft -c -f /etc/nftables.conf
sudo nft -f /etc/nftables.conf
sudo systemctl restart sshd
```

Note: Always update your firewall configuration file, not just add temporary rules with `nft add rule`.

**Trade-offs:**
- ✅ **Reduces noise**: Cuts automated scanner traffic by ~95%
- ✅ **Cleaner logs**: Easier to spot real attacks
- ❌ **NOT real security**: Targeted attackers will find it via port scan
- ❌ **Complexity**: Harder for legitimate users to remember

**Recommendation**: Use non-default ports for convenience (less log noise), but never rely on it for security. Always combine with:
- Strong authentication (SSH keys only)
- fail2ban/CrowdSec
- Network-level access control (VPN, IP whitelisting)

#### 4. Defense-in-Depth Summary

For production SSH hardening, implement all layers:

| Layer | Tool | Purpose |
|-------|------|---------|
| **Network** | nftables rate limiting | Blocks connection floods |
| **Kernel** | SYN cookies + tuning | Prevents resource exhaustion |
| **Application** | fail2ban/CrowdSec | Detects password attacks |
| **Authentication** | SSH keys only | Eliminates password attacks |
| **Access Control** | VPN or IP whitelist | Limits who can connect |

Test your complete defense:
```bash
# From attacker
vagrant ssh attacker

# Port scan (should see rate limiting)
nmap -p 22 192.168.220.11

# Connection flood (should trigger nftables + kernel)
for i in {1..100}; do nc -zv 192.168.220.11 22 2>&1 & done

# Failed logins (should trigger fail2ban)
for i in {1..5}; do ssh wronguser@192.168.220.11; done
```

On defender, verify all layers working:
```bash
vagrant ssh defender

# nftables counters
sudo nft list ruleset | grep SSH_DROP

# Kernel SYN cookies
sudo netstat -s | grep -i "SYN cookies"

# fail2ban bans
sudo fail2ban-client status sshd
```

### 2. Kubernetes NetworkPolicy (In-Depth)

**Prerequisites:** Complete Week 1 Kubernetes Networking section to understand pods, services, and DNS.

NetworkPolicy is Kubernetes' firewall mechanism for controlling pod-to-pod traffic. Unlike host firewalls (which protect individual VMs), NetworkPolicy implements microsegmentation for containerized applications.

#### Understanding NetworkPolicy

**Key Concepts:**
- **Default Behavior:** Without NetworkPolicy, all pods can communicate freely (open by default)
- **Deny-First:** Once a NetworkPolicy selects a pod, it becomes default-deny
- **Additive:** Multiple policies can select the same pod; rules are combined (OR logic)
- **Namespace-Scoped:** Policies apply within a namespace
- **CNI Required:** Your cluster needs a CNI that supports NetworkPolicy (Calico, Cilium, Weave)

**NetworkPolicy vs Host Firewall:**

| Aspect | Host Firewall (nftables) | Kubernetes NetworkPolicy |
|--------|--------------------------|--------------------------|
| **Scope** | Single VM/host | Pods in a namespace |
| **Selection** | Interface/IP-based | Label-based (dynamic) |
| **Rules** | IP addresses, ports | Pod/namespace selectors |
| **State** | Stateful (conntrack) | Stateful (CNI handles) |
| **Layer** | Layer 3/4 (IP/TCP) | Layer 3/4 + pod identity |

#### NetworkPolicy Structure

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: policy-name
  namespace: target-namespace
spec:
  podSelector:          # Which pods this policy applies to
    matchLabels:
      role: backend
  policyTypes:          # Ingress, Egress, or both
    - Ingress
    - Egress
  ingress:              # Incoming traffic rules
    - from:
        - podSelector:
            matchLabels:
              role: frontend
      ports:
        - protocol: TCP
          port: 8080
  egress:               # Outgoing traffic rules
    - to:
        - namespaceSelector:
            matchLabels:
              name: production
      ports:
        - protocol: TCP
          port: 443
```

#### Lab Setup

```bash
# Create a test cluster (if not already created)
kind create cluster --name netpolicy-lab

# Verify CNI supports NetworkPolicy
kubectl get pods -n kube-system | grep kindnet
# Kind uses kindnet which supports NetworkPolicy
```

#### Exercise 1: Basic Ingress Policy (Allow Frontend → Backend)

**Scenario:** Three-tier application where frontend can access backend, but nothing else can.

```bash
# Create namespace
kubectl create namespace webapp

# Deploy backend (database simulation)
kubectl run backend --image=nginx --labels=app=webapp,tier=backend -n webapp
kubectl expose pod backend --port=80 -n webapp

# Deploy frontend (web tier)
kubectl run frontend --image=nginx --labels=app=webapp,tier=frontend -n webapp

# Deploy unauthorized pod
kubectl run hacker --image=busybox --labels=app=unauthorized -n webapp -- sleep 3600

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod/backend -n webapp --timeout=60s
kubectl wait --for=condition=Ready pod/frontend -n webapp --timeout=60s
kubectl wait --for=condition=Ready pod/hacker -n webapp --timeout=60s

# Test BEFORE policy (should work from both)
kubectl exec -n webapp frontend -- wget -qO- --timeout=2 http://backend
kubectl exec -n webapp hacker -- wget -qO- --timeout=2 http://backend
# Both should succeed
```

**Apply NetworkPolicy:**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-ingress
  namespace: webapp
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: frontend
      ports:
        - protocol: TCP
          port: 80
EOF
```

**Test AFTER policy:**

```bash
# Should succeed (frontend has access)
kubectl exec -n webapp frontend -- wget -qO- --timeout=2 http://backend

# Should TIMEOUT (hacker blocked)
kubectl exec -n webapp hacker -- wget -qO- --timeout=2 http://backend
# Expected: wget: download timed out
```

**Verify the policy:**

```bash
kubectl describe networkpolicy backend-ingress -n webapp
# Shows:
# - PodSelector: tier=backend
# - Allowing ingress traffic from: tier=frontend
# - Affecting 1 pod (backend)
```

#### Exercise 2: Default Deny All + Selective Allow

**Best Practice:** Start with deny-all, then add specific allows (whitelist approach).

```bash
# Create production namespace
kubectl create namespace production
kubectl label namespace production env=production

# Deploy microservices
kubectl run web --image=nginx --labels=app=myapp,tier=web -n production
kubectl expose pod web --port=80 -n production

kubectl run api --image=nginx --labels=app=myapp,tier=api -n production
kubectl expose pod api --port=80 -n production

kubectl run db --image=postgres:alpine --labels=app=myapp,tier=db -n production --env=POSTGRES_PASSWORD=secret
kubectl expose pod db --port=5432 -n production

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod/web -n production --timeout=60s
kubectl wait --for=condition=Ready pod/api -n production --timeout=60s
kubectl wait --for=condition=Ready pod/db -n production --timeout=60s

# Apply default deny-all for ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}  # Applies to all pods in namespace
  policyTypes:
    - Ingress
EOF

# Test - nothing should work
kubectl run test --image=busybox -n production --rm -it -- wget -qO- --timeout=2 http://web
# Should timeout
```

**Add selective allows:**

```bash
# Allow web → api
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-web-to-api
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: web
      ports:
        - protocol: TCP
          port: 80
EOF

# Allow api → db
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-api-to-db
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: db
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: api
      ports:
        - protocol: TCP
          port: 5432
EOF

# Allow external traffic to web tier (from ingress controller namespace)
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-to-web
  namespace: production
spec:
  podSelector:
    matchLabels:
      tier: web
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - protocol: TCP
          port: 80
    - from: []  # Allow from anywhere as fallback for testing
      ports:
        - protocol: TCP
          port: 80
EOF
```

#### Exercise 3: Egress Controls (Outbound Traffic)

**Scenario:** Restrict what external resources pods can access.

```bash
# Create namespace
kubectl create namespace restricted

# Deploy app
kubectl run app --image=busybox --labels=app=myapp -n restricted -- sleep 3600

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/app -n restricted --timeout=60s

# Test BEFORE policy (should work)
kubectl exec -n restricted app -- wget -qO- --timeout=2 https://google.com
kubectl exec -n restricted app -- nslookup google.com
```

**Apply egress policy:**

```bash
# Deny all egress, then allow only DNS and specific external API
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-controls
  namespace: restricted
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
    - Egress
  egress:
    # Allow DNS (kube-dns in kube-system)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
        - podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    # Allow specific external IP (example: 8.8.8.8)
    - to:
        - ipBlock:
            cidr: 8.8.8.8/32
      ports:
        - protocol: TCP
          port: 443
    # Allow traffic within same namespace
    - to:
        - podSelector: {}
EOF
```

**Test AFTER policy:**

```bash
# DNS should work
kubectl exec -n restricted app -- nslookup google.com

# Access to google.com should fail (not in allowed IPs)
kubectl exec -n restricted app -- wget -qO- --timeout=2 https://google.com
# Expected: timeout

# Access to 8.8.8.8 should work
kubectl exec -n restricted app -- wget -qO- --timeout=2 https://8.8.8.8
```

#### Exercise 4: Namespace Isolation

**Scenario:** Isolate different environments (dev, staging, prod) from each other.

```bash
# Create namespaces
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod

kubectl label namespace dev env=dev
kubectl label namespace staging env=staging
kubectl label namespace prod env=prod

# Deploy apps in each namespace
for ns in dev staging prod; do
  kubectl run app --image=nginx --labels=app=myapp -n $ns
  kubectl expose pod app --port=80 -n $ns
done

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod/app -n dev --timeout=60s
kubectl wait --for=condition=Ready pod/app -n staging --timeout=60s
kubectl wait --for=condition=Ready pod/app -n prod --timeout=60s

# Test cross-namespace communication BEFORE policy
kubectl run test --image=busybox -n dev --rm -it -- wget -qO- --timeout=2 http://app.staging
# Should work
```

**Apply namespace isolation:**

```bash
# Deny all cross-namespace traffic for prod
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-cross-namespace
  namespace: prod
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    # Only allow from same namespace
    - from:
        - podSelector: {}
EOF

# Test AFTER policy
kubectl run test --image=busybox -n dev --rm -it -- wget -qO- --timeout=2 http://app.prod
# Should timeout

kubectl run test --image=busybox -n prod --rm -it -- wget -qO- --timeout=2 http://app.prod
# Should work (same namespace)
```

#### Exercise 5: Advanced - External Traffic Control with CIDR

**Scenario:** Allow egress only to specific external IP ranges (e.g., your company's API servers).

```bash
# Create namespace
kubectl create namespace api-client

# Deploy app
kubectl run client --image=busybox --labels=app=api-client -n api-client -- sleep 3600

# Wait for pod to be ready
kubectl wait --for=condition=Ready pod/client -n api-client --timeout=60s

# Apply strict egress policy
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-specific-external
  namespace: api-client
spec:
  podSelector:
    matchLabels:
      app: api-client
  policyTypes:
    - Egress
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
    # Allow only specific external CIDR (example: 203.0.113.0/24)
    - to:
        - ipBlock:
            cidr: 203.0.113.0/24
            except:
              - 203.0.113.5/32  # Exclude specific IP in that range
      ports:
        - protocol: TCP
          port: 443
    # Allow to other pods in same namespace
    - to:
        - podSelector: {}
EOF
```

#### Exercise 6: Real-World Scenario - Microservices Security

**Scenario:** Secure a typical microservices application with NetworkPolicy.

```
┌─────────────────────────────────────────────────────┐
│                   Production                         │
│                                                      │
│  Internet → Ingress → Frontend → Backend → Database │
│                                                      │
└─────────────────────────────────────────────────────┘
```

```bash
# Setup
kubectl create namespace microservices
kubectl label namespace microservices env=production

# Deploy all tiers
kubectl run frontend --image=nginx --labels=app=shop,tier=frontend -n microservices
kubectl expose pod frontend --port=80 -n microservices

kubectl run backend --image=nginx --labels=app=shop,tier=backend -n microservices
kubectl expose pod backend --port=8080 -n microservices

kubectl run database --image=postgres:alpine --labels=app=shop,tier=database \
  --env=POSTGRES_PASSWORD=secret -n microservices
kubectl expose pod database --port=5432 -n microservices

# Wait for pods to be ready
kubectl wait --for=condition=Ready pod/frontend -n microservices --timeout=60s
kubectl wait --for=condition=Ready pod/backend -n microservices --timeout=60s
kubectl wait --for=condition=Ready pod/database -n microservices --timeout=60s

# Complete NetworkPolicy suite
cat <<EOF | kubectl apply -f -
---
# Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: microservices
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# Allow frontend ingress from anywhere (public-facing)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-ingress
  namespace: microservices
spec:
  podSelector:
    matchLabels:
      tier: frontend
  policyTypes:
    - Ingress
  ingress:
    - from: []  # Allow from anywhere
      ports:
        - protocol: TCP
          port: 80
---
# Allow frontend → backend
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-from-frontend
  namespace: microservices
spec:
  podSelector:
    matchLabels:
      tier: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: frontend
      ports:
        - protocol: TCP
          port: 8080
---
# Allow backend → database
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-from-backend
  namespace: microservices
spec:
  podSelector:
    matchLabels:
      tier: database
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              tier: backend
      ports:
        - protocol: TCP
          port: 5432
---
# Allow DNS for all pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: microservices
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
---
# Allow egress within namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal-egress
  namespace: microservices
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector: {}
EOF
```

**Test the security:**

```bash
# Test 1: Frontend accessible from external
kubectl run test --image=busybox --rm -it -- wget -qO- --timeout=2 http://frontend.microservices

# Test 2: Backend NOT accessible from external
kubectl run test --image=busybox --rm -it -- wget -qO- --timeout=2 http://backend.microservices:8080
# Should timeout

# Test 3: Database NOT accessible from frontend
kubectl exec -n microservices frontend -- wget -qO- --timeout=2 http://database:5432
# Should timeout

# Test 4: Backend CAN access database
kubectl exec -n microservices backend -- nc -zv database 5432
# Should succeed
```

#### Troubleshooting NetworkPolicy

**Problem: Policy doesn't seem to work**

```bash
# Check if CNI supports NetworkPolicy
kubectl get pods -n kube-system | grep -E "calico|cilium|weave"

# Check policy syntax
kubectl describe networkpolicy <policy-name> -n <namespace>

# Check if policy is selecting pods
kubectl get pods -n <namespace> --show-labels
kubectl get networkpolicy <policy-name> -n <namespace> -o yaml | grep -A 5 podSelector

# Check policy affects (should list affected pods)
kubectl describe networkpolicy <policy-name> -n <namespace> | grep "Affecting"
```

**Problem: Traffic still blocked after allow rule**

```bash
# Check if multiple policies apply (they're additive)
kubectl get networkpolicy -n <namespace>

# Check for default deny policy
kubectl get networkpolicy -n <namespace> -o yaml | grep "podSelector: {}"

# Verify labels match
kubectl get pods -n <namespace> --show-labels
# Compare with your NetworkPolicy selectors
```

**Problem: Can't access external services**

```bash
# Check if egress policy exists
kubectl get networkpolicy -n <namespace> -o yaml | grep -A 10 "policyTypes"

# Add DNS egress if missing
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: <your-namespace>
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
EOF
```

#### NetworkPolicy Best Practices

1. **Start with Default Deny**
   ```yaml
   # Apply to all namespaces
   podSelector: {}
   policyTypes: [Ingress, Egress]
   ```

2. **Use Meaningful Labels**
   ```yaml
   labels:
     app: myapp
     tier: frontend
     environment: production
   ```

3. **Document Your Policies**
   ```yaml
   metadata:
     name: allow-frontend-to-backend
     annotations:
       description: "Allows frontend pods to access backend API"
   ```

4. **Test Before Production**
   - Test in dev/staging first
   - Use dry-run mode if available
   - Monitor logs for blocked traffic

5. **Combine with Other Security Layers**
   - Service mesh (mTLS, advanced policies)
   - Pod Security Policies/Standards
   - RBAC for control plane
   - Runtime security (Falco - Week 6)

#### Advanced: NetworkPolicy + Service Mesh

NetworkPolicy provides L3/L4 security. For L7 (HTTP-level) policies, use a service mesh:

| Feature | NetworkPolicy | Service Mesh (Istio/Linkerd) |
|---------|---------------|------------------------------|
| **Layer** | L3/L4 (IP/TCP) | L7 (HTTP/gRPC) |
| **Granularity** | Pod-to-pod | Method-level (GET /api/users) |
| **mTLS** | No | Yes |
| **Rate Limiting** | No | Yes |
| **Authorization** | Basic | JWT, RBAC, ABAC |

You'll explore service mesh in advanced topics!

#### Cleanup

```bash
# Delete all test namespaces
kubectl delete namespace webapp production restricted api-client microservices

# Delete Kind cluster
kind delete cluster --name netpolicy-lab
```

#### NetworkPolicy Checklist

- [ ] I understand default-allow vs default-deny
- [ ] I can create basic ingress policies
- [ ] I can create egress policies with DNS
- [ ] I can implement namespace isolation
- [ ] I can secure a multi-tier application
- [ ] I can troubleshoot NetworkPolicy issues
- [ ] I understand the difference between NetworkPolicy and host firewalls
- [ ] I can combine multiple policies effectively

### 3. Automation with Ansible

Run:

```bash
cd ../../ansible
ansible-playbook -i inventory.ini site.yml --tags firewall
```

This should push nftables.conf to your target hosts.

**Advanced automation idea:** add a handler to tail `journalctl -k -f` during deployment to verify log rules are taking effect, then codify assertions with `assert` tasks.

## Example solutions / what “good” looks like

- `journalctl -k | grep lab8081` should show SYN packets with source IP/port whenever you curl or nmap the service.
- An `nmap` scan after default-deny should list only `22/tcp open` and `8081/tcp open` with other ports `filtered`.
- In Kubernetes, requests to `mockapi` succeed while requests to `kubernetes.default.svc` hang or time out, proving egress is restricted.
- The Ansible run should report changed tasks for firewall pushes and zero failures.
- `kubectl describe networkpolicy egress-allow-mockapi -n np-lab` should show `Policy Types: Ingress, Egress` and list the allowed destination selector, confirming the policy applied.

## Checklist

### Basic Tasks
- [ ] nftables is active and ruleset is applied
- [ ] You tested connectivity before/after firewall
- [ ] You ran the Ansible playbook (even if just on localhost)
- [ ] Default-deny posture validated with nmap and kernel log evidence

### Kubernetes NetworkPolicy Tasks (EXPANDED)
- [ ] Completed Exercise 1: Basic ingress policy (frontend → backend)
- [ ] Completed Exercise 2: Default deny-all + selective allow (three-tier app)
- [ ] Completed Exercise 3: Egress controls (DNS + external IP whitelist)
- [ ] Completed Exercise 4: Namespace isolation (dev/staging/prod)
- [ ] Completed Exercise 5: External traffic control with CIDR blocks
- [ ] Completed Exercise 6: Real-world microservices security scenario
- [ ] Can create ingress NetworkPolicy from scratch
- [ ] Can create egress NetworkPolicy with DNS allowance
- [ ] Can troubleshoot NetworkPolicy issues
- [ ] Understand default-allow vs default-deny in Kubernetes
- [ ] Can explain difference between NetworkPolicy and host firewalls

### VM-Based Attack/Defense Tasks
- [ ] Completed baseline connectivity test from attacker to defender
- [ ] Deployed default-deny firewall on defender and verified blocking
- [ ] Monitored firewall logs during port scan from attacker
- [ ] Analyzed dropped packet counts and source IPs
- [ ] Configured IP-based whitelisting (webserver-only access)
- [ ] Tested rate limiting on SSH connections
- [ ] Protected webserver with firewall allowing only defender access
- [ ] Simulated and mitigated SYN flood attack
- [ ] Documented attack timeline with firewall log evidence

### Advanced Understanding
- [ ] Can explain difference between DROP and REJECT
- [ ] Understand stateful vs stateless firewall rules
- [ ] Know how to detect port scans in firewall logs
- [ ] Can implement defense-in-depth with multiple VM firewalls

### Gateway Configuration Tasks (NEW - Integrated)
- [ ] Started gateway VM and verified it's running
- [ ] Enabled IP forwarding on gateway manually
- [ ] Fixed gateway default route (Exercise 1.5)
- [ ] Configured Source NAT (SNAT/Masquerading) for internal networks
- [ ] Tested NAT functionality between networks
- [ ] Configured gateway FORWARD chain firewall rules
- [ ] Blocked specific traffic between networks and verified
- [ ] Configured Destination NAT (DNAT/Port Forwarding)
- [ ] Monitored gateway traffic with conntrack and logs
- [ ] Created connectivity test matrix across all networks
- [ ] Used traceroute to verify routing through gateway
- [ ] Understand difference between host firewall and gateway firewall
- [ ] Can explain when to use INPUT vs FORWARD chains

## Gateway Configuration Hands-On

**Prerequisites:** Complete Week 1 for basic networking concepts. This section provides hands-on practice configuring a gateway with NAT and firewall rules.

The gateway VM in this lab connects three different networks and needs proper configuration to route traffic between them. Unlike Week 1 (which was conceptual), you'll now configure the gateway yourself.

### Understanding the Multi-Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                      External Network                        │
│                   192.168.210.0/24 (vagrant-security)        │
│                                                               │
│  ┌──────────┐          ┌──────────────┐      ┌──────────┐  │
│  │ Attacker │──────────│   Gateway    │──────│  Proxy   │  │
│  │  .10     │          │ .5 / .5 / .5 │      │.21 / .21 │  │
│  └──────────┘          └──────┬───────┘      └────┬─────┘  │
│                               │                     │         │
└───────────────────────────────┼─────────────────────┼────────┘
                                │                     │
        ┌───────────────────────┴──────┬──────────────┘
        │                              │
┌───────▼────────────────┐  ┌──────────▼────────────────────┐
│  Internal Network      │  │      DMZ Network               │
│  192.168.220.0/24      │  │   192.168.230.0/24             │
│  (vagrant-internal)    │  │   (vagrant-dmz)                │
│                        │  │                                 │
│  ┌──────────┐         │  │   ┌────────────┐               │
│  │ Defender │         │  │   │ Webserver  │               │
│  │   .11    │         │  │   │    .20     │               │
│  └──────────┘         │  │   └────────────┘               │
│  ┌──────────┐         │  │                                 │
│  │LogServer │         │  │                                 │
│  │   .30    │         │  │                                 │
│  └──────────┘         │  │                                 │
│  ┌──────────┐         │  │                                 │
│  │Monitored │         │  │                                 │
│  │   .40    │         │  │                                 │
│  └──────────┘         │  │                                 │
└────────────────────────┘  └─────────────────────────────────┘
```

**Key Point:** VMs on different networks (like defender on .220.x and webserver on .230.x) cannot communicate until you configure the gateway properly!

### Exercise 1: Enable IP Forwarding

IP forwarding is the kernel parameter that allows a Linux machine to act as a router.

```bash
vagrant ssh gateway

# Check current status (should show 0 - disabled)
sysctl net.ipv4.ip_forward
cat /proc/sys/net/ipv4/ip_forward

# Test connectivity BEFORE enabling (should fail)
# From another terminal:
vagrant ssh defender
ping -c 3 192.168.230.20  # Try to reach webserver
# This should FAIL or timeout
```

Now enable IP forwarding:

```bash
vagrant ssh gateway

# Enable IP forwarding (temporary - lost on reboot)
sudo sysctl -w net.ipv4.ip_forward=1

# Verify it's enabled
cat /proc/sys/net/ipv4/ip_forward  # Should show: 1

# Make it persistent across reboots
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.conf

# Apply all sysctl settings
sudo sysctl -p
```

Test again from defender:

```bash
vagrant ssh defender
ping -c 3 192.168.230.20  # Should now work!
```

**What you learned:** IP forwarding is essential for routing. Without it, the gateway drops packets instead of forwarding them between networks.

### Exercise 1.5: Fix Default Route (Important!)

Due to Vagrant's default networking, the gateway VM has a default route pointing to the management network (eth0) instead of the external network. This must be fixed for the gateway to function properly.

```bash
vagrant ssh gateway

# Check current default route
ip route | grep default
# You'll see: default via 192.168.121.1 dev eth0 (Vagrant's management network)

# Determine the external interface (should be eth1)
EXTERNAL_IF=$(ip -o addr show | grep "192.168.210.5" | awk '{print $2}')
echo "External interface: $EXTERNAL_IF"

# Fix the default route - delete old, add new
sudo ip route del default via 192.168.121.1 dev eth0
sudo ip route add default via 192.168.210.1 dev $EXTERNAL_IF

# Verify the new default route
ip route | grep default
# Should now show: default via 192.168.210.1 dev eth1

# Make it persistent across reboots
sudo tee -a /etc/network/if-up.d/gateway-routes > /dev/null <<'EOF'
#!/bin/bash
# Fix default route for gateway
if [ "$IFACE" = "eth1" ]; then
  ip route del default via 192.168.121.1 dev eth0 2>/dev/null || true
  ip route add default via 192.168.210.1 dev eth1 || true
fi
EOF

sudo chmod +x /etc/network/if-up.d/gateway-routes
```

**Why this is needed:** Vagrant automatically configures eth0 (management network) as the default route. Since the gateway needs to route traffic between networks, it should use eth1 (external network) as its default route.

### Exercise 2: Configure Source NAT (SNAT/Masquerading)

NAT allows internal networks to access external networks using the gateway's IP address.

**Prerequisites:** Make sure you've completed Exercise 1.5 (fix default route) before proceeding.

First, determine the external interface:

```bash
vagrant ssh gateway

# Find which interface connects to the external network (192.168.210.0/24)
EXTERNAL_IF=$(ip -o addr show | grep "192.168.210.5" | awk '{print $2}')
echo "External interface: $EXTERNAL_IF"
# Should show something like: eth1
```

Configure NAT with nftables:

```bash
vagrant ssh gateway

# Determine the external interface
EXTERNAL_IF=$(ip -o addr show | grep "192.168.210.5" | awk '{print $2}')
echo "External interface: $EXTERNAL_IF"

# Create NAT configuration
sudo tee /etc/nftables-gateway.conf > /dev/null <<EOF
# Gateway NAT Configuration
flush ruleset

table ip nat {
  # SNAT/Masquerading for outbound traffic
  chain postrouting {
    type nat hook postrouting priority 100; policy accept;
    
    # Masquerade traffic from internal network going to external
    ip saddr 192.168.220.0/24 oifname "$EXTERNAL_IF" masquerade
    
    # Masquerade traffic from DMZ going to external
    ip saddr 192.168.230.0/24 oifname "$EXTERNAL_IF" masquerade
  }
  
  # DNAT for inbound traffic (port forwarding)
  chain prerouting {
    type nat hook prerouting priority -100; policy accept;
    # Example: Forward external port 8080 to webserver:80
    # iifname "$EXTERNAL_IF" tcp dport 8080 dnat to 192.168.230.20:80
  }
}

# Firewall rules for gateway
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    
    # Accept established connections
    ct state { established, related } accept
    
    # Accept loopback
    iif lo accept
    
    # Accept ICMP (ping)
    ip protocol icmp accept
    
    # Accept SSH
    tcp dport 22 accept
    
    # Drop invalid packets
    ct state invalid drop
  }
  
  # FORWARD chain: Controls traffic THROUGH the gateway
  chain forward {
    type filter hook forward priority 0; policy drop;
    
    # Accept established/related connections
    ct state { established, related } accept
    
    # Allow internal network to reach DMZ
    ip saddr 192.168.220.0/24 ip daddr 192.168.230.0/24 accept
    
    # Allow DMZ to reach external (for updates, etc.)
    ip saddr 192.168.230.0/24 oifname "$EXTERNAL_IF" accept
    
    # Allow internal network to reach external (internet)
    ip saddr 192.168.220.0/24 oifname "$EXTERNAL_IF" accept
    
    # Log forwarded traffic for monitoring (accepted traffic)
    counter log prefix "GATEWAY_FWD: " accept
    
    # Drop and log everything else (default-deny)
    counter log prefix "GATEWAY_DROP: " drop
  }
  
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF

# Validate the configuration
sudo nft -c -f /etc/nftables-gateway.conf

# Apply the configuration
sudo nft -f /etc/nftables-gateway.conf

# Make it persistent
sudo cp /etc/nftables-gateway.conf /etc/nftables.conf
sudo systemctl enable nftables
sudo systemctl restart nftables

# Verify NAT rules
sudo nft list table ip nat
```

Test NAT functionality:

```bash
# From defender (internal network)
vagrant ssh defender

# Try to reach external network through gateway
ping -c 3 192.168.210.10  # Attacker on external network
# Should work now!

# On gateway, monitor connection tracking to see NAT in action:
vagrant ssh gateway
sudo conntrack -L | grep 192.168.220.11
# Should show connections with source IP translated to gateway's IP
```

**Understanding NAT Flow:**

1. Defender (192.168.220.11) sends packet to Attacker (192.168.210.10)
2. Packet reaches Gateway with source=192.168.220.11
3. Gateway's NAT rule rewrites source to 192.168.210.5 (gateway's external IP)
4. Attacker receives packet appearing to come from 192.168.210.5
5. Attacker's reply goes to 192.168.210.5
6. Gateway reverse-NAT changes destination back to 192.168.220.11
7. Defender receives the reply

### Exercise 3: Configure Gateway Firewall (FORWARD Chain)

The FORWARD chain controls traffic passing THROUGH the gateway between networks.

View current FORWARD rules:

```bash
vagrant ssh gateway
sudo nft list chain inet filter forward
```

**Scenario: Block defender from accessing webserver on port 80**

For testing purposes only, you can temporarily add a rule. However, for permanent changes, 
always use a configuration file.

**Temporary testing (NOT persistent across reboots):**

```bash
vagrant ssh gateway

# TEMPORARY TEST ONLY - Insert a drop rule
# WARNING: This is lost on reboot. For production, use a config file.
sudo nft insert rule inet filter forward ip saddr 192.168.220.11 ip daddr 192.168.230.20 tcp dport 80 counter log prefix "BLOCK_DEFENDER_WEB: " drop

# Test from defender (should fail)
vagrant ssh defender
curl --max-time 5 http://192.168.230.20
# Should timeout

# Check gateway logs
vagrant ssh gateway
sudo journalctl -k | grep BLOCK_DEFENDER_WEB

# Remove the blocking rule
# First, list rules with handles
sudo nft -a list chain inet filter forward

# Delete the rule using its handle number
sudo nft delete rule inet filter forward handle <handle_number>

# Verify access is restored
vagrant ssh defender
curl http://192.168.230.20
# Should work again
```

**Persistent approach (recommended for production):**

To permanently block this traffic, add the rule to your gateway configuration file:

```bash
vagrant ssh gateway

# Edit the gateway config to add the blocking rule
sudo nano /etc/nftables-gateway.conf
# Add this line in the forward chain BEFORE the generic accept rules:
# ip saddr 192.168.220.11 ip daddr 192.168.230.20 tcp dport 80 counter log prefix "BLOCK_DEFENDER_WEB: " drop

# Then reload:
sudo nft -c -f /etc/nftables-gateway.conf
sudo nft -f /etc/nftables-gateway.conf
```

**Scenario: Rate limit traffic between networks**

**Temporary testing (NOT persistent):**

```bash
vagrant ssh gateway

# TEMPORARY TEST ONLY - Add rate limiting rules
# WARNING: These rules are lost on reboot
sudo nft insert rule inet filter forward ip protocol icmp limit rate 10/second counter accept
sudo nft add rule inet filter forward ip protocol icmp counter log prefix "ICMP_RATE_LIMIT: " drop

# Test with rapid pings
vagrant ssh defender
ping -f 192.168.230.20
# Should see rate limiting (packet loss)

# Monitor on gateway
vagrant ssh gateway
sudo journalctl -kf | grep ICMP_RATE_LIMIT

# Clean up temporary rules after testing
sudo nft flush chain inet filter forward
# Then reload your original gateway config
sudo nft -f /etc/nftables-gateway.conf
```

**Persistent approach (recommended):**

To add permanent rate limiting, modify your gateway configuration file to include
rate limiting rules in the forward chain before the generic accept rules.

### Exercise 4: Destination NAT (Port Forwarding)

DNAT allows external clients to access internal servers through the gateway.

**Scenario: Forward external port 8080 to webserver's port 80**

The gateway configuration file from Exercise 2 already has a DNAT section. Let's add the port forwarding rule there:

```bash
vagrant ssh gateway

# Determine external interface
EXTERNAL_IF=$(ip -o addr show | grep "192.168.210.5" | awk '{print $2}')
echo "External interface: $EXTERNAL_IF"

# Edit the gateway config file to uncomment/add DNAT rule
sudo cp /etc/nftables-gateway.conf /etc/nftables-gateway.conf.backup

# Update the configuration with DNAT
sudo tee /etc/nftables-gateway.conf > /dev/null <<EOF
# Gateway NAT Configuration
flush ruleset

table ip nat {
  # SNAT/Masquerading for outbound traffic
  chain postrouting {
    type nat hook postrouting priority 100; policy accept;
    
    # Masquerade traffic from internal network going to external
    ip saddr 192.168.220.0/24 oifname "$EXTERNAL_IF" masquerade
    
    # Masquerade traffic from DMZ going to external
    ip saddr 192.168.230.0/24 oifname "$EXTERNAL_IF" masquerade
  }
  
  # DNAT for inbound traffic (port forwarding)
  chain prerouting {
    type nat hook prerouting priority -100; policy accept;
    # Forward external port 8080 to webserver:80
    iifname "$EXTERNAL_IF" tcp dport 8080 dnat to 192.168.230.20:80
  }
}

# Firewall rules for gateway
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    
    # Accept established connections
    ct state { established, related } accept
    
    # Accept loopback
    iif lo accept
    
    # Accept ICMP (ping)
    ip protocol icmp accept
    
    # Accept SSH
    tcp dport 22 accept
    
    # Drop invalid packets
    ct state invalid drop
  }
  
  # FORWARD chain: Controls traffic THROUGH the gateway
  chain forward {
    type filter hook forward priority 0; policy drop;
    
    # Accept established/related connections
    ct state { established, related } accept
    
    # Allow port-forwarded traffic to webserver
    ip daddr 192.168.230.20 tcp dport 80 ct state new counter accept
    
    # Allow internal network to reach DMZ
    ip saddr 192.168.220.0/24 ip daddr 192.168.230.0/24 accept
    
    # Allow DMZ to reach external (for updates, etc.)
    ip saddr 192.168.230.0/24 oifname "$EXTERNAL_IF" accept
    
    # Allow internal network to reach external (internet)
    ip saddr 192.168.220.0/24 oifname "$EXTERNAL_IF" accept
    
    # Log forwarded traffic for monitoring (accepted traffic)
    counter log prefix "GATEWAY_FWD: " accept
    
    # Drop and log everything else (default-deny)
    counter log prefix "GATEWAY_DROP: " drop
  }
  
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF

# Validate and apply
sudo nft -c -f /etc/nftables-gateway.conf
sudo nft -f /etc/nftables-gateway.conf

# Verify NAT table
sudo nft list table ip nat

# Test from attacker (external network)
vagrant ssh attacker
curl http://192.168.210.5:8080
# Should show webserver's HTML page
```

**Key Point:** We added the DNAT rule directly to the configuration file, not with `nft add rule`.
This ensures the port forwarding persists across reboots.

**What happened:**
1. Attacker sends request to 192.168.210.5:8080
2. Gateway's DNAT rule rewrites destination to 192.168.230.20:80
3. Webserver receives request and responds
4. Gateway reverse-NAT changes source back to 192.168.210.5:8080
5. Attacker receives response

### Exercise 5: Monitoring Gateway Traffic

**Connection Tracking:**

```bash
vagrant ssh gateway

# View active connections through gateway
sudo conntrack -L

# Count connections by source network
sudo conntrack -L | grep -oP 'src=\K[^ ]+' | sort | uniq -c | sort -rn

# Monitor new connections in real-time
sudo conntrack -E
```

**Log Analysis:**

```bash
vagrant ssh gateway

# View gateway forwarding logs
sudo journalctl -k | grep GATEWAY_FWD | tail -20

# Monitor logs in real-time
sudo journalctl -kf | grep GATEWAY_FWD

# Generate traffic and watch logs (from another terminal)
vagrant ssh defender
ping -c 5 192.168.230.20
```

**Traffic Statistics:**

```bash
vagrant ssh gateway

# View nftables counters
sudo nft list ruleset | grep counter

# View interface statistics
ip -s link show
```

### Exercise 6: Troubleshooting Gateway Issues

**Create a connectivity test matrix:**

```bash
# From Defender (internal network)
vagrant ssh defender
echo "Testing from Defender (192.168.220.11):"
ping -c 1 192.168.220.5   # Gateway internal interface
ping -c 1 192.168.230.20  # Webserver (DMZ)
ping -c 1 192.168.210.10  # Attacker (external)

# From Webserver (DMZ)
vagrant ssh webserver
echo "Testing from Webserver (192.168.230.20):"
ping -c 1 192.168.230.5   # Gateway DMZ interface
ping -c 1 192.168.220.11  # Defender (internal)
ping -c 1 192.168.210.10  # Attacker (external)
```

**Traceroute Analysis:**

```bash
# From defender to attacker (crosses networks)
vagrant ssh defender
traceroute -n 192.168.210.10
# Should show: defender → gateway (192.168.220.5) → attacker (192.168.210.10)

# From webserver to defender (crosses networks)
vagrant ssh webserver
traceroute -n 192.168.220.11
# Should show: webserver → gateway (192.168.230.5) → defender (192.168.220.11)
```

**Common Issues and Solutions:**

| Issue | Check | Solution |
|-------|-------|----------|
| Ping fails across networks | `sysctl net.ipv4.ip_forward` | Enable: `sudo sysctl -w net.ipv4.ip_forward=1` |
| Can ping but can't access services | `sudo nft list chain inet filter forward` | Add FORWARD rule for specific port |
| NAT not working | `sudo nft list table ip nat` | Verify masquerading rules and interface names |
| Wrong interface in NAT rules | `ip addr show` | Check which interface has which IP |

### Exercise 7: Gateway Status Monitoring

Use the helper script to check overall gateway health:

```bash
vagrant ssh gateway
./gateway-config/status.sh
```

This script shows:
- IP forwarding status
- Network interfaces and IPs
- Routing table
- NAT rules
- FORWARD chain rules
- Active connection tracking (sample)

**Interpreting the output:**
- IP forwarding should be `1` (enabled)
- Should see 3 interfaces: eth1 (external .210.5), eth2 (internal .220.5), eth3 (DMZ .230.5)
- NAT postrouting rules should show masquerading for .220 and .230 networks
- FORWARD chain should allow traffic between networks

### Key Differences: Host vs Gateway Firewalls

```
┌─────────────────────────────────────────────────────┐
│             Host Firewall (Defender)                │
│                                                     │
│  INPUT chain:  Traffic TO defender                 │
│  OUTPUT chain: Traffic FROM defender               │
│  Scope:        Only protects defender VM           │
│  Use case:     Protect individual server           │
│                                                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│           Gateway Firewall (Gateway VM)             │
│                                                     │
│  FORWARD chain: Traffic THROUGH gateway            │
│  Scope:         Protects entire network            │
│  Use case:      Network segmentation, perimeter    │
│  Example:       Filter defender→webserver traffic  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**When to use each:**
- **Host Firewall:** Always! Every server should have its own firewall (defense-in-depth)
- **Gateway Firewall:** When you want centralized control of traffic between network segments

**Best Practice:** Use BOTH! Gateway provides network-level protection, host firewalls provide server-specific protection. If an attacker bypasses the gateway (or compromises it), host firewalls are your second line of defense.

### Additional Resources

For more advanced gateway topics, see:
- [Advanced Gateway and NAT Lab](../week01-network-basics/GATEWAY-LAB.md) - Comprehensive reference and hands-on exercises.
