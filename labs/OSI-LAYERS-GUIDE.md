# Understanding the OSI Model in DevSecOps Labs

## Introduction

The **OSI (Open Systems Interconnection) Model** is a conceptual framework that describes how network protocols and systems communicate. Understanding these layers is crucial for security professionals, as different security controls operate at different layers.

Throughout these labs, you'll work with security tools and concepts that operate at various OSI layers. This guide will help you understand which layer each technology operates at and why it matters.

## The Seven Layers

| Layer | Name | Function | Example Protocols | Lab Coverage |
|-------|------|----------|-------------------|--------------|
| **7** | Application | User applications and services | HTTP, HTTPS, FTP, DNS, SMTP | Week 3 (Proxies), Week 4 (DLP) |
| **6** | Presentation | Data translation, encryption, compression | SSL/TLS, JPEG, MPEG | Week 3 (SSL termination) |
| **5** | Session | Session management between applications | NetBIOS, RPC | Week 5 (SIEM session tracking) |
| **4** | Transport | End-to-end communication, reliability | TCP, UDP | Week 2 (Firewall rules), Week 3 (L4 proxies) |
| **3** | Network | Routing between networks | IP, ICMP, IPSec | Week 1 (Gateway), Week 2 (Firewalls) |
| **2** | Data Link | Node-to-node data transfer | Ethernet, MAC addresses | Week 1 (Network basics) |
| **1** | Physical | Physical transmission of bits | Cables, radio frequencies | Infrastructure setup |

## Why OSI Layers Matter for Security

### Defense in Depth

Security controls should be applied at **multiple layers** to provide defense in depth:

- **Layer 3-4 (Network/Transport)**: Firewalls block malicious IPs and ports
- **Layer 7 (Application)**: WAFs inspect HTTP requests for SQL injection
- **Layer 7 (Application)**: Proxies can cache, authenticate, and filter content

If an attacker bypasses one layer, other layers can still protect you.

### Different Threats at Different Layers

| Layer | Threats | Security Controls (Labs) |
|-------|---------|--------------------------|
| **Layer 7** | SQL injection, XSS, malware downloads | Application proxies (Week 3), DLP (Week 4) |
| **Layer 4** | Port scanning, SYN floods | Stateful firewalls (Week 2) |
| **Layer 3** | IP spoofing, routing attacks | Gateway firewalls (Week 2), NAT (Week 1) |
| **Layer 2** | ARP spoofing, MAC flooding | Network segmentation (Week 1) |

## Layer 4 vs Layer 7: A Critical Distinction

This is the most important distinction for this course:

### Layer 4 (Transport Layer)

**What it sees:**
- Source IP and port
- Destination IP and port
- Protocol (TCP/UDP)
- Connection state

**What it CANNOT see:**
- URLs or paths
- HTTP headers
- Request content
- Application-level data

**Examples:**
```
✓ Can see: 192.168.1.10:45678 → 192.168.1.20:80 (TCP)
✗ Cannot see: GET /admin/delete-user?id=5
```

**Use cases:**
- Fast routing decisions
- Port-based filtering
- TCP load balancing
- Low overhead

### Layer 7 (Application Layer)

**What it sees:**
- Everything Layer 4 sees, PLUS:
- Full HTTP request (method, URL, headers, body)
- Cookies and session data
- Application-specific data

**Examples:**
```
✓ Can see: GET /api/users HTTP/1.1
✓ Can see: Host: api.example.com
✓ Can see: Cookie: session=abc123
✓ Can see: User-Agent: curl/7.68.0
```

**Use cases:**
- Content-based routing
- URL filtering
- Authentication/authorization
- Caching
- SSL termination

## OSI Layers in Our Labs

### Week 1: Network Basics (Layers 2-3)

**Focus**: Understanding how networks communicate

- **Layer 2**: MAC addresses, switches, local network
- **Layer 3**: IP addresses, routing, gateways

**Key concepts:**
- IP addressing and subnetting
- Routing tables
- Gateway configuration

### Week 2: Firewalls (Layers 3-4)

**Focus**: Network and transport layer security

#### Layer 3 Firewall Rules (IP-based)
```bash
# Block entire subnet
nft add rule inet filter input ip saddr 192.168.1.0/24 drop
```

#### Layer 4 Firewall Rules (Port-based)
```bash
# Block specific port
nft add rule inet filter input tcp dport 23 drop

# Allow SSH only
nft add rule inet filter input tcp dport 22 accept
```

**Key concepts:**
- Stateful vs stateless filtering
- Port-based access control
- Connection tracking
- NAT (Network Address Translation)

### Week 3: Proxies (Layers 4 & 7)

**Focus**: Understanding the difference between L4 and L7 proxies

#### Layer 4 Proxies (TCP/UDP Proxies)
- Forward TCP/UDP connections
- No understanding of HTTP
- Fast but limited functionality
- Example: HAProxy in TCP mode

```
Client → L4 Proxy (just forwards bytes) → Server
```

#### Layer 7 Proxies (HTTP/Application Proxies)
- Understand HTTP protocol
- Can inspect and modify requests
- Can cache responses
- Can route based on URL/headers
- Example: Squid, Nginx, HAProxy in HTTP mode

```
Client → L7 Proxy (terminates HTTP, inspects, modifies) → Server
```

