# VM Setup Guide - DevOps Security Lab

This guide explains how to set up and use the virtual machine environment for the DevOps Security Lab tutorials.

## Prerequisites

### Required Software

1. **libvirt/KVM** (Linux-native virtualization)
   - Ensure libvirt and KVM are installed and configured on your Linux system.
   - You might need to install `qemu-kvm`, `libvirt-daemon-system`, `libvirt-clients`, and `bridge-utils` (package names may vary by distribution).
   - Ensure your user is part of the `libvirt` group: `sudo usermod -aG libvirt $(whoami)`
   - Install the `vagrant-libvirt` plugin: `vagrant plugin install vagrant-libvirt`

2. **Vagrant** (2.3 or later)
   - Download from: https://www.vagrantup.com/downloads
   - Vagrant automates VM creation and provisioning

3. **System Requirements**
   - At least 16 GB RAM (to run multiple VMs simultaneously)
   - At least 50 GB free disk space
   - CPU with virtualization support (Intel VT-x or AMD-V enabled in BIOS)

### Verify Installation

```bash
# Check libvirt service
systemctl is-active libvirtd

# Check vagrant-libvirt plugin
vagrant plugin list

# Check Vagrant
vagrant --version
```

## VM Topology

The lab consists of 10 virtual machines forming a complete attack/defense environment across three network segments:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Host Machine                                │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │         External/Security Network: 192.168.210.0/24               │  │
│  │         (vagrant-security)                                        │  │
│  │                                                                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌───────────┐  ┌──────────┐       │  │
│  │  │ Attacker │  │  Proxy   │  │ LogServer │  │ Gateway  │       │  │
│  │  │  .10     │  │  .21     │  │   .30     │  │  .5      │       │  │
│  │  └──────────┘  └────┬─────┘  └───────────┘  └────┬─────┘       │  │
│  └───────────────────── │────────────────────────────│──────────────┘  │
│                          │                            │                  │
│  ┌───────────────────────│────────┐  ┌───────────────│──────────────┐  │
│  │ Internal Network      │        │  │ DMZ Network   │              │  │
│  │ 192.168.220.0/24      │        │  │ 192.168.230.0/24             │  │
│  │ (vagrant-internal)    │        │  │ (vagrant-dmz)  │             │  │
│  │                       ▼        │  │                ▼             │  │
│  │  ┌──────────┐  ┌──────────┐   │  │  ┌──────────┐  ┌────────┐  │  │
│  │  │ Defender │  │Monitored │   │  │  │Webserver │  │ Proxy  │  │  │
│  │  │  .11     │  │  .40     │   │  │  │  .20     │  │  .21   │  │  │
│  │  └──────────┘  └──────────┘   │  │  ├──────────┤  └────────┘  │  │
│  │             ┌──────────┐       │  │  │  web1-3  │              │  │
│  │             │ Gateway  │       │  │  │.31/.32/.33│             │  │
│  │             │  .5      │       │  │  └──────────┘              │  │
│  │             └──────────┘       │  │             ┌──────────┐   │  │
│  └────────────────────────────────┘  │             │ Gateway  │   │  │
│                                       │             │  .5      │   │  │
│                                       │             └──────────┘   │  │
│                                       └────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

### VM Roles

| VM Name | IP | Role | Used In |
|---------|-----|------|---------|
| **gateway** | 192.168.210.5 / 192.168.220.5 / 192.168.230.5 | Network gateway, NAT, routing, gateway firewall | Week 2, 3 (optional) |
| **attacker** | 192.168.210.10 | Red team operations, port scanning, traffic generation | Week 1, 2, 3, 5, 6 |
| **defender** | 192.168.220.11 | Blue team operations, firewall management, defense | Week 2, 3, 5 |
| **webserver** | 192.168.230.20 | Target web application | Week 2, 3 (basic) |
| **web1** | 192.168.230.31 | Backend server #1 for HAProxy load balancing | Week 3 (advanced) |
| **web2** | 192.168.230.32 | Backend server #2 for HAProxy load balancing | Week 3 (advanced) |
| **web3** | 192.168.230.33 | Backend server #3 for HAProxy load balancing | Week 3 (advanced) |
| **proxy** | 192.168.210.21 | Forward and reverse proxy testing (manual configuration) | Week 3 |
| **logserver** | 192.168.210.30 | SIEM, log collection (ELK stack) | Week 5 |
| **monitored** | 192.168.220.40 | Endpoint monitoring target (Falco, Osquery) | Week 6 |

