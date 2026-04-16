# Week 3 – Proxy Lab

## Objectives

- Configure a simple reverse proxy with Nginx
- Experiment with a forward proxy using Squid
- Understand logging and header forwarding basics
- Build hardened proxy pipelines with caching, auth, and fault-injection drills
- Configure High Availability (HA) proxies with load balancing and health checks
- Test proxy configurations in multi-VM environment
- Simulate attacks through proxies and implement defenses
- Build real-world proxy architectures
- Understand the difference between proxies and gateways

## Estimated Time

⏱️ **3-3.5 hours** (including VM setup and all exercises)

This lab includes:
- VM setup and verification (~10-15 minutes)
- Forward proxy (Squid) configuration (~30-40 minutes)
- Reverse proxy (Nginx) setup (~30-40 minutes)
- High Availability (HA) proxy configuration (~40-50 minutes)
- Advanced hardening and attack scenarios (~30-40 minutes)

**Tip:** Log analysis exercises can be done asynchronously while testing different configurations.

## Understanding OSI Layers and Proxies

> **📚 New**: For a comprehensive introduction to OSI layers, see [OSI Layers Guide](../OSI-LAYERS-GUIDE.md)

### Gateway vs Proxy (Layer 3-4 vs Layer 7)

Before starting, it's important to understand how proxies differ from gateways:

| Aspect | Gateway (Layer 3-4) | Layer 4 Proxy | Layer 7 Proxy |
|--------|---------------------|---------------|---------------|
| **OSI Layer** | Network/Transport | Transport | Application |
| **Transparency** | Transparent routing | Transparent TCP/UDP | Can be explicit or transparent |
| **Protocol Knowledge** | IP, TCP, UDP | TCP/UDP connections | HTTP, HTTPS, FTP, etc. |
| **Content Inspection** | Limited (ports/IPs) | Connection state only | Full (reads URLs, headers, content) |
| **Caching** | No | No | Yes |
| **Client Config** | None (routing-based) | None (transparent) | May require proxy settings |
| **Use Case** | Network routing, NAT | TCP load balancing | Application filtering, caching, auth |
| **Performance** | Fastest | Very fast | Slower (deeper inspection) |

### Layer 4 vs Layer 7 Proxies: The Critical Distinction

This is one of the most important concepts in this lab.

#### Layer 4 Proxy (Transport Layer)

**What it does:**
- Forwards TCP/UDP packets
- Makes decisions based on IP addresses and ports
- Maintains connection state
- No understanding of application protocol

**Example: TCP Load Balancer**
```
Client → L4 Proxy → Backend Server
         (sees: 192.168.1.10:45678 → 192.168.1.20:80)
         (cannot see: GET /api/users)
```

**Use cases:**
- Fast TCP/UDP load balancing
- Non-HTTP protocols (databases, SSH, etc.)
- When you don't need to inspect content
- Lowest latency requirements

**Limitations:**
- ❌ Cannot route based on URL path
- ❌ Cannot cache responses
- ❌ Cannot modify headers
- ❌ Cannot authenticate users based on content

#### Layer 7 Proxy (Application Layer)

**What it does:**
- Terminates and re-originates connections
- Understands application protocol (HTTP, etc.)
- Can inspect and modify content
- Can cache, authenticate, route based on content

**Example: HTTP Reverse Proxy**
```
Client → L7 Proxy → Backend Server
         (sees: GET /api/users HTTP/1.1)
         (sees: Host: api.example.com)
         (sees: Cookie: session=abc123)
         (can route /api/* to server1, /web/* to server2)
```

**Use cases:**
- Content-based routing (URL, headers)
- Caching web content
- SSL termination
- Authentication/authorization
- Header manipulation
- Security filtering (WAF)

**Advantages:**
- ✅ Route based on URL: `/api` → api-server, `/static` → cdn
- ✅ Cache responses
- ✅ Modify headers (add security headers, remove sensitive info)
- ✅ Authenticate users
- ✅ Block malicious requests

**Trade-offs:**
- ⚠️ Higher latency (more processing)
- ⚠️ More CPU/memory usage
- ⚠️ More complex configuration

### When to Use Each Type?

| Scenario | Use Layer 4 | Use Layer 7 | Reason |
|----------|-------------|-------------|---------|
| Load balance HTTP across 3 web servers (simple) | ✅ | ✅ | Both work, L4 is faster |
| Route `/api/*` to API servers, `/web/*` to web servers | ❌ | ✅ | Need URL inspection |
| Load balance MySQL database | ✅ | ❌ | Non-HTTP protocol |
| Cache web pages | ❌ | ✅ | Need to understand HTTP |
| SSL termination | ❌ | ✅ | Need to decrypt/inspect |
| Add security headers to responses | ❌ | ✅ | Need to modify HTTP |
| Lowest possible latency | ✅ | ❌ | L4 is faster |
| Block requests to `/admin` from certain IPs | ❌ | ✅ | Need URL inspection |

### Real-World Example

**Scenario**: You have an application with:
- Web frontend on `/`
- API on `/api`
- Admin panel on `/admin`
- Static files on `/static`

**Layer 4 Approach (Limited):**
```
All traffic goes to same backend pool
Cannot route based on URL
```

**Layer 7 Approach (Powerful):**
```
/ → web-servers (cache enabled)
/api → api-servers (no cache, health checks)
/admin → admin-servers (IP whitelist, extra security)
/static → cdn-servers (aggressive caching)
```

### In This Lab

You'll work with both:
- **Squid & Nginx**: Pure Layer 7 proxies (HTTP/HTTPS only)
- **HAProxy**: Can operate at Layer 4 (TCP mode) OR Layer 7 (HTTP mode)

This flexibility makes HAProxy powerful for production environments.

For more on gateways, see [Gateway and NAT Guide](../week01-network-basics/GATEWAY-LAB.md).

## VM Setup for This Lab

### Basic Exercises (Tasks 1-2): Squid and Nginx

Start the required VMs:
```bash
cd /path/to/devops-tutorial
vagrant up attacker proxy webserver
```

**VM Roles:**
- **proxy** (192.168.210.21) - Configure Squid and Nginx here
- **attacker** (192.168.210.10) - Client making requests through proxies
- **webserver** (192.168.230.20) - Backend web application

### Advanced HAProxy Exercises (Task 3+): Load Balancing

For production-grade HAProxy exercises, you'll need additional backend servers:

```bash
# Start with basic VMs
vagrant up attacker proxy webserver

# For HAProxy exercises, halt basic VMs and start backend pool
vagrant halt webserver
vagrant up web1 web2 web3
```

**Additional VMs for HAProxy:**
- **web1** (192.168.230.31) - Backend server #1 for load balancing
- **web2** (192.168.230.32) - Backend server #2 for load balancing
- **web3** (192.168.230.33) - Backend server #3 for load balancing

**Resource Management:**
- Basic exercises: 3 VMs (~3.5 GB RAM)
- HAProxy exercises: 5 VMs (~4 GB RAM - proxy, attacker, web1, web2, web3)
- Use `vagrant halt` and `vagrant up` to swap VM sets as needed

**Lab Flow:**
1. Configure proxies on **proxy** VM
2. Send requests from **attacker**
3. Backend servers (**webserver** or **web1/2/3**) serve responses
4. Monitor logs on **proxy** to observe traffic

See [VM Setup Guide](../../VM-SETUP.md) for detailed instructions.

## Tasks

### 1. Multi-VM Forward Proxy Setup (Squid)

**Set up and test forward proxy across VMs:**