**Key distinction:**
```bash
# L4 proxy: Can route traffic to port 80
# but CANNOT route /api/* to server1 and /web/* to server2

# L7 proxy: Can route based on URL path
location /api/ { proxy_pass http://api-server; }
location /web/ { proxy_pass http://web-server; }
```

### Week 4: DLP (Layer 7)

**Focus**: Application-level content inspection

- Scanning code repositories for secrets
- Inspecting commit messages
- Pattern matching in application data

**Why Layer 7?**
- Need to understand file formats (JSON, YAML, code)
- Need to parse and interpret content
- Can't be done at lower layers

### Week 5: SIEM (Layers 3-7)

**Focus**: Aggregating logs from all layers

- Network flow logs (L3-4)
- Firewall logs (L3-4)
- Proxy logs (L7)
- Application logs (L7)

**Key concept:**
- Correlation across layers
- A Layer 7 attack may show Layer 4 anomalies first

### Week 6: EDR (Layer 7 and above)

**Focus**: Endpoint security, system calls, process behavior

- Beyond network layers
- Monitors OS and application behavior
- Detects malicious processes

## Practical Examples from Labs

### Example 1: Blocking vs Filtering

**Layer 3 Firewall (Week 2):**
```bash
# Block ALL traffic from attacker IP
sudo nft add rule inet filter input ip saddr 192.168.210.10 drop
```
- Simple, fast, but blunt
- Blocks legitimate traffic too

**Layer 7 Proxy (Week 3):**
```bash
# Block only malicious URLs from attacker
location /admin { deny 192.168.210.10; allow all; }
```
- Granular, surgical
- Allows legitimate traffic through

### Example 2: Load Balancing

**Layer 4 Load Balancing:**
```
# HAProxy TCP mode - distributes based on connections
frontend tcp_front
    mode tcp
    balance roundrobin
    server web1 192.168.1.10:80
    server web2 192.168.1.11:80
```
- Fast, efficient
- Can't route based on URL

**Layer 7 Load Balancing:**
```
# HAProxy HTTP mode - distributes based on URL
frontend http_front
    mode http
    acl is_api path_beg /api
    acl is_static path_beg /static
    use_backend api_servers if is_api
    use_backend static_servers if is_static
```
- Intelligent routing
- Can cache, modify headers, etc.

### Example 3: SSL/TLS

**Where does SSL/TLS operate?**

SSL/TLS spans multiple layers:
- **Layer 6 (Presentation)**: Encryption/decryption of data
- **Layer 7 (Application)**: Application data (HTTP, etc.)

**SSL Termination at Proxy (Week 3):**
```
Client ─[HTTPS]─> Proxy ─[HTTP]─> Backend
       (Layer 6/7)      (Layer 7)
```

Benefits:
- Backend doesn't need SSL
- Proxy can inspect traffic
- Centralized certificate management

## Common Misconceptions

### ❌ Misconception 1: "Firewalls are Layer 7"

**Reality**: Most firewalls operate at Layers 3-4
- They see IPs and ports
- They don't understand HTTP

**Exception**: Next-generation firewalls (NGFWs) can do Layer 7 inspection, but that's a special feature.

### ❌ Misconception 2: "All proxies are Layer 7"

**Reality**: Proxies can operate at different layers
- **L4 Proxy**: TCP/UDP proxy (just forwards bytes)
- **L7 Proxy**: HTTP proxy (understands application protocol)

### ❌ Misconception 3: "Higher layers are always better"

**Reality**: Each layer has trade-offs
- **L4**: Fast, low overhead, simple
- **L7**: Flexible, powerful, but slower and more complex

## Quick Reference Table

| Task | Best Layer | Tool (from Labs) | Week |
|------|-----------|------------------|------|
| Block an IP | Layer 3-4 | Firewall | Week 2 |
| Block a URL | Layer 7 | Proxy | Week 3 |
| Cache web content | Layer 7 | Squid | Week 3 |
| Load balance TCP | Layer 4 | HAProxy (TCP mode) | Week 3 |
| Load balance HTTP with URL routing | Layer 7 | HAProxy (HTTP mode) | Week 3 |
| Scan for secrets in code | Layer 7+ | Gitleaks | Week 4 |
| Aggregate logs | All layers | ELK Stack | Week 5 |
| Detect malware execution | Beyond OSI | Falco | Week 6 |

## Summary

Understanding OSI layers helps you:

1. **Choose the right tool**: Need to block IPs? Layer 3-4 firewall. Need to block URLs? Layer 7 proxy.

2. **Understand limitations**: A Layer 4 firewall cannot block `/admin` - it doesn't see URLs.

3. **Design defense in depth**: Layer attacks at Layer 3, 4, and 7 simultaneously.

4. **Troubleshoot effectively**: Is the problem at the network layer (can't ping) or application layer (HTTP 500 error)?

5. **Optimize performance**: Layer 4 is faster; Layer 7 is more powerful. Choose based on your needs.

## What's Next?

As you progress through the labs:

- **Week 1-2**: Build your Layer 3-4 foundation (networking, firewalls)
- **Week 3**: Master Layer 4 vs Layer 7 proxies
- **Week 4-6**: Apply security at all layers

Remember: **The best security comes from protecting at multiple layers!**
