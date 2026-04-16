# Week 1 – Network Basics Lab

## Objectives

- Understand basic networking commands on Linux
- Inspect open ports and connections
- Observe HTTP traffic
- Practice attack/defense scenarios using VMs
- Understand network segmentation and traffic flow in a lab environment
- Learn Kubernetes networking fundamentals (pods, services, DNS, CNI)
- Learn about gateways and their role in network routing

## Estimated Time

⏱️ **2.5-3 hours** (core exercises including Kubernetes networking, excluding optional gateway exploration)

This lab is comprehensive and includes:
- VM setup and verification (~10-15 minutes if VMs already downloaded)
- Basic networking commands (~10-15 minutes)
- Traffic capture exercises (~15-20 minutes)
- VM-based attack/defense scenarios (~30-40 minutes)
- Advanced port scanning and correlation (~20-30 minutes)
- Kubernetes networking fundamentals (~40-50 minutes)
- Gateway concepts exploration (~10-15 minutes - conceptual only)

**Tips for time management:**
- First-time VM setup may take longer (downloads, provisioning) - budget 30-45 minutes
- Core exercises focus on practical networking skills you'll use immediately
- Advanced exercises (Tasks 4-6) build on the basics - complete them in order
- Gateway exploration is optional and conceptual - hands-on gateway config is in Week 2
- Use VM snapshots to save progress between sessions

## VM Setup for This Lab

Start the required VMs:
```bash
cd /path/to/devops-tutorial
vagrant up attacker defender webserver
```

**VM Roles in This Lab:**
- **attacker** (192.168.210.10) - Run network scans, generate traffic, and simulate reconnaissance
- **defender** (192.168.220.11) - Monitor network traffic and practice defensive observation
- **webserver** (192.168.230.20) - Target for testing HTTP traffic and connectivity

**Note:** Attacker (`192.168.210.x`), defender (`192.168.220.x`), and webserver (`192.168.230.x`) are on different network segments. Cross-subnet exercises (scanning defender from attacker, or reaching webserver) require the **gateway** VM to be running and routing traffic between the networks. Start all four VMs when you want to practice attack/defense scenarios:

```bash
vagrant up attacker defender webserver gateway
```

If you only want to run local networking commands on a single VM, the other VMs are not required.

**Lab Flow:**
1. Run network commands on any VM to understand basics
2. From **attacker**: scan and probe other VMs
3. On **defender**: monitor and capture traffic
4. Use **webserver** as a target for HTTP exercises
5. Correlate attacker actions with defender observations

See [VM Setup Guide](../../VM-SETUP.md) for detailed instructions.

## Tasks

### 1. Inspect network interfaces and routes

Run and note output:

```bash
ip addr
ip route
```

Expected output hints:

- `ip addr` should show `lo` plus one main NIC (often `eth0` or `ens3`) with an IPv4 like `192.168.x.x/24` and `state UP`.
- `ip route` usually lists a line starting with `default via 192.168.x.1 dev eth0` indicating the gateway and interface.

Questions to answer (write in your own notes):

- What is your default gateway?
- Which interface has your main IP?

### 2. List listening ports and processes

```bash
ss -tulpn | head -20
```

Note:

- Which services listen on TCP?
- Do you see sshd, nginx, or others?

Expected output hints:

- Typical lab VMs show `LISTEN 0 128 *:22` owned by `sshd` and `127.0.0.53:53` from `systemd-resolved`.
- If you started Python HTTP server later, expect `LISTEN ... :8088` with `python3` as the process.

### 3. Simple HTTP traffic capture (if you have curl installed)

```bash
sudo apt update && sudo apt install -y tcpdump
sudo tcpdump -i any port 80 -n
```

In another terminal:

```bash
curl http://example.com
```

Stop tcpdump with Ctrl+C and review lines.

Expected output hints:

- You should see `IP 10.10.10.2.XXXXX > 10.10.10.1.8088: Flags [P]` and `GET / HTTP/1.1` when curling the test server.
- Packet counts in the tcpdump summary should increase for both directions (request + response).

### 3.1. How to Make tcpdump Output Readable

The default tcpdump output can be overwhelming and jumbled! Here are better ways to view and analyze network traffic:

#### Option A: Cleaner tcpdump Output

Use flags to make tcpdump output more readable:

```bash
# Simple and clean - one line per connection
sudo tcpdump -i any host 192.168.210.10 -n -q

# Show just SYN packets (connection attempts)
sudo tcpdump -i any 'tcp[tcpflags] & (tcp-syn) != 0' -n

# Group by conversation with better formatting
sudo tcpdump -i any host 192.168.210.10 -n -l | \
  awk '{printf "%-20s %-6s %-30s\n", $1, $5, $0}'
```

**Explanation:**
- `-n`: Don't resolve hostnames (faster and clearer)
- `-q`: Quiet mode - less protocol information
- `-l`: Line buffered output (better for piping)
- `tcp[tcpflags]`: Filter by specific TCP flags (SYN, ACK, etc.)
- The awk command formats output into neat columns

