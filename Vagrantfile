# -*- mode: ruby -*- 
# vi: set ft=ruby : 

ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
ENV['LIBVIRT_DEFAULT_URI'] = 'qemu:///system'

Vagrant.configure("2") do |config|
  # Match the working configuration's box
  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_check_update = false
  
  config.ssh.insert_key = false
  
  # Disable synced folder
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Define VMs with multiple network support
  # Network topology:
  # - vagrant-security (192.168.210.0/24): External/DMZ network (has NAT to internet)
  # - vagrant-internal (192.168.220.0/24): Internal protected network
  # - vagrant-dmz (192.168.230.0/24): DMZ for web services
  
  # FIXED: Changed gateway IPs to avoid conflict with libvirt bridge IPs
  
  servers = [
    { name: "gateway",    
      networks: [
        { ip: "192.168.210.5", network: "vagrant-security" },
        { ip: "192.168.220.5", network: "vagrant-internal" },
        { ip: "192.168.230.5", network: "vagrant-dmz" }
      ],
      memory: 1024, cpu: 1 },
    { name: "attacker",   
      networks: [{ ip: "192.168.210.10", network: "vagrant-security" }],
      memory: 2048, cpu: 2 },
    { name: "defender",   
      networks: [{ ip: "192.168.220.11", network: "vagrant-internal" }],
      memory: 2048, cpu: 2 },
    { name: "webserver",  
      networks: [{ ip: "192.168.230.20", network: "vagrant-dmz" }],
      memory: 1024, cpu: 1 },
    { name: "web1",  
      networks: [{ ip: "192.168.230.31", network: "vagrant-dmz" }],
      memory: 512, cpu: 1 },
    { name: "web2",  
      networks: [{ ip: "192.168.230.32", network: "vagrant-dmz" }],
      memory: 512, cpu: 1 },
    { name: "web3",  
      networks: [{ ip: "192.168.230.33", network: "vagrant-dmz" }],
      memory: 512, cpu: 1 },
    { name: "proxy",      
      networks: [
        { ip: "192.168.210.21", network: "vagrant-security" },
        { ip: "192.168.230.21", network: "vagrant-dmz" }
      ],
      memory: 1024, cpu: 1 },
    { name: "logserver",  
      networks: [{ ip: "192.168.210.30", network: "vagrant-security" }],
      memory: 4096, cpu: 2 },
    { name: "monitored",  
      networks: [{ ip: "192.168.220.40", network: "vagrant-internal" }],
      memory: 2048, cpu: 2 }
  ]
  
  servers.each do |opts|
    config.vm.define opts[:name] do |vm|
      vm.vm.hostname = opts[:name]

      # Configure network interfaces based on VM definition
      opts[:networks].each_with_index do |net, index|
        vm.vm.network :private_network,
          ip: net[:ip],
          libvirt__network_name: net[:network],
          libvirt__always_destroy: false
      end
      
      vm.vm.provider "libvirt" do |libvirt|
        libvirt.memory = opts[:memory]
        libvirt.cpus = opts[:cpu]
        libvirt.driver = "kvm"
        libvirt.graphics_type = "none"
        libvirt.uri = 'qemu:///system'
        libvirt.machine_type = 'q35'
      end

      # Port forwards
      if opts[:name] == "webserver"
        vm.vm.network "forwarded_port", guest: 80, host: 8080
      elsif opts[:name] == "logserver"
        vm.vm.network "forwarded_port", guest: 9200, host: 9200  # Elasticsearch
        vm.vm.network "forwarded_port", guest: 5601, host: 5601  # Kibana
      end
      
      # Provisioning
      vm.vm.provision "shell", inline: <<-SHELL
      set -e
      # FIXED: Set frontend to noninteractive globally to stop prompts
      export DEBIAN_FRONTEND=noninteractive
      
      # Configure SSH directory
      install -d -m 700 -o vagrant -g vagrant /home/vagrant/.ssh
      touch /home/vagrant/.ssh/authorized_keys
      chmod 600 /home/vagrant/.ssh/authorized_keys
      chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
      
      # Common tools
      apt-get update -y
      apt-get install -y vim git htop tmux jq net-tools iputils-ping
      
      # VM specific tools
      if [ "#{opts[:name]}" = "gateway" ]; then
        # Install routing and NAT tools
        apt-get install -y nftables iptables-persistent tcpdump traceroute iproute2 conntrack curl
        
        # NOTE: Gateway configuration is intentionally left for hands-on learning in Week 2
        # This preserves the learning experience of configuring NAT and firewall rules manually
        
        # Create example nftables configuration file (not applied automatically)
        cat > /etc/nftables-gateway.conf.example <<'EOF_NFTABLES'
