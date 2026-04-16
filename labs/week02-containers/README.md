# Week 2 – Containerization with Docker

## Objectives

- Understand the difference between Virtual Machines and Containers
- Build and optimize Docker images using Dockerfiles
- Manage container lifecycles (run, stop, rm, logs)
- Configure container networking and volumes
- Run multi-container applications with Docker Compose
- Deploy a local Kubernetes cluster using Kind (Kubernetes in Docker)

## Estimated Time

⏱️ **2.5-3.5 hours**

## Prerequisites

- Vagrant VMs started (defender or attacker)
- Docker installed (pre-installed on logserver, or follow instructions below)

---

## 1. Docker Fundamentals

### What are Containers?
Containers are isolated environments that share the host system's kernel. Unlike VMs, they don't include a full guest OS, making them lightweight and fast.

### Key Concepts
- **Image**: A read-only template with instructions for creating a container.
- **Container**: A runnable instance of an image.
- **Dockerfile**: A text document that contains all the commands a user could call on the command line to assemble an image.
- **Registry**: A stateless, highly scalable server side application that stores and lets you distribute Docker images (e.g., Docker Hub).

---

## 2. Hands-On: Docker Basics

### Task 1: Install Docker (on Defender VM)
```bash
vagrant ssh defender
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker vagrant
# Log out and log back in to apply group changes
exit
vagrant ssh defender
```

### Task 2: Running your first container
```bash
docker run hello-world
docker run -it ubuntu bash
# Inside the container:
ls /
exit
```

### Task 3: Building a Web Server Image
Create a file named `Dockerfile`:
```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
```

Create `index.html`:
```html
<h1>Hello from Docker!</h1>
```

Build and run:
```bash
docker build -t my-web-app .
docker run -d -p 8081:80 --name my-site my-web-app
curl localhost:8081
```

---

## 3. Multi-Container Apps (Docker Compose)

Docker Compose allows you to define and run multi-container applications.

### Task 4: Simple App + DB
Create `docker-compose.yml`:
```yaml
version: '3'
services:
  web:
    image: nginx:alpine
    ports:
      - "8082:80"
  db:
    image: redis:alpine
```

Run:
```bash
docker-compose up -d
docker ps
docker-compose down
```

---

## 4. Kubernetes in Docker (Kind)

Kind is a tool for running local Kubernetes clusters using Docker container "nodes".

### Task 5: Setup Kind
```bash
# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster --name dev-cluster
kubectl cluster-info
```

---

## Checklist
- [ ] I understand the difference between images and containers.
- [ ] I can write a simple Dockerfile.
- [ ] I can map ports from host to container.
- [ ] I can use Docker Compose to start multiple services.
- [ ] I have successfully started a Kind cluster.