**When to use:** Quick analysis during active scans or when you want to reduce noise.

#### Option B: Save and Analyze with Better Tools

Capture traffic to a file and analyze it with specialized tools:

```bash
# Capture to file during scan
sudo tcpdump -i any host 192.168.210.10 -w scan.pcap

# Analyze with tshark (text-based Wireshark)
sudo apt install -y tshark

# Extract specific fields
tshark -r scan.pcap -T fields -e ip.src -e ip.dst -e tcp.dstport -e tcp.flags

# Filter HTTP traffic
tshark -r scan.pcap -Y "http" -T fields -e ip.src -e http.request.method -e http.request.uri

# Get protocol statistics
tshark -r scan.pcap -q -z io,phs
```

**Explanation:**
- `-w`: Write packets to pcap file instead of displaying
- `-r`: Read from pcap file
- `-T fields`: Output as tab-separated fields
- `-e`: Specify which fields to extract
- `-Y`: Display filter (Wireshark syntax)
- `-q -z`: Generate statistics

**When to use:** For detailed forensic analysis, sharing captures with team members, or when you need to review traffic multiple times.

#### Option C: Real-Time Monitoring with Better Formatting

Use visual tools for live network monitoring:

```bash
# Install iftop for visual network monitoring
sudo apt install -y iftop

# Monitor specific interface with bandwidth usage
sudo iftop -i eth1

# Filter by host
sudo iftop -i eth1 -f "host 192.168.210.10"
```

**iftop controls:**
- `h`: Toggle help
- `n`: Toggle hostname resolution
- `s`: Toggle source host display
- `d`: Toggle destination host display
- `p`: Toggle port display
- `q`: Quit

Alternative with nload:

```bash
# Install nload for simpler bandwidth monitoring
sudo apt install -y nload

# Monitor specific interface
sudo nload eth1

# Monitor multiple interfaces
sudo nload eth0 eth1
```

**Explanation:**
- `iftop`: Shows bandwidth usage per connection in real-time (like top for network)
- `nload`: Shows incoming/outgoing bandwidth with graphs
- Both provide visual feedback that's easier to interpret than raw tcpdump

**When to use:** During active attacks to see bandwidth consumption, or when monitoring ongoing traffic patterns.

#### Option D: Connection Tracking with tcptrack

Track TCP connections with a clean interface:

```bash
# Install tcptrack
sudo apt install -y tcptrack

# Monitor all TCP connections
sudo tcptrack -i eth1

# Filter specific traffic
sudo tcptrack -i eth1 host 192.168.210.10
```

**tcptrack features:**
- Shows state (ESTABLISHED, SYN_SENT, TIME_WAIT, etc.)
- Displays source/destination IPs and ports
- Shows idle time for each connection
- Auto-updates as connections change

**Explanation:**
- Provides a "live" view of TCP connection states
- Much easier to spot scan patterns than raw tcpdump
- Idle time helps identify persistent vs. transient connections

**When to use:** Perfect for monitoring port scans, watching for persistent backdoors, or debugging connection issues.

#### Practical Example: Analyzing an nmap Scan

Let's combine these tools to analyze a port scan:

```bash
# Terminal 1 (Defender): Start monitoring with multiple tools
vagrant ssh defender

# Option 1: Raw capture to file (save PID for clean termination)
sudo tcpdump -i eth1 -w /tmp/scan.pcap 'src 192.168.210.10' &
TCPDUMP_PID=$!

# Option 2: Watch with tcptrack (in another terminal, or use screen/tmux)
# sudo tcptrack -i eth1 host 192.168.210.10

# Terminal 2 (Attacker): Run the scan
vagrant ssh attacker
# Using a larger port range to demonstrate realistic scan detection
nmap -sS -p 1-1000 192.168.220.11

# Terminal 1 (Defender): Analyze after scan completes
# Terminate the specific tcpdump process using its PID
sudo kill -TERM $TCPDUMP_PID
sleep 2

# View statistics
tshark -r /tmp/scan.pcap -q -z conv,tcp
tshark -r /tmp/scan.pcap -q -z io,phs

# Count SYN packets per port
tshark -r /tmp/scan.pcap -T fields -e tcp.dstport | sort | uniq -c | sort -rn | head -20
```

**What you'll learn:**
- How many ports were scanned
- Which ports responded (SYN-ACK)
- Duration and pattern of the scan
- Scan timing and packet rate

#### Comparison Table

| Tool | Best For | Pros | Cons |
|------|----------|------|------|
| tcpdump | Raw packet capture | Powerful filters, standard tool | Hard to read, no statistics |
| tshark | Detailed analysis | Wireshark filters, many formats | Requires saved pcap |
| iftop | Bandwidth monitoring | Real-time, visual, easy to use | No packet details |
| nload | Simple bandwidth view | Very simple, graph display | Limited filtering |
| tcptrack | Connection tracking | Shows connection states | TCP only |