**Note:** For Week 3 advanced HAProxy exercises, use `web1`, `web2`, `web3` instead of `webserver`. See VM rotation strategy below.

## Getting Started

> **Important:** Some VMs (gateway and proxy) are intentionally NOT pre-configured to preserve the hands-on learning experience. You will configure these services manually as part of the lab exercises. This approach helps you understand the configuration deeply rather than just using pre-configured systems.

### 0. Network Setup (Important)

Before starting the VMs, define the three custom networks used by the lab. This creates the separate subnets that VMs will be assigned to.

```bash
# Define all three networks from the XML files in the repo root
virsh net-define vagrant-security.xml
virsh net-define vagrant-internal.xml
virsh net-define vagrant-dmz.xml

# Start the networks
virsh net-start vagrant-security
virsh net-start vagrant-internal
virsh net-start vagrant-dmz

# Configure them to start automatically on boot
virsh net-autostart vagrant-security
virsh net-autostart vagrant-internal
virsh net-autostart vagrant-dmz

# Verify all three networks are active
virsh net-list
```

### 1. Start All VMs

```bash
cd /path/to/devops-tutorial
vagrant up
```

This will:
- Download the Ubuntu 24.04 base box (~800 MB, one-time)
- Create and provision all 6 VMs
- Install required packages on each VM
- Configure networking

**Note:** First run takes 15-30 minutes depending on internet speed.

### 2. Start Specific VMs

For resource-constrained systems or specific labs, start only required VMs:

```bash
# For network basics and firewall labs (Week 1-2)
vagrant up attacker defender webserver

# For proxy lab (Week 3)
vagrant up attacker proxy webserver

# For SIEM lab (Week 5)
vagrant up attacker defender logserver

# For EDR lab (Week 6)
vagrant up attacker monitored

# For Gateway/NAT lab (Optional, Week 2-3 advanced)
vagrant up gateway attacker defender webserver
```

### 3. Access VMs

#### SSH Access

```bash
# Connect to a VM
vagrant ssh gateway
vagrant ssh attacker
vagrant ssh defender
vagrant ssh webserver
# ... etc

# Run commands without login
vagrant ssh attacker -c "nmap 192.168.220.11"

# Check gateway status
vagrant ssh gateway -c "./gateway-config/status.sh"
```

#### Direct SSH (with keys)

```bash
# Get SSH config
vagrant ssh-config attacker >> ~/.ssh/config

# Now you can SSH directly
ssh attacker
```

### 4. VM Management Commands

```bash
# Check VM status
vagrant status

# Stop all VMs
vagrant halt

# Stop specific VM
vagrant halt attacker

# Restart VM
vagrant reload defender

# Destroy and recreate VM
vagrant destroy -f webserver
vagrant up webserver

# Destroy all VMs
vagrant destroy -f
```

## Common Workflows

### Week 1-2: Network and Firewall Testing

1. Start the required VMs (gateway is needed for cross-subnet communication):
   ```bash
   vagrant up gateway attacker defender webserver
   ```

2. From your host, SSH into attacker:
   ```bash
   vagrant ssh attacker
   ```

3. Run network scans from attacker to defender:
   ```bash
   nmap -sS 192.168.220.11
   ```

4. In another terminal, SSH into defender and monitor:
   ```bash
   vagrant ssh defender
   sudo tcpdump -i eth1 -n
   ```

### Week 3: Proxy Testing

#### Basic Exercises (Squid, Nginx):

1. Start required VMs:
   ```bash
   vagrant up attacker proxy webserver
   ```

2. Configure the proxy services (required - not done automatically):
   ```bash
   vagrant ssh proxy
   cd ~/proxy-config
   ./configure-squid.sh      # Configure and start Squid
   ./configure-nginx.sh      # Configure Nginx reverse proxy
   ```

3. Test forward proxy from attacker:
   ```bash
   vagrant ssh attacker
   curl -x http://192.168.210.21:3128 http://192.168.230.20
   ```

