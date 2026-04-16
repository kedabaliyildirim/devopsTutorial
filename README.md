# Sec DevOps Lab


Hands-on labs to learn and practice:

- **Containers & Orchestration**: Docker, Kind, and Kubernetes fundamentals
- **Infrastructure as Code**: Terraform/OpenTofu and Ansible automation
- **CI/CD & Automation**: Building secure and efficient pipelines
- **Firewalls**: host, cloud, and Kubernetes network policies
- **Proxies**: forward, reverse, and Kubernetes ingress
- **Monitoring & Observability**: Prometheus, Grafana, and metrics
- **DLP-style controls**: secret scanning and data protection in pipelines
- **SIEM**: log collection, shipping, and detection (ELK stack)
- **EDR-style monitoring**: Falco, OSQuery, and security observability

> **Goal**: Build a portfolio of real-world DevOps and Security skills using open-source tools.

---

## 🚀 Getting Started

1.  **Clone the Repository**
    ```bash
    git clone git@github.com:<your-user>/devops-tutorial.git
    cd devops-tutorial
    ```

2.  **Environment Setup**
    This lab uses a multi-VM environment (Vagrant + libvirt/KVM). See the [**VM Setup Guide**](VM-SETUP.md) for software requirements, network topology, and startup instructions.

3.  **Follow the Curriculum**
    Each week is located in the `labs/` directory:

    ### Part 1: Foundations & Infrastructure
    - [Week 0: OSI Layers Foundation](labs/OSI-LAYERS-GUIDE.md)
    - [Week 1: Network Basics & Gateways](labs/week01-network-basics/README.md)
    - [Week 2: Containerization with Docker](labs/week02-containers/README.md)
    - [Week 3: Infrastructure as Code (Terraform)](labs/week03-iac/README.md)
    - [Week 4: CI/CD & Pipeline Automation](labs/week04-cicd/README.md)

    ### Part 2: Security & Networking
    - [Week 5: Firewalls (Host & Gateway)](labs/week05-firewall/README.md)
    - [Week 6: Proxies (L4 vs L7)](labs/week06-proxy/README.md)

    ### Part 3: Operations & Security Observability
    - [Week 7: Monitoring & Observability](labs/week07-observability/README.md)
    - [Week 8: DLP & Secret Scanning](labs/week08-dlp/README.md)
    - [Week 9: SIEM & Log Shipping](labs/week09-siem/README.md)
    - [Week 10: EDR & Security Observability](labs/week10-edr/README.md)

---

## 📂 Repository Structure

- `labs/` — Weekly hands-on exercises and theory guides.
- `k8s/` — Kubernetes manifests used across different labs.
- `ansible/` — Automation playbooks for consistent lab environments.
- `QUICK-REFERENCE.md` — Cheat sheet for common tools (nmap, tcpdump, nftables).

---

## 🛠️ Requirements Overview

- **OS**: Linux (recommended) or macOS/Windows with a Linux VM.
- **Hardware**: 16 GB RAM (minimum 8 GB for limited labs), 50 GB Disk.
- **Tools**: Vagrant, libvirt/KVM, Docker, and a GitHub account.

See [**VM-SETUP.md**](VM-SETUP.md) for the full checklist and troubleshooting.

---

## 🧪 Why this Lab?

This curriculum is designed to mirror real-world DevOps and security roles:
- **Infrastructure-as-Code**: Automate security controls with Ansible and Terraform.
- **Defense in Depth**: Layered security from the kernel (EDR) to the edge (Gateways).
- **Tool Mastery**: Gain hands-on experience with industry standards like ELK, Prometheus, and K8s.
- **Portfolio Ready**: Document your progress and use the findings in your professional CV.

  [![Sponsor GitHub](https://img.shields.io/badge/Sponsor-GitHub-ea4aaa?style=for-the-badge&logo=github)](https://github.com/sponsors/kedabaliyildirim)

