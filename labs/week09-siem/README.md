# Week 5 – SIEM / Log Shipping Lab

## Objectives

- Collect system logs with Filebeat
- Ship logs to Elasticsearch or another SIEM
- Explore indices and queries
- Build detections with pipelines, enrichments, and adversary-style test events
- Deploy distributed logging across multiple VMs
- Correlate attack activity across attacker and defender logs
- Build real-time detection rules for multi-host attacks

## Estimated Time

⏱️ **2.5-3 hours** (including VM setup and ELK stack deployment)

This lab is comprehensive and includes:
- VM setup and ELK stack deployment (~40-45 minutes, includes 2-3 minute wait for services)
- Filebeat configuration and log shipping (~30-40 minutes)
- Kibana queries and visualization (~30-40 minutes)
- Detection rules and correlation exercises (~50-55 minutes)

**Note:** ELK stack requires 2-3 minutes to fully start. Use this time to review documentation.

## VM Setup for This Lab

Start the required VMs:
```bash
cd /path/to/devops-tutorial
vagrant up attacker defender logserver
```

**VM Roles in This Lab:**
- **logserver** (192.168.210.30) - **PRIMARY FOCUS**: Hosts ELK stack for centralized log collection and analysis
- **attacker** (192.168.210.10) - Generate attack traffic that creates logs to analyze
- **defender** (192.168.220.11) - Generate defensive logs and ship them to logserver

**Lab Flow:**
1. Deploy ELK stack on **logserver**
2. Configure Filebeat on **defender** and **attacker** to ship logs to **logserver**
3. Generate activity on **attacker** and **defender**
4. Query and analyze logs in Kibana on **logserver**
5. Build detection rules based on observed patterns

See [VM Setup Guide](../../VM-SETUP.md) for detailed instructions.

## Prerequisites

Before starting the lab exercises, ensure the ELK stack is set up on the logserver VM:

- **Automatic Setup**: When you run `vagrant up logserver`, Docker, docker-compose, and the ELK stack configuration are automatically installed.
- **Manual Start Required**: The ELK stack does NOT start automatically to save resources. You must start it manually (see Task 1 below).
- **Troubleshooting**: If you encounter issues, see [ELK Setup Guide](ELK-SETUP.md) for detailed installation and troubleshooting instructions.

## Tasks

### 1. Start ELK Stack on Log Server

**Note**: The ELK stack (/opt/elk directory and docker-compose.yml) is automatically created when you provision the logserver VM with `vagrant up logserver`. You just need to start the services.

1. On logserver VM, start Elasticsearch and Kibana:

   ```bash
   vagrant ssh logserver
   
   # Start ELK stack
   cd /opt/elk
   sudo docker-compose up -d
   
   # Wait for services to start (2-3 minutes)
   echo "Waiting for Elasticsearch..."
   until curl -s http://localhost:9200 > /dev/null; do
       sleep 5
       echo -n "."
   done
   echo "Elasticsearch is ready!"
   
   # Verify Kibana is running
   curl -I http://localhost:5601
   ```

2. From your host machine, access Kibana:
   - Open browser: http://localhost:5601
   - Wait for Kibana to initialize

   Expected: Kibana welcome screen appears.
   
   **Troubleshooting**: If ELK stack doesn't start or you can't access Kibana, see [ELK Setup Guide](ELK-SETUP.md) for detailed troubleshooting steps.

### 2. Configure Multi-Host Log Collection

**Install and configure Filebeat on defender VM:**

1. Install Filebeat on defender:

   ```bash
   vagrant ssh defender
   
   # Download and install Filebeat
   curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.0-amd64.deb
   sudo dpkg -i filebeat-8.11.0-amd64.deb
   ```