4. Monitor proxy logs:
   ```bash
   vagrant ssh proxy
   sudo tail -f /var/log/squid/access.log
   ```

#### Advanced HAProxy Exercises (Production-grade load balancing):

For advanced exercises, swap VMs to use the backend pool:

1. Halt basic webserver, start backend pool:
   ```bash
   vagrant halt webserver
   vagrant up web1 web2 web3
   ```

2. VMs running for HAProxy exercises:
   - attacker (client)
   - proxy (HAProxy)
   - web1, web2, web3 (backend servers)

3. Follow exercises in `labs/week06-proxy/README.md` starting from Exercise 4.1

4. When done, swap back:
   ```bash
   vagrant halt web1 web2 web3
   vagrant up webserver  # If needed for other labs
   ```

### Week 5: SIEM Lab

1. Start required VMs:
   ```bash
   vagrant up attacker defender logserver
   ```

2. Start ELK stack on logserver:
   ```bash
   vagrant ssh logserver
   cd /opt/elk
   sudo docker-compose up -d
   ```

3. Wait 2-3 minutes, then access Kibana from your host:
   ```
   http://localhost:5601
   ```

4. Generate attack traffic from attacker and observe logs.

### Week 6: EDR Monitoring

1. Start required VMs:
   ```bash
   vagrant up attacker monitored
   ```

2. Deploy Falco on monitored host (see Week 6 README)

3. Generate suspicious activity from attacker

4. Review Falco alerts on monitored host

### Gateway: NAT and Network Routing (Optional)

The gateway VM provides network address translation (NAT) and routing capabilities, demonstrating how traffic flows between networks at Layer 3/4.

1. Start the gateway with other VMs:
   ```bash
   vagrant up gateway attacker webserver
   ```

2. Access the gateway:
   ```bash
   vagrant ssh gateway
   
   # Check gateway status
   ./gateway-config/status.sh
   ```

3. Verify NAT configuration:
   ```bash
   # View NAT rules
   sudo nft list table ip nat
   
   # View firewall rules
   sudo nft list table inet filter
   
   # Check IP forwarding
   sysctl net.ipv4.ip_forward
   ```

4. Test routing and NAT:
   ```bash
   # From attacker VM
   vagrant ssh attacker
   
   # Add route through gateway (example)
   sudo ip route add 10.0.0.0/24 via 192.168.210.5
   
   # On gateway, monitor forwarded traffic
   vagrant ssh gateway
   sudo journalctl -kf | grep GATEWAY_FWD
   ```

5. See [Gateway and NAT Guide](labs/week01-network-basics/GATEWAY-LAB.md) for comprehensive documentation on:
   - Gateway concepts and architecture
   - NAT types (SNAT, DNAT, masquerading)
   - Gateway firewalls vs host firewalls
   - Gateway vs Proxy differences
   - Hands-on scenarios

## Troubleshooting

### VMs won't start

**Problem:** libvirt/KVM errors on `vagrant up`

**Solution:**
```bash
# Check libvirt service is running
systemctl is-active libvirtd

# Ensure virtualization is enabled in BIOS
# (VT-x for Intel, AMD-V for AMD)

# List all VMs managed by libvirt
virsh list --all

# Try with more verbose output
VAGRANT_LOG=info vagrant up
```

### Network connectivity issues

**Problem:** VMs can't reach each other

**Solution:**
```bash
# On each VM, verify network interface
vagrant ssh attacker
ip addr show eth1

# Verify routes
ip route

# Test connectivity
ping -c 3 192.168.220.11

# Restart networking
sudo systemctl restart networking
```

### Out of disk space

**Problem:** `No space left on device`

**Solution:**
```bash
# Clean up unused boxes
vagrant box prune

# Remove old VMs
vagrant destroy -f
virsh list --all
virsh undefine <vm-name> --remove-all-storage

# Clean Docker images on logserver
vagrant ssh logserver
sudo docker system prune -a
```

### Low memory errors

**Problem:** VMs are slow or won't start

**Solution:**
1. Reduce number of running VMs
2. Edit Vagrantfile to reduce memory allocation
3. Close other applications
4. Consider running labs sequentially instead of all at once

```ruby
# In Vagrantfile, change memory for specific VMs:
attacker.vm.provider "libvirt" do |libvirt|
  libvirt.memory = 1024  # Reduce from 2048
end
```