> **Note:** The proxy VM is intentionally NOT pre-configured. You will configure Squid manually as part of this hands-on exercise to better understand how forward proxies work.

1. On proxy VM, configure Squid:

   ```bash
   vagrant ssh proxy
   
   # Check the configuration directory and helper scripts
   ls -la ~/proxy-config/
   cat ~/proxy-config/README.txt
   
   # Review the example Squid configuration
   cat /etc/squid/squid.conf.example
   
   # Apply the Squid configuration using the helper script
   cd ~/proxy-config
   ./configure-squid.sh
   
   # Or configure manually:
   # sudo cp /etc/squid/squid.conf.example /etc/squid/squid.conf
   # sudo systemctl enable squid
   # sudo systemctl start squid
   
   # Verify Squid is running
   sudo systemctl status squid
   
   # View Squid configuration
   cat /etc/squid/squid.conf
   
   # Tail logs
   sudo tail -f /var/log/squid/access.log
   ```

2. From attacker VM, test forward proxy:

   ```bash
   vagrant ssh attacker
   
   # Test without proxy (direct connection)
   curl -I http://192.168.230.20
   
   # Test with proxy (through Squid)
   curl -I -x http://192.168.210.21:3128 http://192.168.230.20
   
   # Test external site through proxy (if internet enabled)
   curl -I -x http://192.168.210.21:3128 http://example.com
   ```

   Expected: Requests go through proxy, logs appear in Squid access.log showing `TCP_MISS/200` or `TCP_HIT/200`.

3. Monitor proxy logs in real-time:

   ```bash
   # On proxy VM
   vagrant ssh proxy
   sudo tail -f /var/log/squid/access.log
   
   # While on attacker, generate traffic:
   # vagrant ssh attacker
   # for i in {1..5}; do curl -x http://192.168.210.21:3128 http://192.168.230.20; sleep 1; done
   ```

   Analyze the log format:
   - Timestamp
   - Client IP (192.168.210.10)
   - Cache status (TCP_MISS, TCP_HIT)
   - Response code
   - URL requested

4. **Attack Scenario: Proxy Bypass Attempt**

   From attacker, try to bypass proxy restrictions:
   ```bash
   vagrant ssh attacker
   
   # Try accessing proxy admin interface
   curl -x http://192.168.210.21:3128 http://192.168.210.21:3128
   
   # Try HTTP CONNECT to arbitrary port
   curl -x http://192.168.210.21:3128 --proxytunnel http://192.168.230.20:22
   ```

   Expected: Squid blocks non-safe ports. Check logs for `CONNECT` method denials.

5. **Advanced Proxy Traffic Monitoring**

   Monitoring proxy traffic requires different techniques than direct packet capture since the proxy terminates and re-originates connections:

   **Monitor Bandwidth Through Proxy:**
   ```bash
   vagrant ssh proxy
   
   # Install monitoring tools
   sudo apt install -y iftop nload
   
   # Monitor interface serving clients (eth1)
   sudo iftop -i eth1 -P -f "port 3128"
   
   # Simple bandwidth graph
   sudo nload -u M eth1
   ```

   **Analyze Squid Logs with Better Tools:**
   ```bash
   vagrant ssh proxy
   
   # Real-time log parsing with colors for better readability
   sudo tail -f /var/log/squid/access.log | \
     awk 'BEGIN {
       GREEN="\033[32m"; YELLOW="\033[33m"; RED="\033[31m"; RESET="\033[0m";
     }
     {
       if ($4 ~ /TCP_HIT/) print GREEN $0 RESET;      # Green for cache hits
       else if ($4 ~ /TCP_MISS/) print YELLOW $0 RESET; # Yellow for misses
       else if ($4 ~ /DENIED/) print RED $0 RESET;      # Red for denials
       else print $0;
     }'
   
   # Generate statistics from logs
   echo "=== Squid Statistics ==="
   echo "Total requests: $(wc -l < /var/log/squid/access.log)"
   echo "Cache hits: $(grep -c TCP_HIT /var/log/squid/access.log)"
   echo "Cache misses: $(grep -c TCP_MISS /var/log/squid/access.log)"
   echo "Denied requests: $(grep -c DENIED /var/log/squid/access.log)"
   
   # Top requested domains
   echo "=== Top 10 Requested Domains ==="
   awk '{print $7}' /var/log/squid/access.log | \
     cut -d'/' -f3 | \
     sort | uniq -c | sort -rn | head -10
   
   # Top client IPs
   echo "=== Top Client IPs ==="
   awk '{print $3}' /var/log/squid/access.log | \
     sort | uniq -c | sort -rn | head -10
   ```

   **Capture and Analyze Proxy Traffic:**
   ```bash
   vagrant ssh proxy
   
   # Install tshark for packet analysis
   sudo apt install -y tshark
   
   # Capture traffic on both sides of proxy
   # Client side (incoming)
   sudo tcpdump -i eth1 -w /tmp/proxy-client.pcap 'port 3128' &
   CLIENT_PID=$!  # Save PID for clean termination
   
   # Server side (outgoing)
   sudo tcpdump -i eth1 -w /tmp/proxy-server.pcap 'port 80 or port 443' &
   SERVER_PID=$!  # Save PID for clean termination
   
   # Generate some traffic from attacker
   # vagrant ssh attacker
   # for i in {1..10}; do curl -x http://192.168.210.21:3128 http://192.168.230.20; done
   
   # Stop captures using specific PIDs
   sudo kill -TERM $CLIENT_PID $SERVER_PID
   sleep 2
   
   # Compare traffic patterns
   echo "=== Client-side Traffic ==="
   tshark -r /tmp/proxy-client.pcap -q -z io,phs
   
   echo "=== Server-side Traffic ==="
   tshark -r /tmp/proxy-server.pcap -q -z io,phs
   
   # See how proxy modifies headers
   echo "=== Original Client Request ==="
   tshark -r /tmp/proxy-client.pcap -Y "http.request" -T fields -e http.user_agent
   
   echo "=== Proxy-Modified Request ==="
   tshark -r /tmp/proxy-server.pcap -Y "http.request" -T fields -e http.user_agent -e http.x_forwarded_for
   ```

   **Detection: Identifying Proxy Abuse:**
   ```bash
   # Watch for suspicious patterns in real-time
   vagrant ssh proxy
   
   # Detect rapid requests (possible scanning)
   tail -f /var/log/squid/access.log | \
     awk '{print $1, $3}' | \
     uniq -c | \
     awk '$1 > 10 {print "⚠️  Rapid requests from", $3, ":", $1, "requests/sec"}'
   
   # Detect CONNECT method abuse
   grep CONNECT /var/log/squid/access.log | \
     awk '{print $3, $7}' | \
     sort | uniq -c | sort -rn
   
   # Detect unusual user agents
   grep -oP 'User-Agent: \K[^"]+' /var/log/squid/access.log | \
     sort | uniq -c | sort -rn
   ```

   **Why Proxy Monitoring is Different:**
   - Proxies break end-to-end visibility - you see two connections, not one
   - Cache hits don't generate backend traffic - monitor both logs and packets
   - Headers are modified - `X-Forwarded-For` added, `User-Agent` may change
   - Connection pooling means fewer connections than requests
   - SSL/TLS proxies (CONNECT) are opaque - you only see CONNECT, not content

### 2. Multi-VM Reverse Proxy Setup (Nginx)

**Configure Nginx on proxy VM to serve backend from webserver:**

> **Note:** Like Squid, Nginx reverse proxy is not pre-configured. You'll set it up manually to learn how reverse proxies work.