# flush ruleset: Clears all existing nftables rules before loading this configuration.
flush ruleset

# NAT Configuration for Gateway
table ip nat {
  # SNAT/Masquerading for outbound traffic
  chain postrouting {
    type nat hook postrouting priority 100; policy accept;
    # Masquerade traffic from internal networks going to external
    # FIXED: Use actual external interface (the one on vagrant-security network)
    # Determine this with: ip -o addr show | grep "192.168.210.5" | awk '{print $2}'
    ip saddr 192.168.220.0/24 oifname "EXTERNAL_IF" masquerade
    ip saddr 192.168.230.0/24 oifname "EXTERNAL_IF" masquerade
  }
  
  # DNAT for inbound traffic (port forwarding example)
  chain prerouting {
    type nat hook prerouting priority -100; policy accept;
    # Example: Forward external port 8080 to webserver:80
    # iifname "EXTERNAL_IF" tcp dport 8080 dnat to 192.168.230.20:80
  }
}

# Firewall rules for gateway
table inet filter {
  chain input {
    type filter hook input priority 0; policy accept;
    # Accept established connections
    ct state { established, related } accept
    # Accept loopback
    iif lo accept
    # Accept ICMP (ping)
    ip protocol icmp accept
    # Accept SSH
    tcp dport 22 accept
  }
  
  # FORWARD chain: Controls traffic THROUGH the gateway
  chain forward {
    type filter hook forward priority 0; policy accept;
    # Accept established/related connections
    ct state { established, related } accept
    
    # Allow internal network to reach DMZ
    ip saddr 192.168.220.0/24 ip daddr 192.168.230.0/24 accept
    # Allow DMZ to reach external (for updates, etc.)
    ip saddr 192.168.230.0/24 oifname "EXTERNAL_IF" accept
    # FIXED: Allow internal network to reach internet
    ip saddr 192.168.220.0/24 oifname "EXTERNAL_IF" accept
    
    # Log forwarded traffic for monitoring
    counter log prefix "GATEWAY_FWD: " accept
  }
  
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
EOF_NFTABLES
        
        mkdir -p /home/vagrant/gateway-config
        chown vagrant:vagrant /home/vagrant/gateway-config
        
        # Create README for gateway configuration
        cat > /home/vagrant/gateway-config/README.txt <<'READMEEOF'
=== Gateway Configuration Notes ===

This gateway VM is intentionally NOT pre-configured to preserve the hands-on
learning experience. You will configure NAT, IP forwarding, and firewall rules
manually as part of Week 2 exercises.

What's installed:
- nftables, iptables-persistent, tcpdump, traceroute, iproute2, conntrack

Example configuration file:
- /etc/nftables-gateway.conf.example (NOT applied automatically)

Helper scripts available in this directory:
- status.sh: Check gateway status
- enable-nat.sh: Helper to enable NAT for a network
- add-route.sh: Helper to add static routes
- test-forwarding.sh: Check IP forwarding status

For complete gateway setup instructions, see:
- labs/week05-firewall/README.md (Week 2 Lab - Gateway Firewall section)

Next steps:
1. Complete Week 1 to understand basic networking concepts
2. In Week 2, you'll configure this gateway with NAT and firewall rules
READMEEOF
        
        # Create helper script for gateway management
        cat > /home/vagrant/gateway-config/status.sh <<'SCRIPTEOF'
#!/bin/bash
echo "=== Gateway Status ==="
echo ""
echo "IP Forwarding Status:"
sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding
echo ""
echo "Network Interfaces:"
ip addr show | grep -E "^[0-9]|inet "
echo ""
echo "Routing Table:"
ip route
echo ""
echo "NAT Rules:"
sudo nft list table ip nat 2>/dev/null || echo "No NAT table configured"
echo ""
echo "Filter Rules:"
sudo nft list table inet filter 2>/dev/null || echo "No filter table configured"
echo ""
echo "Connection Tracking (sample):"
sudo conntrack -L 2>/dev/null | head -10 || echo "conntrack not available"
SCRIPTEOF
        chmod +x /home/vagrant/gateway-config/status.sh
        chown vagrant:vagrant /home/vagrant/gateway-config/status.sh
        
        # Create hands-on configuration scripts
        cat > /home/vagrant/gateway-config/enable-nat.sh <<'SCRIPTEOF'
#!/bin/bash
# HANDS-ON: Enable NAT for a specific source network
# Usage: ./enable-nat.sh <source_network> <output_interface>
# Example: ./enable-nat.sh 192.168.220.0/24 eth1

SOURCE_NET="${1:-192.168.220.0/24}"
OUT_IFACE="${2:-eth1}"

echo "Enabling SNAT/Masquerading for $SOURCE_NET on $OUT_IFACE"
sudo nft add rule ip nat postrouting ip saddr $SOURCE_NET oifname "$OUT_IFACE" masquerade
sudo nft list table ip nat
SCRIPTEOF
        chmod +x /home/vagrant/gateway-config/enable-nat.sh
        chown vagrant:vagrant /home/vagrant/gateway-config/enable-nat.sh
        
        cat > /home/vagrant/gateway-config/add-route.sh <<'SCRIPTEOF'
#!/bin/bash
# HANDS-ON: Add a static route
# Usage: ./add-route.sh <destination_network> <gateway_ip>
# Example: ./add-route.sh 192.168.240.0/24 192.168.220.254

DEST_NET="$1"
GATEWAY="$2"

if [ -z "$DEST_NET" ] || [ -z "$GATEWAY" ]; then
  echo "Usage: $0 <destination_network> <gateway_ip>"
  echo "Example: $0 192.168.240.0/24 192.168.220.254"
  exit 1
fi

echo "Adding route: $DEST_NET via $GATEWAY"
sudo ip route add $DEST_NET via $GATEWAY
ip route show
SCRIPTEOF
        chmod +x /home/vagrant/gateway-config/add-route.sh
        chown vagrant:vagrant /home/vagrant/gateway-config/add-route.sh
        
        cat > /home/vagrant/gateway-config/test-forwarding.sh <<'SCRIPTEOF'
#!/bin/bash
# HANDS-ON: Test if IP forwarding is working
echo "=== Testing IP Forwarding ==="
echo ""
echo "1. Current IP forwarding status:"
sysctl net.ipv4.ip_forward
echo ""
echo "2. Testing with sysctl:"
echo "   To enable:  sudo sysctl -w net.ipv4.ip_forward=1"
echo "   To disable: sudo sysctl -w net.ipv4.ip_forward=0"
echo ""
echo "3. Make it persistent by editing /etc/sysctl.conf:"
echo "   net.ipv4.ip_forward=1"
echo ""
echo "4. Current forwarding statistics:"
cat /proc/sys/net/ipv4/ip_forward
SCRIPTEOF
        chmod +x /home/vagrant/gateway-config/test-forwarding.sh
        chown vagrant:vagrant /home/vagrant/gateway-config/test-forwarding.sh
        
      elif [ "#{opts[:name]}" = "attacker" ]; then
        # FIXED: Pre-answer the wireshark question so installation doesn't hang
        echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
        
        apt-get install -y nmap tcpdump wireshark-common tshark curl wget netcat-openbsd dnsutils
        mkdir -p /home/vagrant/attack-tools
        chown vagrant:vagrant /home/vagrant/attack-tools
      elif [ "#{opts[:name]}" = "defender" ]; then
        apt-get install -y nftables iptables-persistent fail2ban tcpdump python3-pip
        systemctl enable nftables
        systemctl start nftables
        mkdir -p /home/vagrant/defense-tools
        chown vagrant:vagrant /home/vagrant/defense-tools
        
        # FIXED: Configure default route through gateway (changed to .5)
        ip route del default || true
        ip route add default via 192.168.220.5
        # Add route to DMZ through gateway
        ip route add 192.168.230.0/24 via 192.168.220.5 || true
        # Add route to external network through gateway
        ip route add 192.168.210.0/24 via 192.168.220.5 || true
        
        # FIXED: Make routes persistent
        cat > /etc/network/if-up.d/custom-routes <<'ROUTESEOF'
#!/bin/bash
# Custom routes for defender
if [ "$IFACE" = "eth1" ]; then
  ip route add default via 192.168.220.5 || true
  ip route add 192.168.230.0/24 via 192.168.220.5 || true
  ip route add 192.168.210.0/24 via 192.168.220.5 || true
fi
ROUTESEOF
        chmod +x /etc/network/if-up.d/custom-routes
        
      elif [ "#{opts[:name]}" = "webserver" ]; then
        apt-get install -y nginx
        cat > /var/www/html/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head><title>DevOps Lab Web Server</title></head>
<body>
<h1>DevOps Security Lab</h1>
<p>Server IP: 192.168.230.20 (DMZ)</p>
<p>Gateway: 192.168.230.5</p>
<p>Server: Primary Web Server</p>
</body>
</html>
EOF
        systemctl restart nginx
        systemctl enable nginx
        
        # FIXED: Configure default route through gateway (changed to .5)
        ip route del default || true
        ip route add default via 192.168.230.5
        # Add route to internal network through gateway
        ip route add 192.168.220.0/24 via 192.168.230.5 || true
        # Add route to external network through gateway
        ip route add 192.168.210.0/24 via 192.168.230.5 || true
        
        # FIXED: Make routes persistent
        cat > /etc/network/if-up.d/custom-routes <<'ROUTESEOF'
#!/bin/bash
# Custom routes for webserver
if [ "$IFACE" = "eth1" ]; then
  ip route add default via 192.168.230.5 || true
  ip route add 192.168.220.0/24 via 192.168.230.5 || true
  ip route add 192.168.210.0/24 via 192.168.230.5 || true
fi
ROUTESEOF
        chmod +x /etc/network/if-up.d/custom-routes
        
      elif [ "#{opts[:name]}" = "web1" ] || [ "#{opts[:name]}" = "web2" ] || [ "#{opts[:name]}" = "web3" ]; then
        # Backend web servers for HAProxy load balancing exercises
        apt-get install -y nginx
        
        # Get server number from hostname
        SERVER_NUM=\${HOSTNAME: -1}
        SERVER_IP=$(ip addr show eth1 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        
        cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Backend Web Server \${SERVER_NUM}</title></head>
<body>
<h1>Backend Server \${SERVER_NUM}</h1>
<p>Server IP: \${SERVER_IP} (DMZ)</p>
<p>Hostname: \${HOSTNAME}</p>
<p>This is backend server #\${SERVER_NUM} for HAProxy load balancing</p>
<hr>
<p>Request served at: $(date)</p>
</body>
</html>
EOF
        
        # Add API endpoint for health checks
        mkdir -p /var/www/html/api
        cat > /var/www/html/api/health <<EOF
{"status": "healthy", "server": "\${HOSTNAME}", "ip": "\${SERVER_IP}"}
EOF
        
        # Add endpoint that returns server ID
        cat > /var/www/html/api/info <<EOF
{"server": "\${HOSTNAME}", "ip": "\${SERVER_IP}", "number": "\${SERVER_NUM}"}
EOF
        
        systemctl restart nginx
        systemctl enable nginx
        
        # Configure routing
        ip route del default || true
        ip route add default via 192.168.230.5
        ip route add 192.168.220.0/24 via 192.168.230.5 || true
        ip route add 192.168.210.0/24 via 192.168.230.5 || true
        
        # Make routes persistent
        cat > /etc/network/if-up.d/custom-routes <<'ROUTESEOF'
#!/bin/bash
# Custom routes for backend web servers
if [ "$IFACE" = "eth1" ]; then
  ip route add default via 192.168.230.5 || true
  ip route add 192.168.220.0/24 via 192.168.230.5 || true
  ip route add 192.168.210.0/24 via 192.168.230.5 || true
fi
ROUTESEOF
        chmod +x /etc/network/if-up.d/custom-routes
        
      elif [ "#{opts[:name]}" = "proxy" ]; then
        # Proxy sits between external and DMZ networks
        apt-get install -y squid nginx
        
        # NOTE: Proxy configuration is intentionally left for hands-on learning in Week 3
        # This preserves the learning experience of configuring Squid and Nginx manually
        
        # Stop services (will be configured manually in Week 3)
        systemctl stop squid
        systemctl disable squid
        
        # Create example Squid configuration file (not applied automatically)
        cat > /etc/squid/squid.conf.example <<'SQUIDEOF'
http_port 3128

# ACLs for lab networks
acl lab_security_net src 192.168.210.0/24  # External/Security network (attacker, proxy)
acl lab_dmz_net src 192.168.230.0/24       # DMZ network (webserver)
acl lab_internal_net src 192.168.220.0/24  # Internal network (defender, logserver)
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 443         # https
acl CONNECT method CONNECT

# Deny requests to certain unsafe ports
http_access deny !Safe_ports
# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Allow access from lab networks
http_access allow lab_security_net
http_access allow lab_dmz_net
http_access allow lab_internal_net

# Deny all other access
http_access deny all

# Access log
access_log /var/log/squid/access.log squid
SQUIDEOF
        
        # Create example Nginx reverse proxy configuration (not applied automatically)
        cat > /etc/nginx/sites-available/reverse-proxy.example <<'NGINXEOF'
server {
    listen 8080;
    server_name _;
    
    access_log /var/log/nginx/reverse-proxy-access.log;
    error_log /var/log/nginx/reverse-proxy-error.log;
    
    location / {
        proxy_pass http://192.168.230.20;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Log proxy details
        add_header X-Proxy-Server "lab-proxy" always;
    }
    
    location /admin {
        # Restrict admin to defender only
        allow 192.168.210.11;
        deny all;
        
        proxy_pass http://192.168.230.20/admin;
    }
}
NGINXEOF
        
        mkdir -p /home/vagrant/proxy-config
        chown vagrant:vagrant /home/vagrant/proxy-config
        
        # Create README for proxy configuration
        cat > /home/vagrant/proxy-config/README.txt <<'READMEEOF'
=== Proxy Configuration Notes ===

This proxy VM is intentionally NOT pre-configured to preserve the hands-on
learning experience. You will configure Squid (forward proxy) and Nginx 
(reverse proxy) manually as part of Week 3 exercises.

What's installed:
- Squid (forward proxy) - installed but not configured
- Nginx (reverse proxy) - installed but not configured

Example configuration files:
- /etc/squid/squid.conf.example (NOT applied automatically)
- /etc/nginx/sites-available/reverse-proxy.example (NOT applied automatically)

Helper scripts available in this directory:
- status.sh: Check proxy services status
- configure-squid.sh: Apply Squid configuration
- configure-nginx.sh: Apply Nginx reverse proxy configuration
- test-proxy.sh: Test proxy functionality

For complete proxy setup instructions, see:
- labs/week06-proxy/README.md (Week 3 Lab)

Next steps:
1. Complete Week 1 and Week 2 to understand networking and firewall concepts
2. In Week 3, you'll configure Squid and Nginx proxies manually
READMEEOF
        
        # Create helper script for proxy status
        cat > /home/vagrant/proxy-config/status.sh <<'SCRIPTEOF'
#!/bin/bash
echo "=== Proxy Services Status ==="
echo ""
echo "Squid Forward Proxy:"
sudo systemctl status squid --no-pager || echo "Squid not running"
echo ""
echo "Nginx Web Server/Reverse Proxy:"
sudo systemctl status nginx --no-pager || echo "Nginx not running"
echo ""
echo "Network Interfaces:"
ip addr show | grep -E "^[0-9]|inet "
echo ""
echo "Routing Table:"
ip route
echo ""
echo "Listening Ports:"
ss -tulpn | grep -E "(squid|nginx|3128|8080|80)"
SCRIPTEOF
        chmod +x /home/vagrant/proxy-config/status.sh
        chown vagrant:vagrant /home/vagrant/proxy-config/status.sh
        
        # Create helper script to configure Squid
        cat > /home/vagrant/proxy-config/configure-squid.sh <<'SCRIPTEOF'
#!/bin/bash
# HANDS-ON: Apply Squid configuration
echo "Configuring Squid forward proxy..."

# Copy example configuration to active config
sudo cp /etc/squid/squid.conf.example /etc/squid/squid.conf

# Test configuration
echo "Testing Squid configuration..."
if sudo squid -k parse; then
  echo "Configuration valid. Starting Squid..."
  sudo systemctl enable squid
  sudo systemctl restart squid
  sudo systemctl status squid --no-pager
  echo ""
  echo "Squid is now running on port 3128"
  echo "Test with: curl -x http://192.168.210.21:3128 http://192.168.230.20"
else
  echo "Configuration has errors. Please fix /etc/squid/squid.conf"
  exit 1
fi
SCRIPTEOF
        chmod +x /home/vagrant/proxy-config/configure-squid.sh
        chown vagrant:vagrant /home/vagrant/proxy-config/configure-squid.sh
        
        # Create helper script to configure Nginx reverse proxy
        cat > /home/vagrant/proxy-config/configure-nginx.sh <<'SCRIPTEOF'
#!/bin/bash
# HANDS-ON: Apply Nginx reverse proxy configuration
echo "Configuring Nginx reverse proxy..."

# Copy example configuration
sudo cp /etc/nginx/sites-available/reverse-proxy.example /etc/nginx/sites-available/reverse-proxy

# Enable the site
sudo ln -sf /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/reverse-proxy

# Test configuration
echo "Testing Nginx configuration..."
if sudo nginx -t; then
  echo "Configuration valid. Reloading Nginx..."
  sudo systemctl reload nginx
  sudo systemctl status nginx --no-pager
  echo ""
  echo "Nginx reverse proxy is now running on port 8080"
  echo "Test with: curl http://192.168.210.21:8080"
else
  echo "Configuration has errors. Please fix /etc/nginx/sites-available/reverse-proxy"
  exit 1
fi
SCRIPTEOF
        chmod +x /home/vagrant/proxy-config/configure-nginx.sh
        chown vagrant:vagrant /home/vagrant/proxy-config/configure-nginx.sh
        
        # Create test script
        cat > /home/vagrant/proxy-config/test-proxy.sh <<'SCRIPTEOF'
#!/bin/bash
echo "=== Testing Proxy Configuration ==="
echo ""
echo "1. Testing Squid Forward Proxy (port 3128):"
if sudo systemctl is-active --quiet squid; then
  echo "   Squid is running"
  echo "   Testing connection..."
  curl -s -o /dev/null -w "   HTTP Status: %{http_code}\n" -x http://localhost:3128 http://192.168.230.20 || echo "   Failed to connect"
else
  echo "   Squid is not running. Run ./configure-squid.sh first"
fi
echo ""
echo "2. Testing Nginx Reverse Proxy (port 8080):"
if sudo systemctl is-active --quiet nginx; then
  echo "   Nginx is running"
  if [ -f /etc/nginx/sites-enabled/reverse-proxy ]; then
    echo "   Reverse proxy is configured"
    echo "   Testing connection..."
    curl -s -o /dev/null -w "   HTTP Status: %{http_code}\n" http://localhost:8080 || echo "   Failed to connect"
  else
    echo "   Reverse proxy not configured. Run ./configure-nginx.sh first"
  fi
else
  echo "   Nginx is not running"
fi
echo ""
echo "3. View Squid logs:"
echo "   sudo tail -f /var/log/squid/access.log"
echo ""
echo "4. View Nginx logs:"
echo "   sudo tail -f /var/log/nginx/reverse-proxy-access.log"
SCRIPTEOF
        chmod +x /home/vagrant/proxy-config/test-proxy.sh
        chown vagrant:vagrant /home/vagrant/proxy-config/test-proxy.sh
        
        # FIXED: Configure routing for proxy (changed to .5)
        ip route add 192.168.220.0/24 via 192.168.230.5 || true
        ip route add default via 192.168.210.1 || true
        
      elif [ "#{opts[:name]}" = "logserver" ]; then
        # Logserver is on vagrant-security network which has NAT to internet
        # No special routing needed - default route provides internet access
        # (vagrant-security network has libvirt NAT configured)
        
        # Install Docker and docker-compose for ELK stack
        apt-get install -y docker.io docker-compose curl
        
        # Enable and start Docker
        systemctl enable docker
        systemctl start docker
        usermod -aG docker vagrant
        
        # Create docker-compose for ELK stack
        mkdir -p /opt/elk
        cat > /opt/elk/docker-compose.yml <<'ELKEOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - esdata:/usr/share/elasticsearch/data
    networks:
      - elk

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch
    networks:
      - elk

volumes:
  esdata:

networks:
  elk:
    driver: bridge
ELKEOF
        
        # Note: Don't start automatically to save resources
        # Users can start with: cd /opt/elk && docker-compose up -d
        
        echo "Log Server VM ready"
        echo "To start ELK stack: cd /opt/elk && sudo docker-compose up -d"
        echo "Elasticsearch: http://192.168.210.30:9200"
        echo "Kibana: http://192.168.210.30:5601"
        
      elif [ "#{opts[:name]}" = "monitored" ]; then
        # FIXED: Internal network VMs route through gateway (changed to .5)
        ip route del default || true
        ip route add default via 192.168.220.5
        ip route add 192.168.230.0/24 via 192.168.220.5 || true
        ip route add 192.168.210.0/24 via 192.168.220.5 || true
        
        # FIXED: Make routes persistent
        cat > /etc/network/if-up.d/custom-routes <<'ROUTESEOF'
#!/bin/bash
# Custom routes for internal VMs
if [ "$IFACE" = "eth1" ]; then
  ip route add default via 192.168.220.5 || true
  ip route add 192.168.230.0/24 via 192.168.220.5 || true
  ip route add 192.168.210.0/24 via 192.168.220.5 || true
fi
ROUTESEOF
        chmod +x /etc/network/if-up.d/custom-routes
      fi

      echo "VM #{opts[:name]} provisioned successfully"
      SHELL
    end
  end
end