### Port already in use

**Problem:** `Port 8080 is already in use`

**Solution:**
```bash
# Find process using port
lsof -i :8080

# Either kill the process or change port in Vagrantfile
```

## Resource Management Tips

### For 8 GB RAM Systems

Run VMs in groups:

```bash
# Week 1-2 group (requires ~4 GB)
vagrant up attacker defender

# Week 3 basic group (requires ~3.5 GB)
vagrant halt attacker defender
vagrant up attacker proxy webserver

# Week 3 advanced HAProxy (requires ~4 GB)
vagrant halt webserver
vagrant up web1 web2 web3

# Clean up when done with a week
vagrant halt
```

### For 16 GB+ RAM Systems

You can run most VMs simultaneously:

```bash
# Core lab environment (requires ~10 GB)
vagrant up attacker defender webserver proxy monitored
```

### Save VM States

Instead of destroying VMs, save their state:

```bash
# Suspend (saves RAM to disk, quick resume)
vagrant suspend attacker

# Resume
vagrant resume attacker

# Halt (shutdown, slower resume)
vagrant halt defender
vagrant up defender
```

## Network Configuration

### Private Network

The lab uses three segmented virtual networks:

- **`192.168.210.0/24`** (vagrant-security): attacker, proxy, logserver, gateway
- **`192.168.220.0/24`** (vagrant-internal): defender, monitored, gateway
- **`192.168.230.0/24`** (vagrant-dmz): webserver, web1-3, proxy, gateway

These networks are isolated from your host network. VMs communicate across networks through the **gateway** VM. For cross-network exercises (e.g., attacker → defender), ensure the gateway VM is running and routing is enabled.

### Accessing Services from Host

Services are accessible from your host machine via port forwarding:

| Service | VM | Guest Port | Host Port | URL |
|---------|-----|------------|-----------|-----|
| Web Server | webserver | 80 | 8080 | http://localhost:8080 |
| Squid Proxy | proxy | 3128 | 3128 | http://localhost:3128 |
| Elasticsearch | logserver | 9200 | 9200 | http://localhost:9200 |
| Kibana | logserver | 5601 | 5601 | http://localhost:5601 |

### Adding Internet Access (Optional)

If you need VMs to access the internet:

1. Edit Vagrantfile
2. Add this line to a VM definition:
   ```ruby
   config.vm.network "public_network"
   ```
3. Reload the VM: `vagrant reload <vm-name>`

## Security Considerations

### Lab Environment Safety

- ⚠️ **Never expose these VMs to the internet**
- ⚠️ **Don't use these VMs for production**
- ⚠️ **Default credentials are well-known (vagrant/vagrant)**
- ⚠️ **No firewall rules by default (intentional for labs)**

### Best Practices

1. **Snapshots:** Take snapshots before major changes
   ```bash
   vagrant snapshot save <vm-name> <snapshot-name>
   vagrant snapshot restore <vm-name> <snapshot-name>
   ```

2. **Isolated Network:** Keep VMs on host-only network

3. **Regular Updates:** Rebuild VMs periodically
   ```bash
   vagrant destroy -f
   vagrant up
   ```

4. **Clean up:** Remove VMs when not in use
   ```bash
   vagrant halt
   ```

## Next Steps

1. Start with basic VMs: `vagrant up attacker defender`
2. Follow [Week 1 - Network Basics](labs/week01-network-basics/README.md)
3. Progress through each week, starting additional VMs as needed
4. Refer back to this guide for VM management

## Additional Resources

- [Vagrant Documentation](https://www.vagrantup.com/docs)
- [libvirt/vagrant-libvirt](https://github.com/vagrant-libvirt/vagrant-libvirt)
- [Vagrant Networking](https://www.vagrantup.com/docs/networking)

## Getting Help

If you encounter issues:

1. Check this guide's troubleshooting section
2. Review Vagrant logs: `VAGRANT_LOG=debug vagrant up`
3. Check VM logs: `vagrant ssh <vm> -c "journalctl -xe"`
4. Open an issue on GitHub with:
   - Vagrant version
   - libvirt/KVM version
   - Host OS
   - Error messages
   - Output of `vagrant status`