1. On proxy VM, configure reverse proxy:

   ```bash
   vagrant ssh proxy
   
   # Review the example Nginx reverse proxy configuration
   cat /etc/nginx/sites-available/reverse-proxy.example
   
   # Apply the Nginx configuration using the helper script
   cd ~/proxy-config
   ./configure-nginx.sh
   
   # Or configure manually:
   # sudo cp /etc/nginx/sites-available/reverse-proxy.example /etc/nginx/sites-available/reverse-proxy
   # sudo ln -sf /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/
   # sudo nginx -t
   # sudo systemctl reload nginx
   
   # Alternatively, create your own configuration:
   # sudo tee /etc/nginx/sites-available/reverse-proxy <<'EOF'
   # server {
   #     listen 8080;
   #     server_name _;
   #     
   #     access_log /var/log/nginx/reverse-proxy-access.log;
   #     error_log /var/log/nginx/reverse-proxy-error.log;
   #     
   #     location / {
   #         proxy_pass http://192.168.230.20;
   #         proxy_set_header Host $host;
   #         proxy_set_header X-Real-IP $remote_addr;
   #         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
   #         proxy_set_header X-Forwarded-Proto $scheme;
   #         
   #         # Log proxy details
   #         add_header X-Proxy-Server "lab-proxy" always;
   #     }
   #     
   #     location /admin {
   #         # Restrict admin to defender only
   #         allow 192.168.220.11;
   #         deny all;
   #         
   #         proxy_pass http://192.168.230.20/admin;
   #     }
   # }
   # EOF
   # 
   # # Enable the site
   # sudo ln -sf /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/
   # sudo nginx -t
   # sudo systemctl reload nginx
   ```

2. From attacker, test reverse proxy:

   ```bash
   vagrant ssh attacker
   
   # Access through reverse proxy
   curl -I http://192.168.210.21:8080
   
   # Should see X-Proxy-Server header
   curl -v http://192.168.210.21:8080 2>&1 | grep X-Proxy-Server
   
   # Try accessing admin (should be denied)
   curl http://192.168.210.21:8080/admin
   ```

   Expected:
   - Public endpoints work through proxy
   - Admin endpoint returns `403 Forbidden` from attacker
   - Headers show proxy information

3. From defender VM (if started), test admin access:

   ```bash
   vagrant up defender  # If not already running
   vagrant ssh defender
   
   # This should work (IP whitelisted)
   curl http://192.168.210.21:8080/admin
   ```

4. **Attack Scenario: Header Injection Attempt**

   From attacker, try header injection:
   ```bash
   vagrant ssh attacker
   
   # Try to spoof X-Real-IP
   curl -H "X-Real-IP: 192.168.220.11" http://192.168.210.21:8080/admin
   
   # Try to inject X-Forwarded-For
   curl -H "X-Forwarded-For: 192.168.220.11" http://192.168.210.21:8080/admin
   ```

   Expected: Still denied because Nginx overwrites these headers. This shows importance of proxy configuration.

5. **Monitor Nginx Reverse Proxy Logs**

   After configuring and testing the reverse proxy, you can monitor its logs:

   ```bash
   vagrant ssh proxy
   
   # Real-time log monitoring with GoAccess (if available)
   sudo apt install -y goaccess
   
   # Analyze Nginx logs interactively
   sudo goaccess /var/log/nginx/reverse-proxy-access.log -o report.html --log-format=COMBINED
   
   # Or use awk for quick stats
   echo "=== Nginx Reverse Proxy Stats ==="
   awk '{print $9}' /var/log/nginx/reverse-proxy-access.log | sort | uniq -c | sort -rn
   
   # Response time analysis (if logging $request_time)
   awk '{print $NF}' /var/log/nginx/reverse-proxy-access.log | \
     awk '{sum+=$1; count++} END {print "Avg response time:", sum/count, "seconds"}'
   ```
   
   **Note:** These commands require that the reverse proxy has been configured and has handled some traffic. If the log files don't exist, configure the reverse proxy first using `./configure-nginx.sh`, then generate some traffic by accessing `http://192.168.210.21:8080` from the attacker VM.

### 3. High Availability (HA) Proxies

High Availability proxies ensure continuous service availability by distributing traffic across multiple backend servers, providing load balancing, health checking, and failover capabilities.

#### Understanding HA Proxies

**What is an HA Proxy?**

An HA (High Availability) proxy is a specialized load balancer that:
- Distributes traffic across multiple backend servers
- Monitors backend health and removes failed servers from the pool
- Provides automatic failover when backends become unavailable
- Ensures no single point of failure in your architecture

**Why Use HA Proxies?**

1. **High Availability**: Service continues even if one or more backends fail
2. **Load Distribution**: Spreads traffic to prevent any single server from being overwhelmed
3. **Scalability**: Add or remove backends without service interruption
4. **Performance**: Reduces response times by balancing load efficiently
5. **Maintenance**: Update servers without downtime (rolling updates)

**Common HA Proxy Solutions:**

| Solution | Type | Key Features | Best For |
|----------|------|--------------|----------|
| **HAProxy** | Dedicated LB | High performance, TCP/HTTP, ACLs | Production load balancing |
| **Nginx (upstream)** | Web server + LB | HTTP/HTTPS, caching, SSL termination | Web applications |
| **Traefik** | Modern LB | Auto-discovery, Docker/K8s native | Microservices |
| **Envoy** | Service mesh | Advanced routing, gRPC, observability | Cloud-native apps |

#### HA Proxy Concepts

**Load Balancing Algorithms:**

1. **Round Robin**: Distributes requests evenly across all backends (default)
   - Use when: All backends have similar capacity
   
2. **Least Connections**: Sends traffic to server with fewest active connections
   - Use when: Request processing times vary significantly
   
3. **IP Hash**: Maps client IP to specific backend (session persistence)
   - Use when: Sessions must stick to same backend
   
4. **Weighted**: Assigns different weights to backends based on capacity
   - Use when: Backends have different specifications

**Health Checks:**

- **Active**: Proxy periodically sends requests to check backend health
- **Passive**: Proxy monitors real traffic to detect failures
- **HTTP**: Check for specific status codes (200, 301, etc.)
- **TCP**: Verify port is accepting connections
- **Custom**: Run scripts or check specific endpoints

#### Exercise 3.1: Configure HAProxy for Load Balancing

In this exercise, we'll simulate a simple HA proxy setup using Nginx's upstream module (simpler than installing HAProxy for the lab).

**Scenario**: Load balance traffic between webserver and a second backend (simulated).