#### Pro Tips

1. **Combine tools:** Capture with tcpdump, analyze with tshark
2. **Use filters early:** Don't capture everything - filter at capture time
3. **Mind the disk space:** Large captures fill disk quickly
4. **Rotate captures:** Use `-C` (file size) and `-W` (number of files) with tcpdump:
   ```bash
   # Rotate capture files: -C 10 = 10 million bytes (≈9.54 MiB) per file, -W 5 = keep 5 newest files
   sudo tcpdump -i eth1 -w capture.pcap -C 10 -W 5
   ```
   This creates rotating files (capture1.pcap, capture2.pcap, etc.)
5. **Security note:** pcap files may contain sensitive data - protect them

### 4. Advanced: Build a mini lab and map traffic flows

**Option A: Using Vagrant VMs (Recommended)**

1. SSH into the attacker VM and scan the defender:

   ```bash
   vagrant ssh attacker
   nmap -sS -p 1-1024 192.168.220.11
   ```

   Expected output:
   - SSH (port 22) should show as `open`
   - Other ports will show as `filtered` or `closed`
   - Scan completes in 5-30 seconds depending on your system

2. Monitor traffic on the defender while being scanned:

   ```bash
   # In a new terminal
   vagrant ssh defender
   sudo tcpdump -i eth1 -n 'src 192.168.210.10'
   ```

   Expected: You'll see packets like `IP 192.168.210.10.XXXXX > 192.168.220.11.22: Flags [S]` showing SYN packets from the attacker's scan.

3. Test HTTP connectivity from attacker to webserver:

   ```bash
   vagrant ssh attacker
   curl http://192.168.230.20
   ```

   Expected: HTML page with "DevOps Lab Web Server" title.

4. Capture and analyze the HTTP traffic:

   ```bash
   # On attacker VM
   sudo tcpdump -i eth1 -w /tmp/http-test.pcap 'host 192.168.230.20 and port 80' &
   TCPDUMP_PID=$!
   
   curl http://192.168.230.20
   sleep 2
   sudo kill $TCPDUMP_PID
   
   # Analyze the capture
   sudo tcpdump -r /tmp/http-test.pcap -A | grep -E "GET|HTTP|Host:"
   ```

   Expected output hints:
   - You should see `GET / HTTP/1.1` request from attacker
   - `HTTP/1.1 200 OK` response from webserver
   - `Host: 192.168.230.20` header in the request

**Option B: Using Linux Network Namespaces (Alternative if no VMs)**

1. Create a pair of virtual ethernet interfaces and a namespace to simulate an "attacker" VM:

   ```bash
   sudo ip link add veth-red type veth peer name veth-blue
   sudo ip netns add red
   sudo ip link set veth-red netns red
   sudo ip addr add 10.10.10.1/24 dev veth-blue
   sudo ip link set veth-blue up
   sudo ip netns exec red ip addr add 10.10.10.2/24 dev veth-red
   sudo ip netns exec red ip link set veth-red up
   ```

   Sanity check: `ip -n red addr show veth-red` should display `inet 10.10.10.2/24` and `state UP`.

2. Start a temporary HTTP server on the host side and hit it from inside the namespace:

   ```bash
   python3 -m http.server 8088 >/tmp/http.log 2>&1 &
   sudo ip netns exec red curl http://10.10.10.1:8088
   ```

   Expected: curl prints a directory listing or `200 OK` HTML. The host terminal running `python -m http.server` logs `"GET / HTTP/1.1" 200`.

3. Capture the traffic while it happens:

   ```bash
   sudo tcpdump -i veth-blue -w /tmp/veth-blue.pcap -c 20
   ```

4. Inspect the capture without leaving the CLI:

   ```bash
   tshark -r /tmp/veth-blue.pcap -Y "http" -T fields -e ip.src -e ip.dst -e http.request.uri
   ```

### 5. Advanced: Port scanning and route tracing

**Using VMs (Recommended):**

1. From the attacker VM, perform a comprehensive scan of the defender:

   ```bash
   vagrant ssh attacker
   
   # SYN scan (requires sudo)
   sudo nmap -sS -p 1-1024 192.168.220.11
   
   # Service version detection
   sudo nmap -sV -p 22,80,443 192.168.220.11
   
   # OS detection
   sudo nmap -O 192.168.220.11
   ```

   Record which ports respond and compare them with `ss -tulpn` on the defender.

   Expected:
   - Only ports you intentionally exposed (e.g., 22) show as `open`
   - Service version shows something like `OpenSSH 8.9p1 Ubuntu`
   - OS detection identifies Ubuntu Linux

2. Monitor the scan on the defender side:

   ```bash
   vagrant ssh defender
   
   # Watch connections in real-time
   watch -n 1 'ss -tan | grep ESTAB'
   
   # Or monitor with tcpdump
   sudo tcpdump -i eth1 -n 'tcp[tcpflags] & tcp-syn != 0' | head -20
   ```

   Expected: You'll see rapid SYN packets from 192.168.210.10 as nmap probes different ports.