2. Configure Filebeat to send logs to logserver:

   ```bash
   vagrant ssh defender
   
   # Backup original config
   sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak
   
   # Create new configuration
   sudo tee /etc/filebeat/filebeat.yml > /dev/null <<'EOF'
   filebeat.inputs:
   - type: log
     enabled: true
     paths:
       - /var/log/auth.log
       - /var/log/syslog
     fields:
       host_role: defender
       lab_name: devops-security
   
   # Enable system module
   filebeat.modules:
   - module: system
     syslog:
       enabled: true
     auth:
       enabled: true
   
   # Output to Elasticsearch
   output.elasticsearch:
     hosts: ["192.168.210.30:9200"]
   
   # Kibana endpoint
   setup.kibana:
     host: "192.168.210.30:5601"
   
   # Logging
   logging.level: info
   logging.to_files: true
   logging.files:
     path: /var/log/filebeat
     name: filebeat
     keepfiles: 7
   EOF
   
   # Enable and start Filebeat
   sudo filebeat modules enable system
   sudo systemctl enable filebeat
   sudo systemctl start filebeat
   
   # Check status
   sudo systemctl status filebeat
   ```

3. Install Filebeat on attacker VM (to collect attacker logs too):

   ```bash
   vagrant ssh attacker
   
   # Install Filebeat
   curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.11.0-amd64.deb
   sudo dpkg -i filebeat-8.11.0-amd64.deb
   
   # Configure with attacker role
   sudo tee /etc/filebeat/filebeat.yml > /dev/null <<'EOF'
   filebeat.inputs:
   - type: log
     enabled: true
     paths:
       - /var/log/auth.log
       - /var/log/syslog
       - /home/vagrant/*.log
     fields:
       host_role: attacker
       lab_name: devops-security
   
   filebeat.modules:
   - module: system
     syslog:
       enabled: true
     auth:
       enabled: true
   
   output.elasticsearch:
     hosts: ["192.168.210.30:9200"]
   
   setup.kibana:
     host: "192.168.210.30:5601"
   
   logging.level: info
   EOF
   
   sudo filebeat modules enable system
   sudo systemctl enable filebeat
   sudo systemctl start filebeat
   ```

4. Verify logs are flowing:

   ```bash
   # On logserver
   vagrant ssh logserver
   
   # Check indices
   curl http://localhost:9200/_cat/indices?v
   
   # Should see filebeat-* indices
   # Check document count
   curl http://localhost:9200/filebeat-*/_count
   ```

   Expected: See indices with green/yellow status and document count > 0.

### 3. Generate Attack Traffic and Observe in SIEM

1. From attacker, simulate SSH brute force:

   ```bash
   vagrant ssh attacker
   
   # Create a script to attempt SSH logins
   cat > /tmp/brute_force_sim.sh <<'EOF'
   #!/bin/bash
   TARGET="192.168.220.11"
   
   echo "Starting simulated SSH brute force against $TARGET"
   echo "This is for educational purposes only in a lab environment"
   
   for i in {1..20}; do
       # Try invalid users
       sshpass -p 'wrongpass' ssh -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
           "fakeuser$i@$TARGET" "whoami" 2>&1 | grep -i "denied\|refused\|failed" | head -1
       sleep 1
   done
   
   echo "Brute force simulation complete"
   EOF
   
   chmod +x /tmp/brute_force_sim.sh
   
   # Install sshpass if needed
   sudo apt-get update && sudo apt-get install -y sshpass
   
   # Run the simulation
   /tmp/brute_force_sim.sh | tee /home/vagrant/brute_force.log
   ```

2. On defender, check auth logs:

   ```bash
   vagrant ssh defender
   
   # View failed SSH attempts
   sudo grep "Failed password" /var/log/auth.log | tail -20
   
   # Count failures from attacker IP
   sudo grep "Failed password" /var/log/auth.log | grep "192.168.210.10" | wc -l
   ```