1. On proxy VM, install and configure Nginx for HA:

   ```bash
   vagrant ssh proxy
   
   # Install nginx-full for upstream module
   sudo apt update
   sudo apt install -y nginx-full
   
   # Create HA proxy configuration
   sudo tee /etc/nginx/sites-available/ha-proxy <<'EOF'
   # Define backend server pool
   upstream backend_pool {
       # Load balancing method (default: round-robin)
       # Other options: least_conn, ip_hash, random
       
       # Backend servers
       server 192.168.230.20:80 weight=1 max_fails=3 fail_timeout=30s;
       
       # Simulated second backend (will fail health check)
       server 192.168.230.20:8081 weight=1 max_fails=3 fail_timeout=30s backup;
       
       # Health check interval
       keepalive 32;
   }
   
   server {
       listen 9090;
       server_name _;
       
       access_log /var/log/nginx/ha-proxy-access.log;
       error_log /var/log/nginx/ha-proxy-error.log;
       
       location / {
           proxy_pass http://backend_pool;
           
           # Headers for backend
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           
           # Health check settings
           proxy_next_upstream error timeout http_500 http_502 http_503;
           proxy_next_upstream_tries 2;
           proxy_next_upstream_timeout 10s;
           
           # Connection settings
           proxy_connect_timeout 5s;
           proxy_send_timeout 10s;
           proxy_read_timeout 10s;
           
           # Add header showing which backend served the request
           add_header X-Backend-Server $upstream_addr always;
           add_header X-Response-Time $upstream_response_time always;
       }
       
       # Health check endpoint
       location /health {
           access_log off;
           return 200 "HA Proxy Healthy\n";
           add_header Content-Type text/plain;
       }
   }
   EOF
   
   # Enable the site
   sudo ln -sf /etc/nginx/sites-available/ha-proxy /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

2. Test the HA proxy from attacker:

   ```bash
   vagrant ssh attacker
   
   # Test load balancer
   for i in {1..10}; do 
     curl -s http://192.168.210.21:9090 | head -1
     sleep 0.5
   done
   
   # Check which backend served each request
   for i in {1..5}; do 
     curl -I http://192.168.210.21:9090 2>&1 | grep "X-Backend-Server"
   done
   ```
   
   Expected output: All requests go to the primary backend (192.168.230.20:80) since the backup is offline.

3. Monitor backend pool status:

   ```bash
   vagrant ssh proxy
   
   # Check Nginx status (requires nginx-full with stub_status)
   sudo tee -a /etc/nginx/sites-available/ha-proxy <<'EOF'
   
   # Status page for monitoring
   server {
       listen 9091;
       location /nginx_status {
           stub_status on;
           access_log off;
           allow 192.168.210.0/24;
           deny all;
       }
   }
   EOF
   
   sudo nginx -t
   sudo systemctl reload nginx
   
   # View status
   curl http://localhost:9091/nginx_status
   
   # Watch logs for backend selection
   sudo tail -f /var/log/nginx/ha-proxy-access.log
   ```

#### Exercise 3.2: Advanced Load Balancing Strategies

1. **Least Connections Load Balancing**:

   ```bash
   vagrant ssh proxy
   
   # Update upstream configuration
   sudo tee /etc/nginx/sites-available/ha-proxy-leastconn <<'EOF'
   upstream backend_pool {
       least_conn;  # Use least connections algorithm
       
       server 192.168.230.20:80 weight=2;  # Higher weight = more traffic
       server 192.168.230.20:8081 weight=1 backup;
       
       keepalive 32;
   }
   
   server {
       listen 9092;
       server_name _;
       
       access_log /var/log/nginx/ha-leastconn-access.log;
       
       location / {
           proxy_pass http://backend_pool;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           
           add_header X-Backend-Server $upstream_addr always;
       }
   }
   EOF
   
   sudo ln -sf /etc/nginx/sites-available/ha-proxy-leastconn /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

2. **Session Persistence (IP Hash)**:

   ```bash
   vagrant ssh proxy
   
   # Update for session persistence
   sudo tee /etc/nginx/sites-available/ha-proxy-iphash <<'EOF'
   upstream backend_pool {
       ip_hash;  # Session persistence based on client IP
       
       server 192.168.230.20:80;
       server 192.168.230.20:8081 backup;
   }
   
   server {
       listen 9093;
       server_name _;
       
       access_log /var/log/nginx/ha-iphash-access.log;
       
       location / {
           proxy_pass http://backend_pool;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           
           add_header X-Backend-Server $upstream_addr always;
       }
   }
   EOF
   
   sudo ln -sf /etc/nginx/sites-available/ha-proxy-iphash /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

3. Test session persistence from attacker:

   ```bash
   vagrant ssh attacker
   
   # All requests from same IP should go to same backend
   for i in {1..10}; do 
     curl -s http://192.168.210.21:9093 -I 2>&1 | grep "X-Backend-Server"
   done
   
   # All should show the SAME backend server
   ```

#### Exercise 3.3: Health Checks and Failover

1. **Configure active health checks**:

   ```bash
   vagrant ssh proxy
   
   # Create a more robust health check configuration
   sudo tee /etc/nginx/sites-available/ha-proxy-healthcheck <<'EOF'
   upstream backend_pool {
       server 192.168.230.20:80 max_fails=2 fail_timeout=10s;
       server 192.168.230.20:8081 backup;
       
       keepalive 32;
   }
   
   server {
       listen 9094;
       server_name _;
       
       access_log /var/log/nginx/ha-healthcheck-access.log;
       error_log /var/log/nginx/ha-healthcheck-error.log notice;
       
       location / {
           proxy_pass http://backend_pool;
           proxy_set_header Host $host;
           
           # Advanced failure handling
           proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
           proxy_next_upstream_tries 3;
           
           add_header X-Backend-Server $upstream_addr always;
           add_header X-Upstream-Status $upstream_status always;
       }
   }
   EOF
   
   sudo ln -sf /etc/nginx/sites-available/ha-proxy-healthcheck /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl reload nginx
   ```

2. **Simulate backend failure**:

   ```bash
   # On attacker, generate steady traffic
   vagrant ssh attacker
   
   while true; do
     curl -s http://192.168.210.21:9094 -I | grep -E "HTTP|X-Backend"
     sleep 1
   done
   ```
   
   In another terminal, simulate webserver failure:
   
   ```bash
   vagrant ssh webserver
   
   # Stop nginx temporarily
   sudo systemctl stop nginx
   
   # Wait 30 seconds, then restart
   sleep 30
   sudo systemctl start nginx
   ```
   
   Expected: Traffic should fail over gracefully. Nginx marks the backend as down after 2 failures and stops sending traffic.

3. **Monitor failover in logs**:

   ```bash
   vagrant ssh proxy
   
   # Watch for upstream failures
   sudo tail -f /var/log/nginx/ha-healthcheck-error.log | grep -E "upstream|failed"
   
   # Check access logs for backend switching
   sudo tail -f /var/log/nginx/ha-healthcheck-access.log
   ```

#### Exercise 3.4: HA Proxy with Real HAProxy Software

For production scenarios, dedicated HAProxy provides more features. Here's a quick setup:

1. Install HAProxy on proxy VM:

   ```bash
   vagrant ssh proxy
   
   sudo apt update
   sudo apt install -y haproxy
   
   # Backup original config
   sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
   ```

2. Configure HAProxy:

   ```bash
   sudo tee /etc/haproxy/haproxy.cfg <<'EOF'
   global
       log /dev/log local0
       log /dev/log local1 notice
       chroot /var/lib/haproxy
       stats socket /run/haproxy/admin.sock mode 660 level admin
       stats timeout 30s
       user haproxy
       group haproxy
       daemon
   
   defaults
       log     global
       mode    http
       option  httplog
       option  dontlognull
       timeout connect 5000
       timeout client  50000
       timeout server  50000
   
   # Statistics page
   listen stats
       bind *:8404
       stats enable
       stats uri /stats
       stats refresh 5s
       stats show-legends
       stats show-node
   
   # Frontend - where clients connect
   frontend http_front
       bind *:9095
       default_backend web_servers
       
       # Access control list examples
       acl is_admin path_beg /admin
       acl allowed_ips src 192.168.220.11
       
       # Deny admin access from non-allowed IPs
       http-request deny if is_admin !allowed_ips
   
   # Backend - pool of servers
   backend web_servers
       balance roundrobin
       option httpchk GET /
       
       # Backend servers
       server web1 192.168.230.20:80 check inter 2000 rise 2 fall 3
       # server web2 192.168.230.20:8081 check inter 2000 rise 2 fall 3 backup
   EOF
   
   # Test configuration
   sudo haproxy -c -f /etc/haproxy/haproxy.cfg
   
   # Restart HAProxy
   sudo systemctl restart haproxy
   sudo systemctl enable haproxy
   ```

3. Test HAProxy from attacker:

   ```bash
   vagrant ssh attacker
   
   # Test load balancer
   for i in {1..10}; do 
     curl -s http://192.168.210.21:9095 | head -1
   done
   
   # View HAProxy statistics page
   curl http://192.168.210.21:8404/stats
   
   # Or in browser: http://192.168.210.21:8404/stats
   ```

4. Monitor HAProxy stats:

   ```bash
   vagrant ssh proxy
   
   # View HAProxy logs
   sudo tail -f /var/log/haproxy.log
   
   # Check stats via socket
   echo "show stat" | sudo socat stdio /run/haproxy/admin.sock
   
   # Show backend status
   echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock
   ```

#### Understanding HA Proxy Architectures

**Single HA Proxy (Basic)**:
```
Client → HAProxy → [Backend1, Backend2, Backend3]
```
- Pros: Simple, centralized management
- Cons: HAProxy is single point of failure

**Dual HA Proxy with Keepalived (Production)**:
```
Client → VIP (Floating IP) → [HAProxy1 (Master), HAProxy2 (Backup)] → Backends
```
- Pros: No single point of failure, automatic failover
- Cons: More complex, requires shared VIP

**Geographic Distribution**:
```
Client → DNS → [HAProxy-US, HAProxy-EU, HAProxy-ASIA] → Regional Backends
```
- Pros: Low latency, geographic redundancy
- Cons: Complex DNS setup, data consistency challenges

**Key Considerations for HA Proxy Deployment**:

1. **Capacity Planning**: Each proxy can handle ~10,000-50,000 concurrent connections
2. **SSL Termination**: Proxies can decrypt SSL to inspect traffic (CPU intensive)
3. **Session Persistence**: Needed for stateful applications (cookies, IP hash)
4. **Health Checks**: Balance frequency vs backend load
5. **Failover Time**: Typically 1-5 seconds for detection + recovery
6. **Monitoring**: Essential for detecting backend degradation

#### HA Proxy Best Practices

1. **Always use health checks**: Don't send traffic to dead backends
2. **Set appropriate timeouts**: Prevent hung connections from consuming resources
3. **Monitor proxy health**: The proxy itself can fail
4. **Use connection limits**: Protect backends from overload
5. **Log everything**: Essential for debugging and capacity planning
6. **Test failover regularly**: Ensure your HA setup actually works
7. **Use backup servers**: For graceful degradation during maintenance
8. **Implement rate limiting**: Protect against abuse and DDoS

#### Troubleshooting HA Proxies

**Problem: All requests go to one backend**
```bash
# Check load balancing algorithm
sudo nginx -T | grep -A 5 "upstream backend_pool"

