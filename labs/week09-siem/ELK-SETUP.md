# ELK Stack Setup Guide

This guide provides instructions for setting up the ELK (Elasticsearch, Logstash, Kibana) stack on the logserver VM for Week 5 SIEM lab.

## Automatic Setup

When you provision the `logserver` VM with `vagrant up logserver`, the following are automatically installed and configured:

1. **Docker and docker-compose** - Container runtime and orchestration
2. **/opt/elk directory** - ELK stack configuration location
3. **docker-compose.yml** - ELK stack service definitions

The ELK stack is **not started automatically** to save system resources. You need to start it manually when ready.

## Starting the ELK Stack

### Quick Start

```bash
# SSH into logserver VM
vagrant ssh logserver

# Navigate to ELK directory
cd /opt/elk

# Start ELK stack in detached mode
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

### Access Services

From your **host machine** (not from inside the VM):

- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601

From **other VMs** in the lab (e.g., defender, attacker):

- **Elasticsearch**: http://192.168.210.30:9200
- **Kibana**: http://192.168.210.30:5601

## Managing the ELK Stack

### Check Status

```bash
vagrant ssh logserver
cd /opt/elk
sudo docker-compose ps
```

### View Logs

```bash
# All services
sudo docker-compose logs

# Elasticsearch only
sudo docker-compose logs elasticsearch

# Kibana only
sudo docker-compose logs kibana

# Follow logs in real-time
sudo docker-compose logs -f
```

### Stop ELK Stack

```bash
vagrant ssh logserver
cd /opt/elk
sudo docker-compose down
```

### Restart Services

```bash
# Restart all services
sudo docker-compose restart

# Restart specific service
sudo docker-compose restart elasticsearch
sudo docker-compose restart kibana
```

### Remove Everything (Including Data)

```bash
vagrant ssh logserver
cd /opt/elk
sudo docker-compose down -v  # -v removes volumes (data will be lost)
```

## Troubleshooting

### Elasticsearch Won't Start

**Problem**: Elasticsearch container exits immediately

**Check logs**:
```bash
sudo docker-compose logs elasticsearch
```

**Common causes**:
1. Insufficient memory (needs at least 2GB allocated to logserver VM)
2. Port 9200 already in use

**Solution**:
```bash
# Check memory
free -h

# Check if port is in use
sudo netstat -tlnp | grep 9200

# Increase VM memory in Vagrantfile if needed (already set to 4096 MB)
# Restart the VM
vagrant reload logserver
```

### Kibana Shows "Kibana server is not ready yet"

**Problem**: Kibana can't connect to Elasticsearch

**Solution**:
1. Wait 2-3 minutes for Elasticsearch to fully start
2. Check Elasticsearch is running:
   ```bash
   curl http://localhost:9200
   ```
3. Check Kibana logs:
   ```bash
   sudo docker-compose logs kibana
   ```

### Can't Access from Host Machine

**Problem**: http://localhost:5601 doesn't work from host

**Check**:
1. Verify port forwarding in Vagrantfile (already configured)
2. Verify Kibana is running inside VM:
   ```bash
   vagrant ssh logserver
   curl http://localhost:5601
   ```
3. Check firewall on host machine

### Services Keep Restarting

**Problem**: Docker containers keep restarting

**Check**:
```bash
sudo docker-compose logs
```

**Common causes**:
1. Out of memory - increase logserver VM memory
2. Disk space full - clean up with `sudo docker system prune`

## Manual Installation (If Needed)

If automatic provisioning fails or you need to set it up manually:

### Install Docker

```bash
vagrant ssh logserver

# Update package list
sudo apt-get update

# Install Docker
sudo apt-get install -y docker.io docker-compose curl

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add vagrant user to docker group
sudo usermod -aG docker vagrant

# Log out and back in for group changes to take effect
exit
vagrant ssh logserver
```

### Create ELK Configuration

```bash
# Create directory
sudo mkdir -p /opt/elk

# Create docker-compose.yml
sudo tee /opt/elk/docker-compose.yml > /dev/null <<'EOF'
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
EOF

# Set proper ownership
sudo chown -R vagrant:vagrant /opt/elk
```

### Start Services

```bash
cd /opt/elk
sudo docker-compose up -d
```

## ELK Stack Configuration Details

### Elasticsearch Configuration

- **Version**: 8.11.0
- **Discovery Type**: single-node (for lab environment)
- **Memory**: 512MB heap size (adjustable via ES_JAVA_OPTS)
- **Security**: Disabled (xpack.security.enabled=false) for ease of use in lab
- **Port**: 9200
- **Data Storage**: Docker volume `esdata`

### Kibana Configuration

- **Version**: 8.11.0
- **Port**: 5601
- **Elasticsearch URL**: http://elasticsearch:9200
- **Depends On**: Elasticsearch (starts after ES is ready)

### Network Configuration

- **Network Name**: elk
- **Driver**: bridge
- **Services**: Both Elasticsearch and Kibana on same Docker network

### Data Persistence

Data is stored in a Docker volume named `esdata`. This means:
- Data persists across container restarts
- Data is lost if you run `docker-compose down -v`
- Data survives `docker-compose down` (without -v flag)

## Resource Requirements

### Minimum Requirements

- **RAM**: 2 GB (for both Elasticsearch and Kibana)
- **Disk**: 10 GB free space
- **CPU**: 2 cores

### Recommended Requirements

- **RAM**: 4 GB (already configured in Vagrantfile)
- **Disk**: 20 GB free space
- **CPU**: 2 cores (already configured in Vagrantfile)

## Next Steps

After ELK stack is running:

1. **Verify Installation**: Access Kibana at http://localhost:5601
2. **Install Filebeat**: Follow instructions in Week 5 README for Filebeat configuration
3. **Generate Logs**: Create attack traffic to generate logs
4. **Explore Kibana**: Search and visualize logs in Kibana interface

## References

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/8.11/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/8.11/index.html)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Week 5 Lab README](README.md)