3. Trace the route from attacker to different targets:

   ```bash
   vagrant ssh attacker
   
   # Trace to defender (should be 1 hop on local network)
   traceroute -n 192.168.220.11
   
   # Trace to webserver
   traceroute -n 192.168.230.20
   ```

   Expected: Single hop shows `192.168.220.11` with <1ms latency for local network.

4. **Advanced Attack Scenario:** TCP SYN flood simulation

   ```bash
   # On attacker VM (educational purposes only!)
   vagrant ssh attacker
   
   # Generate controlled SYN packets
   sudo hping3 -S -p 80 --flood --rand-source 192.168.230.20 -c 100
   ```

   ⚠️ **Warning:** Only run this in your lab VMs, never against production systems!

   Then on the defender or webserver, observe the impact:
   ```bash
   vagrant ssh defender
   sudo netstat -an | grep SYN_RECV | wc -l
   ```

5. **Defense Exercise:** Identify scanning activity

   On the defender VM, check system logs for scan evidence:
   ```bash
   vagrant ssh defender
   
   # Check for failed connection attempts
   sudo journalctl -u ssh --since "5 minutes ago" | grep "Failed\|Invalid"
   
   # Check kernel logs for port scan indicators
   sudo dmesg | tail -50
   ```

**Using Namespaces (Alternative):**

1. Use `nmap` from the namespace to scan the host:

   ```bash
   sudo ip netns exec red nmap -sS -p 1-1024 10.10.10.1
   ```

   Record which ports respond and compare them with `ss -tulpn`.

   Expected: Only ports you intentionally exposed (e.g., 22, 8088) show as `open`; others are `filtered` or `closed`.

2. Trace the route to a public service and explain each hop:

   ```bash
   traceroute -n 1.1.1.1 | head -10
   ```

   Identify where your traffic leaves the VM (gateway IP) and how latency changes per hop.

### Example solutions / what “good” looks like

- **Routing answers:** Default gateway often appears as `via 192.168.x.1` in `ip route` output.
- **tcpdump verification:** HTTP GET lines should show `10.10.10.2` → `10.10.10.1` with `GET /` when using the namespace test.
- **nmap comparison:** Any `open` ports in `nmap` should match listeners from `ss -tulpn`; mismatches hint at firewalls or host-based filtering.
- **Traceroute reasoning:** Latency should gradually increase; large jumps suggest WAN transit or overloaded hops.

### 6. Attack/Defense Correlation Exercise

This exercise teaches you to correlate attacker actions with defender observations.

1. **Setup monitoring on defender:**

   ```bash
   vagrant ssh defender
   
   # Terminal 1: Monitor incoming connections
   sudo tcpdump -i eth1 -n -l 'src 192.168.210.10' | tee /tmp/defender-traffic.log
   ```

2. **Execute reconnaissance from attacker:**

   ```bash
   vagrant ssh attacker
   
   # Step 1: Ping sweep
   nmap -sn 192.168.210.0/24 > /tmp/ping-sweep.txt
   sleep 5
   
   # Step 2: Port scan defender
   nmap -sS -p 1-100 192.168.220.11 > /tmp/port-scan.txt
   sleep 5
   
   # Step 3: Banner grabbing
   nc -v 192.168.220.11 22 < /dev/null > /tmp/banner.txt 2>&1
   sleep 2
   
   # Step 4: HTTP request to webserver
   curl -v http://192.168.230.20 > /tmp/http-request.txt 2>&1
   ```

3. **Analyze defender logs:**

   ```bash
   vagrant ssh defender
   
   # Review captured traffic
   cat /tmp/defender-traffic.log
   
   # Count different traffic types
   echo "=== Traffic Summary ==="
   echo "ICMP packets: $(grep -c ICMP /tmp/defender-traffic.log)"
   echo "TCP SYN packets: $(grep -c 'Flags \[S\]' /tmp/defender-traffic.log)"
   echo "TCP connections: $(grep -c 'Flags \[S\.\]' /tmp/defender-traffic.log)"
   ```

4. **Document the timeline:**

   Create a timeline correlating attacker actions with defender observations:
   
   | Time | Attacker Action | Defender Observation | Notes |
   |------|----------------|---------------------|-------|
   | T+0s | Ping sweep | ICMP echo requests from .10 | Network discovery |
   | T+5s | Port scan | Multiple SYN packets to various ports | Reconnaissance |
   | T+10s | Banner grab | TCP connection to port 22 | Service identification |
   | T+15s | HTTP request | No direct log (different target) | Targeting webserver |

### Additional VM-based success criteria

- **Nmap scan results:** Defender shows port 22 open, others filtered. Attacker sees consistent results.
- **Traffic correlation:** Every nmap SYN packet on attacker appears in defender's tcpdump within milliseconds.
- **HTTP capture:** GET request clearly visible with proper headers (`User-Agent: curl/...`).
- **Route tracing:** Single-hop paths with <1ms latency for local 192.168.210.0/24 network.
- **Defense logs:** SSH service logs show connection attempts from 192.168.210.10 matching nmap timing.
- **Correlation exercise:** Timeline accurately maps attacker commands to defender observations with proper timestamps.