# Verify all backends are marked as up
echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock
```

**Problem: Backend marked as down but is actually healthy**
```bash
# Check health check configuration
sudo nginx -T | grep -E "max_fails|fail_timeout"

# Test backend directly
curl -I http://192.168.230.20:80

# Review error logs for health check failures
sudo tail -100 /var/log/nginx/error.log | grep upstream
```

**Problem: Slow failover during backend failure**
```bash
# Reduce fail_timeout and increase max_fails frequency
# In upstream block:
# server 192.168.230.20:80 max_fails=2 fail_timeout=5s;
```

**Problem: Session persistence not working**
```bash
# Verify ip_hash or cookie-based persistence is configured
sudo nginx -T | grep -E "ip_hash|sticky"

# Check X-Forwarded-For header is being set
curl -v http://192.168.210.21:9093
```

## Production-Grade HAProxy: Advanced Exercises

> **🎯 Goal**: Build production-ready load balancing infrastructure using HAProxy with multiple backend servers

### Exercise 4.1: Layer 4 vs Layer 7 HAProxy - Hands-On Comparison

This exercise demonstrates the critical difference between Layer 4 (TCP) and Layer 7 (HTTP) proxies.

#### Setup: Start Backend Servers

**Important**: For these exercises, we need multiple backend servers. Manage your VMs efficiently:

```bash
# First, halt VMs not needed for HAProxy exercises
vagrant halt webserver

# Start the backend server pool
vagrant up web1 web2 web3

# Verify they're running
vagrant status | grep web
```

#### Part A: Layer 4 TCP Proxy (Fast, Simple)

1. **Configure HAProxy in TCP mode:**

   ```bash
   vagrant ssh proxy
   
   sudo apt update && sudo apt install -y haproxy socat
   
   # Create Layer 4 configuration
   sudo tee /etc/haproxy/haproxy-l4.cfg <<'EOF'
   global
    log /dev/log local0
    maxconn 4096
    user haproxy
    group haproxy
    daemon
    
    # Performance tuning for L4
    tune.bufsize 32768
   defaults
    log     global
    mode    tcp                    # Layer 4 mode
    option  tcplog                 # TCP logging
    option  dontlognull
    timeout connect 5s
    timeout client  30s
    timeout server  30s
    
    # TCP-specific options
    option  tcp-smart-accept
    option  tcp-smart-connect
   
   # Statistics page (HTTP mode for stats only)
   listen stats
    bind *:8405
    mode http
    stats enable
    stats uri /stats
    stats refresh 5s
    stats show-legends
    stats admin if TRUE
   
   # Layer 4 TCP load balancer
   frontend tcp_frontend
    bind *:9096
    mode tcp
    default_backend tcp_backend
    
    # L4 can only log connections, not HTTP details
    log-format "%ci:%cp -> %fi:%fp [%t] %ft %b/%s %Tw/%Tc/%Tt %B %ts %ac/%fc/%bc/%sc/%rc %sq/%bq"
   
   backend tcp_backend
    mode tcp
    balance roundrobin            # Simple round-robin
    
    # Health check: just TCP connect
    option tcp-check
    
    # Backend servers
    server web1 192.168.230.31:80 check inter 2000 rise 2 fall 3
    server web2 192.168.230.32:80 check inter 2000 rise 2 fall 3
    server web3 192.168.230.33:80 check inter 2000 rise 2 fall 3
EOF
   
   # Test configuration
   sudo haproxy -c -f /etc/haproxy/haproxy-l4.cfg
   
   # Start HAProxy with L4 config
   sudo systemctl stop haproxy
   sudo haproxy -f /etc/haproxy/haproxy-l4.cfg -D
   ```

2. **Test Layer 4 proxy:**

   ```bash
   # From attacker VM
   vagrant ssh attacker
   
   # Test load balancing - notice different backend servers
   for i in {1..9}; do
     echo "Request $i:"
     curl -s http://192.168.210.21:9096 | grep "Backend Server"
   done
   
   # All requests are load balanced, but proxy doesn't know about HTTP
   ```

3. **Observe Layer 4 limitations:**

   ```bash
   vagrant ssh attacker
   
   # Try to route based on URL path - THIS WILL NOT WORK at L4
   curl http://192.168.210.21:9096/api/info
   curl http://192.168.210.21:9096/api/health
   
   # Both go through round-robin - L4 proxy doesn't see URLs!
   ```

#### Part B: Layer 7 HTTP Proxy (Powerful, Feature-Rich)

1. **Configure HAProxy in HTTP mode:**

   ```bash
   vagrant ssh proxy
   
   # Stop L4 proxy
   sudo killall haproxy
   
   # Create Layer 7 configuration
   sudo tee /etc/haproxy/haproxy-l7.cfg <<'EOF'
