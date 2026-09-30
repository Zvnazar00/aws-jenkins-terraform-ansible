# AWS Jenkins CI/CD Infrastructure (Terraform + Ansible)

DevOps project: automated provisioning of CI/CD infrastructure on AWS — Jenkins master/worker in a public/private subnet, configured through the combination of Terraform (infrastructure) and Ansible (configuration).

## What's implemented

- **Infrastructure (Terraform)**:
  - VPC with a public and a private subnet (`main.tf`)
  - EC2 instances for the Jenkins master (public subnet) and worker (private subnet) (`ec2.tf`)
  - Security Groups restricting SSH/HTTP access
  - Remote state in S3 with state locking (`use_lockfile`)
  - Cloud-init and Ansible inventory templates (`templates/`)
  - Outputs with the addresses of the created servers (`outputs.tf`)

- **Configuration (Ansible)** (`site.yml`):
  - **Jenkins master**: installs Java, Jenkins, Nginx (reverse proxy), generates an SSH key to connect to the worker node
  - **Jenkins worker**: installs Java and Docker (docker-ce, buildx, compose-plugin), authorizes the master's SSH key for `ProxyJump` access

- **CI/CD pipeline (Jenkinsfile)**:
  - Checks out the application from Git
  - Builds a Docker image via `docker compose build`
  - Runs tests in a separate container
  - Publishes the image to DockerHub once tests pass
  - Handles failed tests in a separate pipeline stage

## Tech stack

`Terraform` · `AWS EC2/VPC` · `Ansible` · `Jenkins` · `Docker` · `Nginx` · `Groovy (Jenkinsfile)`

## Architecture

1. Terraform creates the VPC, EC2 instances for the Jenkins master (public) and worker (private, reachable via `ProxyJump` from the master), and generates the Ansible inventory file.
2. Ansible configures Jenkins on the master node (with an Nginx reverse proxy) and the Docker environment on the worker node, establishing a trusted SSH connection between them.
3. Jenkins on the worker node runs the pipeline: build image → run tests → publish to DockerHub.

## Repository structure

```
Src/
├── terraform/       # IaC: VPC, EC2, security groups, S3 backend
├── ansible/          # Provisioning of the Jenkins master/worker
└── Jenkins/
    └── Jenkinsfile    # CI/CD pipeline (build → test → push)
Screens/               # Screenshots of the deployment and CI/CD run
```

## Screenshots

Screenshots of the infrastructure and pipeline in action are in the `Screens/` folder.