### Why these exercises matter

- **Red team perspective:** Understanding what attackers see helps you think like them
- **Blue team perspective:** Knowing what defensive tools capture helps you detect attacks
- **Correlation skills:** Real SOC analysts must correlate attacker TTP with defensive telemetry
- **Tool proficiency:** Mastering nmap, tcpdump, and log analysis are essential security skills
- **Monitoring mastery:** Using the right tool (tcpdump vs tshark vs iftop) for the right job improves efficiency

## Kubernetes Networking Fundamentals

**Prerequisites:** Basic understanding of containers (Docker) is helpful but not required.

Kubernetes networking is essential for modern DevOps and security professionals. This section covers the fundamentals that prepare you for NetworkPolicy security controls in Week 2.

### What is Kubernetes?

Kubernetes (K8s) is a container orchestration platform that automates deployment, scaling, and management of containerized applications. Understanding its networking model is crucial for:
- Securing microservices architectures
- Troubleshooting connectivity issues
- Implementing network policies (Week 2)
- Understanding cloud-native security

### Kubernetes Networking Model

Kubernetes has a unique networking model with specific requirements:

1. **All pods can communicate with each other** without NAT (by default)
2. **All nodes can communicate with all pods** without NAT
3. **The IP a pod sees itself as** is the same IP others see it as

This flat network model is different from traditional VM networking where NAT is common.

### Core Networking Components

#### 1. Pods and Pod Networking

A **Pod** is the smallest deployable unit in Kubernetes (one or more containers).

```
┌─────────────────────────────────────────────┐
│           Kubernetes Cluster                 │
│                                              │
│  ┌──────────┐         ┌──────────┐         │
│  │  Pod A   │         │  Pod B   │         │
│  │ 10.244.1.5│────────│10.244.2.8│         │
│  │          │         │          │         │
│  │[container]│         │[container]│         │
│  └──────────┘         └──────────┘         │
│                                              │
└─────────────────────────────────────────────┘
```

**Key Concepts:**
- Each pod gets its own IP address
- Containers within a pod share the network namespace (same IP, can use localhost)
- Pods can communicate directly using IP addresses
- IPs are ephemeral - pods can be recreated with new IPs

**Example: Create a pod and check its IP**

```bash
# Create a simple pod
kubectl run test-pod --image=nginx --restart=Never

# Get pod IP
kubectl get pod test-pod -o wide
# Shows: NAME      READY   STATUS    IP           NODE

# Access pod from another pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside the debug pod:
wget -qO- http://10.244.1.5  # Use actual pod IP
```

#### 2. Services - Stable Network Endpoints

Since pod IPs change, Kubernetes uses **Services** for stable networking.

**Service Types:**

| Type | Description | Use Case | Access |
|------|-------------|----------|--------|
| **ClusterIP** | Internal cluster IP only | Internal microservices | Within cluster only |
| **NodePort** | Exposes on each node's IP:Port | Development, testing | External via NodeIP:Port |
| **LoadBalancer** | Cloud provider load balancer | Production external access | External via LB IP |
| **ExternalName** | DNS CNAME record | External service proxy | DNS based |

**Example: ClusterIP Service**

```bash
# Create a deployment (multiple pods)
kubectl create deployment web --image=nginx --replicas=3

# Create a ClusterIP service
kubectl expose deployment web --port=80 --type=ClusterIP

# Get service details
kubectl get svc web
# Shows: NAME   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
#        web    ClusterIP   10.96.100.50    <none>        80/TCP

# Access service from another pod
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
wget -qO- http://web  # Uses service name (DNS)
wget -qO- http://web.default.svc.cluster.local  # Full DNS name
```

**How Services Work:**

1. Service gets a stable ClusterIP (e.g., 10.96.100.50)
2. DNS entry created: `web.default.svc.cluster.local → 10.96.100.50`
3. kube-proxy creates iptables rules to load balance to pod IPs
4. Requests to ClusterIP are distributed across backend pods

**View Service Endpoints:**

```bash
# See which pods the service routes to
kubectl get endpoints web
# Shows actual pod IPs: 10.244.1.5:80,10.244.2.8:80,10.244.3.12:80
```

#### 3. Kubernetes DNS

Every service gets a DNS name automatically:

**DNS Format:** `<service-name>.<namespace>.svc.cluster.local`

**Examples:**
- `web.default.svc.cluster.local` - Full name
- `web.default` - Shorter version
- `web` - Same namespace (works within default namespace)

**Special DNS Entries:**
- `kubernetes.default.svc.cluster.local` - Kubernetes API server
- `*.svc.cluster.local` - All services in cluster

**Test DNS Resolution:**

