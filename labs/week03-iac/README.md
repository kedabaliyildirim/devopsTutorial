# Week 3 – Infrastructure as Code (IaC) with Terraform

## Objectives

- Understand the principles of Infrastructure as Code (IaC)
- Install and configure Terraform/OpenTofu
- Provision local infrastructure using the Docker provider
- Manage infrastructure state and lifecycles (init, plan, apply, destroy)
- Understand Terraform variables, outputs, and modules
- Explore the difference between declarative and imperative configuration

## Estimated Time

⏱️ **2.5-3 hours**

## Prerequisites

- Vagrant VMs started (defender or logserver)
- Docker installed (pre-installed on logserver, or follow instructions in Week 2)

---

## 1. What is Infrastructure as Code (IaC)?

IaC is the management and provisioning of infrastructure through code, rather than through manual processes.

### Key Benefits
- **Consistency**: Eliminate "it works on my machine" issues.
- **Speed**: Rapidly provision environments for dev, test, and prod.
- **Auditability**: Track changes to infrastructure through version control (Git).
- **Automation**: Integrate infrastructure changes into CI/CD pipelines.

### Terraform vs. Ansible
- **Terraform**: Best for **provisioning** resources (VMs, networks, databases, cloud instances). "Declarative".
- **Ansible**: Best for **configuring** existing resources (installing packages, updating configs). "Imperative".

---

## 2. Hands-On: Terraform Basics

### Task 1: Install Terraform/OpenTofu (on Logserver VM)
```bash
vagrant ssh logserver
# OpenTofu is the open-source fork of Terraform
sudo apt-get update
sudo apt-get install -y opentofu
tofu --version
```

### Task 2: Provision a Docker Container with Terraform
Create a directory and a configuration file `main.tf`:
```bash
mkdir -p ~/terraform-lab && cd ~/terraform-lab
cat > main.tf <<'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "tutorial-container"
  ports {
    internal = 80
    external = 8083
  }
}
EOF
```

### Task 3: Terraform Lifecycle
```bash
# Initialize (downloads provider)
tofu init

# Plan (shows what will be created)
tofu plan

# Apply (actually creates the resource)
tofu apply -auto-approve

# Verify
docker ps
curl localhost:8083

# Destroy (removes everything)
tofu destroy -auto-approve
```

---

## 3. Variables and Outputs

### Task 4: Using Variables
Create `variables.tf`:
```hcl
variable "container_name" {
  description = "Value of the name for the Docker container"
  type        = string
  default     = "ExampleNginxContainer"
}
```

Update `main.tf` to use `var.container_name`:
```hcl
resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = var.container_name
  # ... (rest of the block)
}
```

---

## 4. State Management

Terraform tracks the ID and properties of resources it manages in a file called `terraform.tfstate`. **Never edit this file manually!**

### Task 5: Inspect State
```bash
tofu show
tofu state list
```

---

## Checklist
- [ ] I can explain the difference between provisioning and configuration management.
- [ ] I successfully ran `tofu init`, `plan`, `apply`, and `destroy`.
- [ ] I understand how Terraform uses `tfstate` to track resources.
- [ ] I successfully used a variable to change a resource property.