3. In Kibana (http://localhost:5601), create detection:

   - Go to **Discover**
   - Look for events with:
     - `host_role: defender`
     - `event.action: failed*` or search for "Failed password"
     - `source.ip: 192.168.210.10`
   
   - Create a query:
     ```
     host_role:defender AND (message:"Failed password" OR event.action:*failed*)
     ```

4. **Create a detection rule in Kibana:**

   - Go to **Security** → **Rules** → **Create Rule**
   - Rule type: Custom query
   - Query:
     ```
     host_role:defender AND message:"Failed password" AND source.ip:192.168.210.10
     ```
   - Threshold: 10 events in 5 minutes
   - Actions: Create an alert

5. **Run port scan and observe:**

   ```bash
   vagrant ssh attacker
   
   # Port scan defender
   sudo nmap -sS -p 1-1000 192.168.220.11 | tee /home/vagrant/nmap_scan.log
   
   # Wait 30 seconds for logs to process
   sleep 30
   ```

   In Kibana:
   - Search for: `host_role:defender AND destination.port:*`
   - Look for multiple connection attempts from 192.168.210.10
   - Create visualization showing top source IPs and destination ports

6. **Correlating Network Traffic with SIEM Logs**

   The most powerful security analysis combines real-time network monitoring with historical log analysis:

   **Capture Network Traffic During Attack:**
   ```bash
   vagrant ssh defender
   
   # Start packet capture before the attack
   # We save the process ID to cleanly terminate the specific tcpdump instance later
   sudo tcpdump -i eth1 -w /tmp/attack-traffic.pcap 'src 192.168.210.10' &
   TCPDUMP_PID=$!  # $! captures the PID of the most recent background job (the tcpdump process)
   
   # From attacker VM, generate attack traffic:
   # vagrant ssh attacker
   # for i in {1..20}; do sshpass -p 'wrong' ssh fakeuser$i@192.168.220.11; done
   # sudo nmap -sS -p 1-1000 192.168.220.11
   
   # Stop capture using the specific PID we saved earlier
   sudo kill -TERM $TCPDUMP_PID || echo "Process already terminated"
   sleep 2
   ```

   **Analyze Traffic and Correlate with Logs:**
   ```bash
   # Install tshark for packet analysis
   sudo apt install -y tshark
   
   # Extract timestamps and connection info
   tshark -r /tmp/attack-traffic.pcap -T fields \
     -e frame.time -e ip.src -e ip.dst -e tcp.dstport -e tcp.flags \
     > /tmp/traffic-timeline.txt
   
   # In Kibana, search for events in same timeframe:
   # Query: host_role:defender AND @timestamp:[<start> TO <end>]
   # Compare packet capture timeline with log entries
   
   # Count SYN packets per port (shows scan pattern)
   tshark -r /tmp/attack-traffic.pcap -Y "tcp.flags.syn==1 && tcp.flags.ack==0" \
     -T fields -e tcp.dstport | sort | uniq -c | sort -rn | head -20
   
   # Now search in Kibana for same ports and timeframe
   # This proves correlation between network activity and logs
   ```

   **Real-Time Monitoring While Reviewing Historical Logs:**
   ```bash
   vagrant ssh defender
   
   # Install iftop for real-time traffic visualization
   sudo apt install -y iftop
   
   # Terminal 1: Real-time traffic monitoring
   sudo iftop -i eth1 -f "src 192.168.210.10"
   
   # Terminal 2: Real-time log tailing
   sudo tail -f /var/log/auth.log | grep --line-buffered "Failed password"
   
   # Terminal 3 (from host): Kibana dashboard
   # Watch events appear in real-time as attacks happen
   # Compare what you see in iftop/logs with Kibana visualizations
   ```

   **Build Attack Timeline from Multiple Sources:**
   ```bash
   # Extract attack start time from pcap
   ATTACK_START=$(tshark -r /tmp/attack-traffic.pcap -T fields -e frame.time | head -1)
   
   # Get auth failures from logs in that timeframe
   sudo journalctl --since "$ATTACK_START" | grep "Failed password" > /tmp/auth-failures.txt
   
   # Get firewall drops from logs
   sudo journalctl -k --since "$ATTACK_START" | grep "DROP" > /tmp/firewall-drops.txt
   
   # Create consolidated timeline
   echo "=== Attack Timeline ===" > /tmp/attack-timeline.txt
   echo "Start: $ATTACK_START" >> /tmp/attack-timeline.txt
   echo "" >> /tmp/attack-timeline.txt
   
   echo "Network Activity (from tcpdump):" >> /tmp/attack-timeline.txt
   tshark -r /tmp/attack-traffic.pcap -q -z io,phs >> /tmp/attack-timeline.txt
   
   echo -e "\nAuthentication Failures:" >> /tmp/attack-timeline.txt
   wc -l /tmp/auth-failures.txt >> /tmp/attack-timeline.txt
   
   echo -e "\nFirewall Blocks:" >> /tmp/attack-timeline.txt
   wc -l /tmp/firewall-drops.txt >> /tmp/attack-timeline.txt
   
   cat /tmp/attack-timeline.txt
   ```

   **Why Combine Network Monitoring with SIEM:**
   - **Network capture** shows what the attacker attempted (including blocked attempts)
   - **SIEM logs** show what reached the application layer and how systems responded
   - **Firewall logs** show what was blocked vs. allowed
   - **Combined analysis** reveals the complete attack story:
     * Network scan shows reconnaissance (many SYN packets)
     * Firewall logs show which ports were protected
     * Auth logs show actual login attempts that got through
     * SIEM correlation identifies the attack pattern

   **SIEM Query Examples for Network Events:**
   ```
   # Find scans (many connections in short time)
   host_role:defender AND event.category:network
   | stats count by source.ip, destination.port
   | where count > 100
   
   # Find successful vs failed connections
   host_role:defender AND event.outcome:(success OR failure)
   | stats count by event.outcome, source.ip
   
   # Find unusual ports being targeted
   destination.port:* AND NOT destination.port:(22 OR 80 OR 443)
   | stats count by destination.port, source.ip
   | sort count desc
   ```

### 1. Run Elasticsearch + Kibana locally (Original Content)
2. Configure Filebeat using `filebeat.yml.example` and point it to your stack.
3. Ingest logs and confirm indices appear in Kibana.

Expected output hints:

- `curl http://localhost:9200/_cat/indices?v` should list `filebeat-*` with `health status` green/yellow after Filebeat connects.
- Kibana Discover should show documents with fields like `host.name`, `agent.type:filebeat`, and timestamps matching recent events.

### Advanced: From ingest to detection

1. **Enrich with GeoIP + ECS**
   - Add a Filebeat ingest pipeline with GeoIP on `source.ip` and ECS field mappings.
   - Verify documents show `source.geo.country_iso_code` in Kibana Discover.

2. **Synthetic attack events**
   - Generate SSH brute-force noise with `ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no` in a loop against localhost.
   - Confirm events land in Filebeat indices and show elevated failure counts.

3. **Detection query**
   - Create a Kibana Saved Search or Detection Rule that triggers when a single source IP has >10 auth failures in 5 minutes.
   - **Configuration Note:** Adjust threshold based on your environment:
     - High-security: 5 failures in 5 minutes
     - Normal environment: 10 failures in 5 minutes (default)
     - Development/Test: 20 failures in 5 minutes
   - Document the KQL/Lucene you used (e.g., `event.dataset:system.auth and event.action:failed and terms aggregation on source.ip`).
   - **Tuning Tip:** Monitor false positive rate and adjust threshold accordingly.

4. **Dashboards + export**
   - Build a small dashboard: top talkers by `source.ip`, top processes by `process.name`, and failed vs successful auth over time.
   - Export the NDJSON and save it under `dashboards/week09-siem.ndjson` for reuse.

5. **Alternative SIEM**
   - If Elasticsearch isn’t available, ship to Grafana Loki or Splunk Free with equivalent labels/fields and replicate one detection.

### Example solutions / what “good” looks like

- The ingest pipeline JSON contains `geoip` and ECS `rename` processors, and resulting docs include `source.geo.*` fields.
- Synthetic SSH tests produce multiple `event.action: failed-password` entries with the same `source.ip`; your detection query lists that IP as the top offender.
- Dashboard export contains panels for geo distribution and auth failure trends with non-empty visualizations.
- Alternative SIEM notes explain mapping choices (e.g., Loki labels `host`, `process`, `status`).
- Saved Search or Detection Rule status in Kibana should be `Enabled` with `Last run status: succeeded`, indicating the rule executed.

## Checklist

### Basic Tasks
- [ ] Filebeat is installed and running
- [ ] Logs are forwarded to Elasticsearch
- [ ] You can see indices and sample queries in Kibana
- [ ] GeoIP/ECS pipeline applied and validated
- [ ] Synthetic attack events generated and visible in SIEM
- [ ] Detection query saved and documented
- [ ] Dashboard exported (or equivalent in chosen SIEM)

### Multi-VM SIEM Tasks
- [ ] Started ELK stack on logserver VM
- [ ] Installed Filebeat on defender and attacker VMs
- [ ] Verified logs flowing from multiple hosts to Elasticsearch
- [ ] Simulated SSH brute force and observed in Kibana
- [ ] Created detection rule for brute force attempts
- [ ] Generated port scan from attacker and found evidence in logs
- [ ] Built visualization showing attack sources and targets
- [ ] Correlated attacker and defender logs for same incident

### Advanced Understanding
- [ ] Can write KQL queries to find specific attack patterns
- [ ] Understand how to correlate events across multiple hosts
- [ ] Know how to tune detection rules to reduce false positives
- [ ] Can explain difference between logs, events, and alerts

### Advanced Production SIEM Deployment

While the lab ELK stack is great for learning, production SIEM deployments require additional considerations:

**1. High Availability and Scalability:**

```bash
# Production ELK cluster should have:
# - Multiple Elasticsearch nodes (minimum 3)
# - Load-balanced Kibana instances
# - Redis/Kafka buffer for log ingestion
# - Dedicated master nodes for cluster management

# Example multi-node setup (conceptual)
cat > /tmp/production-elk-architecture.md <<'EOF'
# Production SIEM Architecture

## Component Distribution

### Elasticsearch Cluster
- 3x Master nodes (cluster management, no data)
  - 4 CPU, 16GB RAM each
- 3x Data nodes (hot tier - recent data)
  - 8 CPU, 64GB RAM, 1TB SSD each
- 3x Data nodes (warm tier - older data)
  - 4 CPU, 32GB RAM, 4TB HDD each

### Ingestion Layer
- 2x Logstash instances (processing)
  - 4 CPU, 16GB RAM each
- Redis cluster (buffering)
  - 3 nodes for high availability

### Presentation Layer
- 2x Kibana instances (behind load balancer)
  - 2 CPU, 8GB RAM each
- Nginx load balancer
  - SSL termination, authentication

### Log Shippers
- Filebeat on every server (lightweight)
- Auditbeat for security audit logs
- Metricbeat for system metrics

## Data Flow

1. **Collection:** Filebeat → Redis buffer
2. **Processing:** Redis → Logstash (parse, enrich, transform)
3. **Storage:** Logstash → Elasticsearch (indexed, replicated)
4. **Analysis:** Elasticsearch → Kibana (visualize, alert)

## Sizing Guidelines

### Log Volume Estimation
- Average server: 1-5 MB/day
- Busy web server: 50-200 MB/day
- Network device: 10-50 MB/day
- Database server: 20-100 MB/day

### Retention Strategy
- Hot tier (0-7 days): Fast SSD, full search
- Warm tier (8-90 days): Slower HDD, read-only
- Cold tier (91-365 days): Object storage, compressed
- Archive (1+ year): Tape/glacier, compliance only

### Index Management
- Daily indices: `filebeat-YYYY.MM.DD`
- Auto-rollover at 50GB or 1 day
- Automatic snapshot to object storage
- ILM policy for tier transitions

## Security Hardening

### Network Security
- Elasticsearch: Only from Logstash/Kibana
- Kibana: Only from load balancer
- No direct internet exposure

### Authentication & Authorization
- SAML/LDAP for user authentication
- Role-based access control (RBAC)
- Audit logging for all access
- API keys for automation

### Encryption
- TLS for all communication
- Encryption at rest for indices
- Encrypted snapshots
- Secure credential storage

## Monitoring the SIEM

Even your monitoring needs monitoring!

### Metrics to Track
- Ingestion rate (events/sec)
- Query latency (ms)
- Cluster health (red/yellow/green)
- Disk usage per tier
- Search rejections
- JVM heap usage

### Alerts to Configure
- Cluster health degradation
- Disk space < 15%
- Ingestion lag > 5 minutes
- Failed authentication attempts
- Index shard failures

## Cost Optimization

### Storage Optimization
- Use compression (reduces by 50-70%)
- Implement proper retention
- Separate hot/warm/cold tiers
- Archive old data to object storage

### Compute Optimization
- Right-size nodes (don't over-provision)
- Use reserved instances for stable workload
- Scale data nodes horizontally
- Consider managed services for small deployments

### Query Optimization
- Use index patterns wisely
- Implement field-level security
- Cache common queries
- Use async search for heavy queries

## Disaster Recovery

### Backup Strategy
- Automated daily snapshots
- Test restoration quarterly
- Cross-region replication
- Document recovery procedures

### Recovery Time Objectives
- Elasticsearch cluster: 15 minutes
- Kibana: 5 minutes
- Full historical data: 4 hours

## Migration from Lab to Production

1. **Planning Phase** (Week 1-2)
   - Document requirements
   - Size infrastructure
   - Design network topology
   - Plan security controls

2. **Infrastructure Setup** (Week 3-4)
   - Deploy Elasticsearch cluster
   - Configure Logstash pipeline
   - Set up Kibana instances
   - Implement load balancing

3. **Migration Phase** (Week 5-6)
   - Deploy Filebeat to test servers
   - Validate log ingestion
   - Migrate dashboards and searches
   - Configure alerting rules

4. **Validation Phase** (Week 7)
   - Test all detection rules
   - Verify performance
   - Conduct disaster recovery drill
   - Train SOC team

5. **Go-Live** (Week 8)
   - Deploy to all servers
   - Enable alerting
   - 24/7 monitoring
   - Continuous optimization
EOF
```

**2. Advanced Detection Engineering:**

Create sophisticated detection rules that catch real attacks:

```bash
# Example: Credential Stuffing Detection

cat > /tmp/credential-stuffing-detection.json <<'EOF'
{
  "rule_id": "cred-stuffing-001",
  "name": "Potential Credential Stuffing Attack",
  "description": "Detects multiple failed login attempts from single IP across multiple users",
  "query": "event.dataset:system.auth AND event.outcome:failure",
  "threshold": {
    "field": "source.ip",
    "value": 10
  },
  "window": "5m",
  "severity": "high",
  "tags": ["authentication", "brute-force", "MITRE:T1110"],
  "actions": [
    {
      "type": "firewall_block",
      "duration": "1h"
    },
    {
      "type": "alert",
      "channel": "security-ops"
    }
  ]
}
EOF

# Example: Lateral Movement Detection

cat > /tmp/lateral-movement-detection.json <<'EOF'
{
  "rule_id": "lateral-move-001",
  "name": "Suspicious Lateral Movement",
  "description": "Detects authentication from one host immediately followed by auth to another host",
  "query": "event.dataset:system.auth AND event.outcome:success AND NOT source.ip:10.0.*",
  "sequence": [
    {
      "host": "host-a",
      "event": "successful_auth"
    },
    {
      "host": "host-b",
      "event": "successful_auth",
      "within": "2m",
      "same_user": true
    }
  ],
  "severity": "critical",
  "tags": ["lateral-movement", "MITRE:T1021"],
  "investigation_guide": "Check if user typically accesses both hosts. Review session duration and commands executed."
}
EOF
```

**3. Threat Hunting with SIEM:**

Beyond reactive alerting, proactively hunt for threats:

```bash
# Create threat hunting queries

cat > /tmp/threat-hunting-queries.md <<'EOF'
# Threat Hunting Queries for Kibana

## Hunt 1: Suspicious Process Execution

Look for unusual parent-child process relationships:

```
process.name:powershell.exe AND process.parent.name:excel.exe
```

Why: Office documents shouldn't spawn PowerShell.

## Hunt 2: Uncommon Network Connections

Find processes making external connections:

```
destination.port:NOT (80 OR 443 OR 22) AND 
destination.ip:NOT (10.0.0.0/8 OR 192.168.0.0/16 OR 172.16.0.0/12)
```

Why: Non-standard ports to external IPs may indicate C2.

## Hunt 3: Privilege Escalation Attempts

Search for sudo failures and retries:

```
event.action:*sudo* AND event.outcome:failure AND 
<same user> AND <within 5 minutes> AND count > 3
```

Why: Multiple sudo failures suggest privilege escalation attempts.

## Hunt 4: Data Exfiltration Indicators

Large outbound transfers:

```
network.direction:outbound AND 
network.bytes > 100000000 AND
destination.ip:NOT (10.0.0.0/8 OR 192.168.0.0/16)
```

Why: Large outbound transfers to external IPs may indicate data theft.

## Hunt 5: Account Anomalies

User accounts created outside business hours:

```
event.action:user-added AND
@timestamp:[22:00 TO 06:00]
```

Why: Attackers often create backdoor accounts at night.

## Hunt 6: Persistence Mechanisms

Check for unusual scheduled tasks:

```
event.category:process AND
process.name:(crontab OR at OR schtasks) AND
NOT user.name:root
```

Why: Attackers use scheduled tasks for persistence.

## Hunt 7: Reconnaissance Activity

Look for network scanning patterns:

```
event.category:network AND
destination.port:(*) AND
source.ip:<single IP> AND
<unique destination ports> > 100 within 1 minute
```

Why: Rapid connection attempts to many ports indicates scanning.

## Hunting Methodology

1. **Hypothesis:** "Is there evidence of X attack?"
2. **Query:** Build search to find indicators
3. **Investigate:** Review findings, rule out false positives
4. **Document:** Record findings and create detection rules
5. **Iterate:** Refine query and repeat

## Tips for Effective Hunting

- Stack by fields to find outliers: `| stats count by process.name`
- Use time-based analysis: Compare to baseline
- Correlate multiple data sources: Process + Network + File
- Look for absence: Things that should happen but didn't
- Think like an attacker: What would you do?
EOF
```

**4. Integration with Threat Intelligence:**

```bash
# Integrate threat intel feeds

cat > /tmp/threat-intel-integration.sh <<'EOF'
#!/bin/bash
# Threat Intelligence Integration

# Download threat intel feeds (example)
curl -s https://example.com/malicious-ips.txt > /tmp/malicious-ips.txt

# Create Elasticsearch enrichment pipeline
curl -X PUT "localhost:9200/_ingest/pipeline/threat-intel" -H 'Content-Type: application/json' -d'
{
  "description": "Enrich with threat intelligence",
  "processors": [
    {
      "set": {
        "if": "ctx.source?.ip != null",
        "field": "threat.indicator.ip",
        "value": "{{source.ip}}"
      }
    },
    {
      "script": {
        "lang": "painless",
        "source": "if (params.malicious_ips.contains(ctx.source.ip)) { ctx.threat.matched = true; ctx.threat.severity = '\''high'\''; }"
      }
    }
  ]
}
'

# Apply pipeline to filebeat indices
# (In production, use proper threat intel platforms like MISP, ThreatConnect, etc.)
EOF
```

### Real-World SIEM Use Cases

**Use Case 1: Ransomware Detection**

Indicators to monitor:
- Rapid file modifications across many directories
- Unusual file extensions (.encrypted, .locked)
- Process execution: Known ransomware binaries
- Network: Connection to known ransomware C2
- Registry: Persistence mechanisms

**Use Case 2: Insider Threat Detection**

Indicators to monitor:
- After-hours access from unusual locations
- Large data downloads/exports
- Access to resources outside normal scope
- USB device connections
- Email with large attachments to external addresses

**Use Case 3: Supply Chain Attack**

Indicators to monitor:
- Software updates from unexpected sources
- Modified binaries (hash mismatch)
- Unusual network connections after updates
- Privilege escalation post-update
- New scheduled tasks after software changes

## SIEM Maturity Model

### Level 1: Collection (Weeks 1-4)
- [ ] Logs collected from critical systems
- [ ] Basic parsing and indexing
- [ ] Simple searches work
- [ ] Ad-hoc investigations possible

### Level 2: Detection (Months 2-3)
- [ ] Detection rules for known attacks
- [ ] Automated alerting configured
- [ ] False positive tuning in progress
- [ ] Incident response procedures defined

### Level 3: Correlation (Months 4-6)
- [ ] Multi-source event correlation
- [ ] User and entity behavior analytics (UEBA)
- [ ] Threat intelligence integration
- [ ] Automated investigation workflows

### Level 4: Optimization (Months 7-12)
- [ ] Machine learning anomaly detection
- [ ] Automated response actions (SOAR)
- [ ] Metrics-driven improvement
- [ ] Regular threat hunting exercises

### Level 5: Advanced (Year 2+)
- [ ] Predictive threat modeling
- [ ] Red team vs Blue team exercises
- [ ] Custom detection engineering
- [ ] Industry-leading SOC operations

## Common SIEM Pitfalls and Solutions

### Pitfall 1: Alert Fatigue
**Problem:** Too many alerts, analysts ignore them
**Solution:** 
- Tune rules aggressively (target <10 false positives/day)
- Implement alert prioritization
- Use ML to cluster similar alerts
- Regularly review and disable noisy rules

### Pitfall 2: Storage Costs
**Problem:** Log storage costs spiral out of control
**Solution:**
- Implement tiered storage (hot/warm/cold)
- Sample high-volume, low-value logs
- Compress old data
- Archive to object storage

### Pitfall 3: Missing Critical Logs
**Problem:** Attacks succeed because logs weren't collected
**Solution:**
- Map logs to MITRE ATT&CK coverage
- Identify gaps in visibility
- Prioritize high-value asset logging
- Regular audit of log sources

### Pitfall 4: Long Investigation Times
**Problem:** Hours to investigate each alert
**Solution:**
- Build investigation playbooks
- Create pivot queries for common scenarios
- Use dashboards for quick context
- Implement SOAR for automation

### Pitfall 5: Poor Performance
**Problem:** Queries take forever, searches time out
**Solution:**
- Optimize index patterns
- Use field-level security appropriately
- Scale horizontally with more nodes
- Cache common queries
- Use async search for heavy workloads

## Compliance and SIEM

Different compliance frameworks require different log retention:

| Framework | Retention | Critical Logs |
|-----------|-----------|---------------|
| **PCI-DSS** | 1 year (accessible), 3 months (immediate) | Authentication, Authorization, Audit trail |
| **HIPAA** | 6 years | Access to PHI, modifications, disclosures |
| **SOX** | 7 years | Financial system access, changes |
| **GDPR** | Varies | Data access, processing, deletion |
| **SOC 2** | 1 year+ | System changes, access, monitoring |

**Compliance Implementation:**

```bash
# Create compliance-specific indices with proper retention
cat > /tmp/compliance-ilm-policy.json <<'EOF'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "50GB",
            "max_age": "1d"
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "readonly": {},
          "shrink": {
            "number_of_shards": 1
          }
        }
      },
      "cold": {
        "min_age": "90d",
        "actions": {
          "freeze": {}
        }
      },
      "delete": {
        "min_age": "2555d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
EOF
```

### Week 5 Mastery Checklist

Beyond the basic checklist, true mastery includes:

- [ ] Can design a production SIEM architecture
- [ ] Understand cost implications and optimization strategies
- [ ] Know how to implement high availability
- [ ] Can write complex detection rules with low false positives
- [ ] Understand threat hunting methodology
- [ ] Can integrate threat intelligence feeds
- [ ] Know compliance requirements for your industry
- [ ] Can troubleshoot SIEM performance issues
- [ ] Understand the full incident response workflow
- [ ] Can mentor others on SIEM best practices