```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Inside pod:
nslookup web
nslookup web.default.svc.cluster.local
nslookup kubernetes.default.svc.cluster.local
```

#### 4. Network Namespaces (Kubernetes Context)

Kubernetes uses Linux network namespaces for pod isolation:

```
┌─────────────────────────────────────────────────┐
│              Node (Virtual Machine)              │
│                                                  │
│  ┌────────────────┐      ┌────────────────┐    │
│  │ Network NS 1   │      │ Network NS 2   │    │
│  │  Pod A         │      │  Pod B         │    │
│  │  eth0: 10.1.5  │      │  eth0: 10.1.8  │    │
│  └────────────────┘      └────────────────┘    │
│           │                       │             │
│           └───────┬───────────────┘             │
│                   │                             │
│            ┌──────▼──────┐                      │
│            │   Bridge    │                      │
│            │  (veth pairs)│                      │
│            └──────┬──────┘                      │
│                   │                             │
│            ┌──────▼──────┐                      │
│            │  Node eth0  │                      │
│            └─────────────┘                      │
└─────────────────────────────────────────────────┘
```

**Comparison with Week 1 veth exercise:**
- You created network namespaces manually with `ip netns`
- Kubernetes does this automatically for each pod
- Each pod's network namespace is isolated
- veth pairs connect pod to node network

### 5. Container Network Interface (CNI)

CNI is a plugin specification for container networking. Popular CNI plugins:

| CNI Plugin | Description | Features |
|------------|-------------|----------|
| **Calico** | Layer 3 networking | NetworkPolicy support, BGP routing |
| **Flannel** | Simple overlay | Easy setup, VXLAN overlay |
| **Cilium** | eBPF-based | Advanced security, L7 policies |
| **Weave** | Mesh networking | Automatic discovery |

**What CNI Does:**
- Assigns IP addresses to pods
- Sets up network routes
- Configures network policies (Week 2 topic)

**Check your CNI:**

```bash
# On a Kubernetes node
ls /etc/cni/net.d/
# Shows CNI configuration files

# View CNI plugin
kubectl get pods -n kube-system | grep -E "calico|flannel|cilium|weave"
```

### Hands-On: Kubernetes Networking Lab

**Setup (using Kind - Kubernetes in Docker):**

```bash
# Install Kind (if not already installed)
# On Linux:
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create a cluster
kind create cluster --name netlab

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

**Exercise 1: Explore Pod Networking**

```bash
# Create two pods
kubectl run pod-a --image=nginx --restart=Never
kubectl run pod-b --image=busybox --restart=Never -- sleep 3600

# Get pod IPs
kubectl get pods -o wide
# Note the IP addresses

# Exec into pod-b and test connectivity to pod-a
POD_A_IP=$(kubectl get pod pod-a -o jsonpath='{.status.podIP}')
kubectl exec -it pod-b -- wget -qO- http://$POD_A_IP

# Check if pods can ping each other
kubectl exec -it pod-b -- ping -c 3 $POD_A_IP
```

**Exercise 2: Service Discovery**

```bash
# Create a deployment
kubectl create deployment web --image=nginx --replicas=3

# Expose as a service
kubectl expose deployment web --port=80 --type=ClusterIP

# Get service info
kubectl get svc web
kubectl describe svc web

# Test DNS resolution
kubectl run -it --rm test --image=busybox --restart=Never -- sh
# Inside the pod:
nslookup web
nslookup web.default.svc.cluster.local
wget -qO- http://web
exit

# View service endpoints (pod IPs)
kubectl get endpoints web
```

**Exercise 3: Service Types**

```bash
# NodePort service
kubectl expose deployment web --name=web-nodeport --port=80 --type=NodePort

# Get NodePort
kubectl get svc web-nodeport
# Shows something like: 80:30123/TCP (30123 is the NodePort)

# Access from host (if Kind)
kubectl get nodes -o wide  # Get node IP
# For Kind, use localhost:
curl http://localhost:30123
```

**Exercise 4: Network Troubleshooting**

```bash
# Create a debug pod with networking tools
kubectl run -it --rm netdebug --image=nicolaka/netshoot --restart=Never -- bash

# Inside the debug pod, explore:
# 1. View network interfaces
ip addr

# 2. Check routing
ip route

# 3. Test DNS
nslookup kubernetes.default
dig web.default.svc.cluster.local

# 4. Test connectivity
curl http://web
telnet web 80

# 5. Check iptables rules (shows service routing)
iptables -t nat -L -n -v | grep -A 5 "web"

# 6. Trace route
traceroute web
```

### Understanding Service Load Balancing

When you access a service, kube-proxy creates iptables/IPVS rules for load balancing:

```bash
# View service routing rules
kubectl run -it --rm netdebug --image=nicolaka/netshoot --restart=Never -- bash

# Inside debug pod:
# Find the ClusterIP of 'web' service
kubectl get svc web -o jsonpath='{.spec.clusterIP}'