global
    log /dev/log local0
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http                   # Layer 7 mode!
    option  httplog                # HTTP logging (shows URLs, status codes)
    option  dontlognull
    timeout connect 5s
    timeout client  50s
    timeout server  50s
    timeout http-request 10s
    
    # HTTP-specific options
    option  http-server-close
    option  forwardfor             # Add X-Forwarded-For header
    option  httpchk                # HTTP health checks

# Statistics (same as before)
listen stats
    bind *:8405
    stats enable
    stats uri /stats
    stats refresh 3s
    stats show-legends
    stats admin if TRUE
    stats auth admin:admin123      # Basic auth for stats

# Layer 7 HTTP load balancer
frontend http_frontend
    bind *:9097
    mode http
    
    # Log format shows HTTP details
    log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs %{+Q}r"
    
    # ACLs (Access Control Lists) - only possible at L7!
    acl is_api path_beg /api
    acl is_health path /api/health
    acl is_admin path_beg /admin
    acl allowed_admin_ip src 192.168.220.11
    
    # Block admin access from non-whitelisted IPs (must come before use_backend)
    http-request deny if is_admin !allowed_admin_ip
    
    # Add custom headers (L7 feature - must come before use_backend)
    http-request add-header X-Load-Balancer HAProxy-L7
    http-response add-header X-Backend-Server %s
    
    # Content-based routing - THE POWER OF L7!
    use_backend api_backend if is_api
    use_backend health_backend if is_health
    
    default_backend web_backend

backend web_backend
    mode http
    balance roundrobin
    
    # HTTP health check
    option httpchk GET /
    http-check expect status 200
    
    server web1 192.168.230.31:80 check inter 2000
    server web2 192.168.230.32:80 check inter 2000
    server web3 192.168.230.33:80 check inter 2000

backend api_backend
    mode http
    balance leastconn              # Least connections for API
    
    # More frequent health checks for API
    option httpchk GET /api/health
    http-check expect string healthy
    
    server web1 192.168.230.31:80 check inter 1000
    server web2 192.168.230.32:80 check inter 1000
    server web3 192.168.230.33:80 check inter 1000

backend health_backend
    mode http
    # Direct to a specific server for health endpoint
    server web1 192.168.230.31:80
EOF
   
   # Test and start
   sudo haproxy -c -f /etc/haproxy/haproxy-l7.cfg
   sudo haproxy -f /etc/haproxy/haproxy-l7.cfg -D
   ```

2. **Test Layer 7 features:**

   ```bash
   vagrant ssh attacker
   
   # Content-based routing - works at L7!
   echo "=== Testing L7 Content-Based Routing ==="
   
   # Regular web requests - go to web_backend
   curl -s http://192.168.210.21:9097/ | grep "Backend Server"
   
   # API requests - go to api_backend (least connections)
   curl -s http://192.168.210.21:9097/api/info
   
   # Health endpoint - goes to specific backend
   curl -s http://192.168.210.21:9097/api/health
   
   # See custom headers added by L7 proxy
   curl -I http://192.168.210.21:9097/ | grep -E "X-Load|X-Backend"
   ```

3. **Compare L4 vs L7 in logs:**

   ```bash
   vagrant ssh proxy
   
   # Check HAProxy logs
   sudo tail -f /var/log/haproxy.log
   
   # L7 logs show:
   # - HTTP method (GET, POST)
   # - URL path
   # - Status codes (200, 404, 500)
   # - User agents
   # - Response times
   
   # L4 logs show:
   # - Only bytes transferred
   # - Connection states
   # - No HTTP details
   ```

#### Part C: Side-by-Side Comparison

| Feature | Layer 4 (TCP) | Layer 7 (HTTP) |
|---------|---------------|----------------|
| **Speed** | ⚡⚡⚡ Fastest | ⚡⚡ Fast |
| **CPU Usage** | Low | Higher |
| **Memory Usage** | Low | Higher |
| **Can route by URL** | ❌ No | ✅ Yes |
| **Can modify headers** | ❌ No | ✅ Yes |
| **Can cache** | ❌ No | ✅ Yes (with plugin) |
| **Can authenticate** | ❌ No | ✅ Yes |
| **Sees HTTP status codes** | ❌ No | ✅ Yes |
| **Can do SSL termination** | ⚠️ Limited | ✅ Full support |
| **Works with non-HTTP** | ✅ Yes | ❌ No |

**When to use L4:**
- Non-HTTP protocols (database, SSH)
- Need maximum performance
- Simple load balancing

**When to use L7:**
- Need content-based routing
- Need to inspect/modify HTTP
- Need advanced features (auth, caching, security)

### Exercise 4.2: Production HAProxy with SSL/TLS Termination

Real-world production proxies handle SSL/TLS. This exercise builds a production-grade setup.

#### Setup SSL Certificates

1. **Generate self-signed certificates:**

   ```bash
   vagrant ssh proxy
   
   # Create certificate directory
   sudo mkdir -p /etc/haproxy/certs
   
   # Generate self-signed cert (for lab purposes)
   sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /etc/haproxy/certs/server.key \
     -out /etc/haproxy/certs/server.crt \
     -subj "/C=US/ST=Lab/L=Lab/O=DevSecOps/CN=proxy.lab.local"
   
   # HAProxy needs cert and key in one file
   sudo cat /etc/haproxy/certs/server.crt /etc/haproxy/certs/server.key \
     | sudo tee /etc/haproxy/certs/server.pem
   
   sudo chmod 600 /etc/haproxy/certs/server.pem
   sudo chown haproxy:haproxy /etc/haproxy/certs/server.pem
   ```

#### Configure Production HAProxy

2. **Create production configuration:**

```bash
   sudo tee /etc/haproxy/haproxy-production.cfg <<'EOF'
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 30s
    user haproxy
    group haproxy
    daemon
    
    # SSL/TLS settings
    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
    
    # Performance tuning
    maxconn 4096
    tune.ssl.default-dh-param 2048

defaults
    log     global
    mode    http
    option  httplog
    option  dontlognull
    option  http-server-close
    option  forwardfor except 127.0.0.0/8
    option  redispatch
    retries 3
    timeout connect 5s
    timeout client  50s
    timeout server  50s
    timeout http-request 10s
    timeout queue 1m
    errorfile 400 /etc/haproxy/errors/400.http
    errorfile 403 /etc/haproxy/errors/403.http
    errorfile 408 /etc/haproxy/errors/408.http
    errorfile 500 /etc/haproxy/errors/500.http
    errorfile 502 /etc/haproxy/errors/502.http
    errorfile 503 /etc/haproxy/errors/503.http
    errorfile 504 /etc/haproxy/errors/504.http

# Statistics and monitoring
listen stats
    bind *:8405
    mode http
    stats enable
    stats uri /haproxy?stats
    stats realm HAProxy\ Statistics
    stats auth admin:SecurePass123!
    stats refresh 10s
    stats show-legends
    stats show-node
    stats admin if TRUE

