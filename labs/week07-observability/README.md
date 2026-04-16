# Week 7 – Monitoring & Observability

## Objectives

- Understand the "Three Pillars of Observability" (Logs, Metrics, Traces)
- Setup and configure Prometheus for metric collection
- Install and use Node Exporter to monitor system-level metrics
- Visualize data using Grafana dashboards
- Create alerts based on metric thresholds
- Explore the difference between "monitoring" and "observability"

## Estimated Time

⏱️ **3-4 hours**

## Prerequisites

- Vagrant VMs started (defender or monitored)
- Basic knowledge of Linux networking and HTTP

---

## 1. What is Observability?

Observability is a measure of how well internal states of a system can be inferred from knowledge of its external outputs.

### The Three Pillars
1. **Metrics**: Numerical representations of data measured over time (e.g., CPU usage, error rate).
2. **Logs**: Immutable, timestamped records of discrete events that happened over time.
3. **Traces**: End-to-end representation of a request's journey through a distributed system.

---

## 2. Hands-On: Prometheus Setup

Prometheus is an open-source system monitoring and alerting toolkit.

### Task 1: Install Prometheus (on Logserver VM)
```bash
vagrant ssh logserver
# Prometheus is available as a Docker image or standalone binary
# Let's use Docker for quick setup
docker run -d \
    --name prometheus \
    -p 9090:9090 \
    prom/prometheus
```

Access Prometheus: `http://192.168.210.30:9090`

### Task 2: Install Node Exporter (on Defender VM)
Node Exporter is a Prometheus exporter for hardware and OS metrics.
```bash
vagrant ssh defender
docker run -d \
    --name node-exporter \
    -p 9100:9100 \
    prom/node-exporter
```

Access metrics: `curl http://192.168.220.11:9100/metrics`

---

## 3. Visualization with Grafana

Grafana is an open-source platform for monitoring and observability.

### Task 3: Setup Grafana
```bash
vagrant ssh logserver
docker run -d \
    --name grafana \
    -p 3000:3000 \
    grafana/grafana
```

Access Grafana: `http://192.168.210.30:3000`
- **Default login**: `admin/admin`

### Task 4: Connect Prometheus to Grafana
1. In Grafana, go to **Connections** -> **Data Sources**.
2. Click **Add data source** and select **Prometheus**.
3. Set **URL** to `http://192.168.210.30:9090` (if logserver) or `http://prometheus:9090` (if in same docker network).
4. Click **Save & Test**.

---

## 4. Building Dashboards

### Task 5: Import a Dashboard
1. Go to **Dashboards** -> **New** -> **Import**.
2. Use ID `1860` (Node Exporter Full) to import a pre-made dashboard.
3. Select your Prometheus data source and click **Import**.

---

## 5. Alerting Foundations

### Task 6: Create a Basic Alert
1. In Grafana, go to **Alerting** -> **Alert rules**.
2. Create a new rule for "High CPU Usage".
3. Query: `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80`.
4. Set evaluation behavior and notification channel (e.g., email or Slack).

---

## Checklist
- [ ] I can explain the three pillars of observability.
- [ ] I successfully setup Prometheus to scrape metrics.
- [ ] I can visualize system-level metrics in Grafana.
- [ ] I imported a community-made dashboard.
- [ ] I understand how to define an alert threshold.