# View iptables rules for this service
iptables -t nat -L -n | grep -A 10 "KUBE-SVC"
```

**What you'll see:**
- KUBE-SVC chain for the service ClusterIP
- KUBE-SEP chains for each backend pod (endpoints)
- Probability-based load balancing across pods

### Kubernetes Networking vs Traditional Networking

| Aspect | Traditional VMs | Kubernetes Pods |
|--------|----------------|-----------------|
| **IP Assignment** | Static or DHCP | Dynamic per pod |
| **IP Stability** | Stable (MAC-based) | Ephemeral |
| **Service Discovery** | DNS or IP | Services + DNS |
| **Load Balancing** | External LB | Built-in (Services) |
| **Network Isolation** | VLANs, Subnets | Namespaces + NetworkPolicy |
| **NAT** | Common (gateway NAT) | Avoided (CNI handles routing) |

### Why This Matters for Security

Understanding Kubernetes networking is essential for:
1. **NetworkPolicy (Week 2):** Control traffic between pods
2. **Zero Trust:** Assume breach, restrict pod-to-pod communication
3. **Microsegmentation:** Isolate different tiers (web, app, database)
4. **Troubleshooting:** Diagnose connectivity issues
5. **Cloud Native Security:** Modern attacks target container networks

### Common Kubernetes Networking Patterns

**Pattern 1: Three-Tier Application**

```
┌─────────────────────────────────────────────────┐
│                                                  │
│  ┌──────────┐      ┌──────────┐      ┌────────┐│
│  │   Web    │─────▶│   App    │─────▶│   DB   ││
│  │  (svc)   │      │  (svc)   │      │ (svc)  ││
│  │  Pods    │      │  Pods    │      │  Pod   ││
│  └──────────┘      └──────────┘      └────────┘│
│       ▲                                          │
│       │                                          │
│  External Access                                 │
│  (LoadBalancer)                                  │
└─────────────────────────────────────────────────┘
```

Each tier has:
- Deployment (pods)
- Service (stable endpoint)
- NetworkPolicy (Week 2) to restrict access

**Pattern 2: Sidecar Proxy (Service Mesh)**

```
┌──────────────────────────┐
│        Pod               │
│  ┌──────────┐            │
│  │   App    │            │
│  │Container │◄───┐       │
│  └──────────┘    │       │
│                  │       │
│  ┌──────────┐    │       │
│  │  Proxy   │────┘       │
│  │ (Envoy)  │            │
│  └──────────┘            │
└──────────────────────────┘
```

Sidecar proxy handles:
- Encryption (mTLS)
- Authentication
- Traffic shaping
- Observability

### Cleanup

```bash
# Delete test resources
kubectl delete deployment web
kubectl delete svc web web-nodeport
kubectl delete pod pod-a pod-b

# Delete Kind cluster (optional)
kind delete cluster --name netlab
```

### Next Steps

- **Week 2:** Learn NetworkPolicy to control pod-to-pod traffic
- **Week 3:** Explore service mesh and advanced networking
- Practice: Set up a multi-tier app with services
- Experiment: Try different CNI plugins (Calico, Cilium)

### Kubernetes Networking Checklist

- [ ] I understand the Kubernetes networking model (flat network, no NAT)
- [ ] I can create pods and check their IP addresses
- [ ] I understand the difference between pod IPs and service IPs
- [ ] I can create and use ClusterIP services
- [ ] I understand Kubernetes DNS (service-name.namespace.svc.cluster.local)
- [ ] I can troubleshoot connectivity issues using netshoot/busybox pods
- [ ] I understand how services load balance across pods
- [ ] I can explain the difference between ClusterIP, NodePort, and LoadBalancer
- [ ] I'm ready to learn NetworkPolicy security controls (Week 2)

## Introduction to Gateway Concepts (Conceptual Overview)

**Note:** This section provides conceptual understanding only. Hands-on gateway configuration is covered in Week 2. The gateway VM is NOT needed for Week 1 exercises.

The **gateway** is a fundamental networking concept that determines how traffic leaves your local network. Understanding gateways is crucial for network troubleshooting and security.

### What is a Gateway?

A **gateway** (or **default gateway**) is a network device that serves as an access point to another network. Think of it as the "door" through which your traffic exits to reach destinations outside your local network.

**Key Concepts:**
- **Default Gateway**: The IP address of the router that forwards traffic to destinations outside your local network
- **Routing Decision**: When your computer needs to reach an IP outside its subnet, it sends the packet to the gateway
- **Network Edge**: The gateway sits at the edge of your network, connecting it to other networks or the internet

### Viewing Your Gateway Configuration

On any VM, you can see your gateway:

```bash
# View routing table
ip route