# HTTPS Frontend (SSL termination)
frontend https_frontend
    bind *:9443 ssl crt /etc/haproxy/certs/server.pem
    mode http
    
    # Security headers
    http-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains"
    http-response set-header X-Frame-Options "SAMEORIGIN"
    http-response set-header X-Content-Type-Options "nosniff"
    http-response set-header X-XSS-Protection "1; mode=block"
    
    # Rate limiting
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request deny deny_status 429 if { sc_http_req_rate(0) gt 100 }
    
    # ACLs
    acl is_api path_beg /api
    acl is_static path_beg /static
    acl is_admin path_beg /admin
    acl allowed_admin src 192.168.220.11
    
    # Deny unauthorized admin access (must come before use_backend)
    http-request deny if is_admin !allowed_admin
    
    # Routing
    use_backend api_servers if is_api
    use_backend static_servers if is_static
    use_backend admin_servers if is_admin allowed_admin
    
    default_backend web_servers

# HTTP Frontend (redirect to HTTPS)
frontend http_frontend
    bind *:9080
    mode http
    redirect scheme https code 301 if !{ ssl_fc }

# Backend pools
backend web_servers
    mode http
    balance roundrobin
    option httpchk GET /
    http-check expect status 200
    
    # Connection pooling
    http-reuse safe
    
    server web1 192.168.230.31:80 check inter 2000 rise 2 fall 3 weight 100
    server web2 192.168.230.32:80 check inter 2000 rise 2 fall 3 weight 100
    server web3 192.168.230.33:80 check inter 2000 rise 2 fall 3 weight 100

backend api_servers
    mode http
    balance leastconn                   # Best for APIs
    option httpchk GET /api/health
    http-check expect string healthy
    
    # Stricter health checks for APIs
    server web1 192.168.230.31:80 check inter 1000 rise 3 fall 2
    server web2 192.168.230.32:80 check inter 1000 rise 3 fall 2
    server web3 192.168.230.33:80 check inter 1000 rise 3 fall 2

backend static_servers
    mode http
    balance roundrobin
    # No health check needed for static content
    server web1 192.168.230.31:80
    server web2 192.168.230.32:80
    server web3 192.168.230.33:80

backend admin_servers
    mode http
    balance roundrobin
    # Extra logging for admin access
    option httplog
    server web1 192.168.230.31:80 check
EOF
   
   # Validate and restart
   sudo haproxy -c -f /etc/haproxy/haproxy-production.cfg
   sudo killall haproxy
   sudo haproxy -f /etc/haproxy/haproxy-production.cfg -D
   ```

3. **Test production features:**

```bash
   vagrant ssh attacker
   
   # Test HTTPS with SSL termination
   curl -k https://192.168.210.21:9443/
   
   # Test HTTP redirect to HTTPS
   curl -I http://192.168.210.21:9080/
   # Should see: HTTP/1.1 301 Moved Permanently
   
   # Test security headers
   curl -k -I https://192.168.210.21:9443/ | grep -E "Strict-Transport|X-Frame|X-Content"
   
   # Test rate limiting (send 150 requests quickly)
   for i in {1..150}; do
     curl -k -s -o /dev/null -w "%{http_code}\n" https://192.168.210.21:9443/
   done
   # Should see some 429 (Too Many Requests) responses
   
   # Test content-based routing
   curl -k https://192.168.210.21:9443/api/info
   curl -k https://192.168.210.21:9443/static/test
   
   # View stats page
   curl -u admin:SecurePass123! http://192.168.210.21:8405/haproxy?stats
   ```

### Exercise 4.3: Advanced Features - Sticky Sessions and Circuit Breakers

Production applications often need session persistence and fault tolerance.

1. **Configure sticky sessions:**

```bash
   vagrant ssh proxy
   
   sudo tee /etc/haproxy/haproxy-sticky.cfg <<'EOF'
global
    daemon
    maxconn 4096

defaults
    mode http
    timeout connect 5s
    timeout client 50s
    timeout server 50s

listen stats
    bind *:8405
    stats enable
    stats uri /stats

frontend app_frontend
    bind *:9098
    default_backend app_backend

backend app_backend
    balance roundrobin
    
    # Cookie-based sticky sessions
    cookie SERVERID insert indirect nocache
    
    server web1 192.168.230.31:80 check cookie web1
    server web2 192.168.230.32:80 check cookie web2
    server web3 192.168.230.33:80 check cookie web3
EOF
   
   sudo killall haproxy
   sudo haproxy -f /etc/haproxy/haproxy-sticky.cfg -D
   ```

2. **Test sticky sessions:**

```bash
   vagrant ssh attacker
   
   # First request - get a cookie
   curl -c /tmp/cookies.txt http://192.168.210.21:9098/ 2>&1 | grep -E "Backend Server|Set-Cookie"
   
   # Subsequent requests - should always go to same server
   for i in {1..5}; do
     curl -b /tmp/cookies.txt -s http://192.168.210.21:9098/ | grep "Backend Server"
   done
   
   # All should show the SAME backend server!
   ```

3. **Configure circuit breaker pattern:**

```bash
   vagrant ssh proxy
   
   sudo tee /etc/haproxy/haproxy-circuit-breaker.cfg <<'EOF'
global
    daemon

defaults
    mode http
    timeout connect 5s
    timeout client 50s
    timeout server 50s
    retries 3                          # Retry failed requests

listen stats
    bind *:8405
    stats enable
    stats uri /stats

frontend resilient_frontend
    bind *:9099
    default_backend resilient_backend

backend resilient_backend
    balance roundrobin
    option httpchk GET /api/health
    
    # Circuit breaker settings
    server web1 192.168.230.31:80 check inter 1000 rise 2 fall 3 on-error mark-down observe layer7
    server web2 192.168.230.32:80 check inter 1000 rise 2 fall 3 on-error mark-down observe layer7
    server web3 192.168.230.33:80 check inter 1000 rise 2 fall 3 on-error mark-down observe layer7 backup
    
    # If a server fails 3 checks (fall 3), it's marked down
    # It needs 2 successful checks (rise 2) to come back up
    # observe layer7 = monitor HTTP errors (500, 502, 503)
EOF
   
   sudo killall haproxy
   sudo haproxy -f /etc/haproxy/haproxy-circuit-breaker.cfg -D
   ```

4. **Test circuit breaker:**

```bash
   vagrant ssh attacker
   
   # Send requests normally
   for i in {1..5}; do
     curl -s http://192.168.210.21:9099/ | grep "Backend"
   done
   
   # Now simulate a backend failure
   # In another terminal:
   vagrant ssh web1
   sudo systemctl stop nginx
   
   # Back on attacker, keep sending requests
   # HAProxy will detect the failure and stop sending traffic to web1
   for i in {1..10}; do
     echo "Request $i:"
     curl -s http://192.168.210.21:9099/ | grep "Backend Server" || echo "Failed"
     sleep 1
   done
   
   # You should see:
   # 1. A few requests may fail while HAProxy detects the problem
   # 2. Then all traffic goes to web2 (or web3 if web2 also fails)
   # 3. web1 is automatically removed from rotation
   
   # Restart web1 and watch it come back
   vagrant ssh web1
   sudo systemctl start nginx
   
   # After 2 successful health checks, web1 rejoins the pool!
   ```

### Exercise 4.4: Production Monitoring and Observability

Real production proxies need comprehensive monitoring.

1. **Enable detailed logging:**

```bash
   vagrant ssh proxy
   
   # Create logging configuration
   sudo tee -a /etc/haproxy/haproxy-production.cfg <<'EOF'

# Logging configuration for production
frontend https_frontend
    # ... existing config ...
    
    # Custom log format with all details
    log-format "%ci:%cp [%tr] %ft %b/%s %TR/%Tw/%Tc/%Tr/%Ta %ST %B %CC %CS %tsc %ac/%fc/%bc/%sc/%rc %sq/%bq %hr %hs {%[ssl_c_verify],%{+Q}[ssl_c_s_dn],%{+Q}[ssl_c_i_dn]} %{+Q}r"
    
    # Capture headers for debugging
    capture request header User-Agent len 128
    capture request header Referer len 128
    capture response header Content-Type len 64
    capture response header Cache-Control len 32
EOF
   ```

2. **Monitor with HAProxy stats API:**

```bash
   vagrant ssh proxy
   
   # Query HAProxy stats via socket
   echo "show stat" | sudo socat stdio /run/haproxy/admin.sock | column -t -s,
   
   # Show current sessions
   echo "show sess" | sudo socat stdio /run/haproxy/admin.sock
   
   # Show backend status
   echo "show servers state" | sudo socat stdio /run/haproxy/admin.sock
   
   # Disable a server (maintenance mode)
   echo "disable server resilient_backend/web3" | sudo socat stdio /run/haproxy/admin.sock
   
   # Enable it back
   echo "enable server resilient_backend/web3" | sudo socat stdio /run/haproxy/admin.sock
   ```

3. **Performance metrics:**

```bash
   # Create monitoring script
   cat > /tmp/haproxy-monitor.sh <<'EOF'
#!/bin/bash
while true; do
  clear
  echo "=== HAProxy Performance Metrics ==="
  echo "show info" | socat stdio /run/haproxy/admin.sock | grep -E "CurrConns|CumConns|CumReq|MaxConnRate"
  echo ""
  echo "=== Backend Health ==="
  echo "show stat" | socat stdio /run/haproxy/admin.sock | grep -E "web1|web2|web3" | cut -d',' -f1,2,18,19
  sleep 2
done
EOF
   chmod +x /tmp/haproxy-monitor.sh
   sudo /tmp/haproxy-monitor.sh
   ```

### Production Best Practices Summary

Based on these exercises, here are key production practices:

1. **Use Layer 7 for HTTP/HTTPS** - You need content-based routing
2. **Always implement SSL/TLS termination** - Centralize certificate management
3. **Configure proper health checks** - Detect failures quickly
4. **Implement rate limiting** - Protect against abuse
5. **Use sticky sessions when needed** - For stateful applications
6. **Set up comprehensive monitoring** - Know when things go wrong
7. **Configure circuit breakers** - Fail fast and recover automatically
8. **Add security headers** - Protect users from common attacks
9. **Log everything** - Debug issues and analyze traffic patterns
10. **Test failover scenarios** - Ensure HA actually works

### Cleanup and VM Management

When you're done with HAProxy exercises:

```bash
# Halt backend servers
vagrant halt web1 web2 web3

# Start original webserver if needed
vagrant up webserver
```

### 1. Reverse proxy (Nginx) - Original Content
   - Use `nginx-app.conf` and point it to a local app on port 8080.
   - Reload nginx and verify headers are forwarded.
   - Expected: `curl -I http://localhost/` returns `200 OK` with `Via` or `X-Forwarded-For` headers injected by Nginx.

2. **Forward proxy (Squid)**
   - Start Squid with `squid.conf.example`.
   - Configure your browser or curl to use the proxy and verify access.
   - Expected: `curl -x http://localhost:3128 http://example.com` returns HTML and Squid logs show `TCP_MISS/200`.

3. **Logging**
   - Tail Nginx access logs and Squid logs to observe requests.
   - Expected: `/var/log/nginx/access.log` shows `"GET / HTTP/1.1" 200` with your client IP; `/var/log/squid/access.log` shows timestamps plus `TCP_MISS/200` for proxied sites.

### Advanced: Layer 7 hardening and troubleshooting

1. **Mutual TLS between Nginx and backend**
   - Generate a simple CA + server/client cert pair with `openssl req -new -x509`.
   - Configure Nginx to require client certs to reach `/admin` and reload.
   - Example verification: `curl -vk --cert client.crt --key client.key https://localhost/admin` should succeed while a plain curl returns `400` or `403`.

2. **Cache + rate-limit heavy endpoints**
   - Add `proxy_cache_path` + `proxy_cache` to cache `/api/v1/reports` for 30s.
   - Add `limit_req_zone $binary_remote_addr zone=api:10m rate=1r/s;` and a `limit_req` directive on `/api/`.
   - Use `ab -n 20 -c 5 http://localhost/api/v1/reports` and observe cached responses + 503s when limits trigger.

3. **Squid auth and ACL tests**
   - Enable basic auth in `squid.conf.example` (e.g., `auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd`).
   - Create users with `htpasswd -c /etc/squid/passwd analyst`.
   - Verify `curl -x http://localhost:3128 http://example.com` fails without creds and succeeds with `-U analyst:<password>`.
   - Expected: unauthenticated curl returns `407 Proxy Authentication Required`; authenticated requests succeed and Squid logs show `TCP_MISS/200` with the username.

4. **Fault injection + log correlation**
   - Simulate backend failure by stopping the upstream app and capture Nginx `upstream timed out` errors.
   - Map timestamps between Nginx access/error logs and Squid logs to trace a single request end-to-end.

### Example solutions / what “good” looks like

- `curl` to `/admin` without a client cert should show `400 No required SSL certificate was sent`; with a valid cert it returns `200 OK`.
- ApacheBench results should show most `200` responses served in <5ms after caching, with some `503` once the rate limit trips.
- Squid denies unauthenticated requests with `HTTP/1.1 407 Proxy Authentication Required`; authenticated requests succeed and appear in `access.log` with `TCP_MISS/200`.
- When the backend is down, Nginx should log `upstream timed out` in `error.log` and the matching entry in `access.log` should be `504` for the same timestamp + client IP.
- Access logs during mTLS tests should include `ssl_client_verify=SUCCESS` for allowed requests and `FAILED:certificate required` for blocked ones, confirming header propagation.

## Checklist

### Basic Tasks
- [ ] Reverse proxy forwards traffic to your app
- [ ] Forward proxy is reachable and enforces ACL
- [ ] You reviewed access logs for both services
- [ ] Client-cert enforcement tested on a protected path
- [ ] Caching + rate limiting verified with a load test
- [ ] Squid auth + deny-by-default confirmed in access.log
- [ ] Error scenarios traced across access and error logs

### VM-Based Proxy Tasks
- [ ] Tested Squid forward proxy from attacker VM to webserver
- [ ] Monitored Squid logs in real-time during traffic
- [ ] Attempted and documented proxy bypass attack
- [ ] Configured Nginx reverse proxy with IP whitelisting
- [ ] Tested header injection attack and verified proxy protection
- [ ] Implemented and tested admin endpoint access control
- [ ] Analyzed proxy logs to identify cache hits vs misses

### High Availability (HA) Proxy Tasks
- [ ] Configured Nginx upstream for load balancing
- [ ] Tested different load balancing algorithms (round-robin, least_conn, ip_hash)
- [ ] Implemented health checks with max_fails and fail_timeout
- [ ] Simulated backend failure and verified automatic failover
- [ ] Configured session persistence with ip_hash
- [ ] Set up HAProxy with backend pool and health checks
- [ ] Monitored HAProxy statistics page
- [ ] Understood HA proxy architectures and deployment patterns

### Advanced Understanding
- [ ] Can explain difference between forward and reverse proxy
- [ ] Understand X-Forwarded-For and X-Real-IP headers
- [ ] Know how to detect proxy abuse in logs
- [ ] Can implement defense-in-depth with proxy + firewall
- [ ] Understand load balancing algorithms and when to use each
- [ ] Know how to configure and troubleshoot health checks
- [ ] Can design HA proxy architecture for production use