# Expected output (example from defender on internal network):
# default via 192.168.220.5 dev eth1
# 192.168.220.0/24 dev eth1 proto kernel scope link src 192.168.220.11
```

The line starting with `default via` shows your **default gateway**.

**What this means:**
- `default` = "any destination not in my local network"
- `via 192.168.220.5` = "send to this IP address (the gateway)"
- `dev eth1` = "use this network interface"

### Understanding the Lab Network Topology

In this lab environment, we have multiple networks connected by a gateway:

```
External Network (192.168.210.0/24) - Where attacker VM lives
        |
   Gateway (.5 on each network)
        |
        +--- Internal Network (192.168.220.0/24) - Where defender lives
        |
        +--- DMZ Network (192.168.230.0/24) - Where webserver lives
```

**Key Point:** VMs on different networks (like defender on .220.x and webserver on .230.x) need the gateway to communicate with each other. This is where gateway configuration becomes important - covered in Week 2!

### Gateway Functions (Conceptual)

**Gateway Functions:**
1. **Routing**: Forwards packets between **different networks** (not same-subnet traffic)
2. **NAT (Network Address Translation)**: Can translate between internal and external IPs (Week 2)
3. **Filtering**: Can inspect and filter traffic (gateway firewalls - Week 2)
4. **Logging**: Can log all traffic passing through for monitoring

**Important Networking Principle:** 
- **Same-subnet traffic** uses Layer 2 switching (direct communication)
- **Different-subnet traffic** uses Layer 3 routing (through gateway)

Examples in our lab:
- Attacker (192.168.210.10) → Another VM on 192.168.210.x = **Direct** (same subnet)
- Defender (192.168.220.11) → Webserver (192.168.230.20) = **Through gateway** (different subnets)

### Understanding Routing Decisions

You can see how your VM will route traffic:

```bash
# From any VM, check the routing table
ip route

# Example from defender (internal network):
# default via 192.168.220.5 dev eth1
# 192.168.220.0/24 dev eth1 proto kernel scope link src 192.168.220.11
# 192.168.230.0/24 via 192.168.220.5 dev eth1
# 192.168.210.0/24 via 192.168.220.5 dev eth1
```

**Reading the routing table:**
- First line: "default via 192.168.220.5" = Send all non-local traffic to gateway
- Second line: "192.168.220.0/24 dev eth1" = Direct connection to local network
- Other lines: Specific routes for other networks through gateway

### Gateway vs. Proxy: What's the Difference?

Both gateways and proxies handle network traffic, but they work at different levels:

| Aspect | Gateway | Proxy |
|--------|---------|-------|
| **OSI Layer** | Layer 3 (Network) | Layer 7 (Application) |
| **What it sees** | IP addresses, ports | HTTP URLs, headers, content |
| **Transparency** | Transparent (routing-based) | Can be explicit or transparent |
| **Configuration** | No client config needed | May require client config |
| **Primary Use** | Network routing, connectivity | Content filtering, caching |

**Example:**
- **Gateway**: Routes packets based on IP address (any protocol: HTTP, SSH, DNS, etc.)
- **Proxy**: Understands HTTP and can filter specific URLs or cache web pages

You'll explore proxies in detail in Week 3!

### Why Learn About Gateways?

Understanding gateways is essential for:
- **Troubleshooting**: "Why can't I reach the internet?" often starts with checking the gateway
- **Security**: Gateways are common points for firewalls and monitoring
- **Network Design**: Understanding how traffic flows between networks
- **Attack/Defense**: Attackers look for gateways; defenders monitor them

### Next Steps

- **Week 2 - Firewall Lab**: You'll configure a gateway with NAT and firewall rules hands-on
  - Enable IP forwarding to make the gateway functional
  - Configure NAT to allow internal networks to reach the internet
  - Set up gateway-level firewall rules (FORWARD chain)
  - Test traffic routing between different network segments

This conceptual overview prepares you for those hands-on exercises!

## Checklist

### Core Skills (Required)
- [ ] I can list interfaces and routes with `ip addr` and `ip route`
- [ ] I can see which processes are listening on which ports with `ss -tulpn`
- [ ] I captured HTTP traffic with tcpdump and analyzed the output
- [ ] I built a veth + namespace mini-lab OR used VMs for traffic capture
- [ ] I reconciled nmap scan results with socket listeners
- [ ] I can explain traceroute output and identify network hops
- [ ] I completed VM-based attack/defense scenarios
- [ ] I correlated attacker reconnaissance with defender observations
- [ ] I documented a complete attack timeline with evidence

### Kubernetes Networking (NEW)
- [ ] I understand the Kubernetes networking model (flat network, no NAT)
- [ ] I can create pods and check their IP addresses
- [ ] I understand the difference between pod IPs and service IPs
- [ ] I can create and use ClusterIP services
- [ ] I understand Kubernetes DNS naming
- [ ] I can troubleshoot connectivity issues using debug pods
- [ ] I understand how services load balance across pods

### Optional Learning
- [ ] I understand what a gateway is and its role in networking (conceptual)
- [ ] I can explain the difference between same-subnet and different-subnet routing
- [ ] I understand why the gateway IP changed from .1 to .5 (libvirt conflict)

Commit when done:

```bash
git add .
git commit -m "Complete week01 networking lab"
```
