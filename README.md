# Inception of Things

This project is part of the 42 curriculum and focuses on learning the fundamentals of containerization, orchestration, and cluster-based deployment using Docker and Kubernetes.

The goal is to understand how modern infrastructure is built and managed by deploying services in isolated containers, then orchestrating them in a Kubernetes environment.

## Project Overview

The Inception of Things project introduces the core concepts behind:
- Containerization
- Docker and image creation
- Kubernetes architecture
- Pods, deployments, and services
- Networking and service discovery
- Persistent storage
- Cluster management and orchestration
- Automation and deployment workflows

The project is divided into several phases, each gradually increasing in complexity and introducing new DevOps concepts.

## Repository Structure

```text
IOT-inception-of-things/
├── .gitignore
├── bonus/
├── p1/
├── p2/
├── p3/
├── README.md
└── ...
```

### Directories
- `p1/`: Basic Docker and containerization exercises
- `p2/`: Kubernetes fundamentals and deployment basics
- `p3/`: Advanced Kubernetes concepts and cluster configuration
- `bonus/`: Additional extensions and optional challenges

## Learning Objectives

By the end of this project, the student should be able to:
- Understand container concepts and Docker usage
- Build and run custom Docker images
- Manage containers and their lifecycle
- Configure basic networking between services
- Deploy applications in a Kubernetes cluster
- Use Kubernetes objects such as Pods, Deployments, Services, and ConfigMaps
- Understand cluster architecture and orchestration principles
- Troubleshoot common deployment and infrastructure issues

## Prerequisites

Before starting this project, it is recommended to have:
- Basic knowledge of Linux and shell scripting
- Familiarity with networking concepts
- Experience with command-line tools
- A working Docker environment
- A local or virtual Kubernetes environment
- Git and GitHub fundamentals

## Tools Used

This project typically relies on:
- Docker
- Kubernetes
- kubectl
- k3s or a local cluster solution
- Shell scripting
- YAML configuration files

## Part 1 - Docker Fundamentals

The first part introduces the basic concepts of containerization and virtualization.
Students learn how to:
- Create Docker images
- Run and manage containers
- Expose ports and share data
- Understand container isolation and lifecycle
- Build simple service architectures

## Part 2 - Kubernetes Basics

The second part focuses on deploying applications inside a Kubernetes cluster.
Students learn how to:
- Create Pods
- Manage Deployments and ReplicaSets
- Expose applications through Services
- Configure inter-service communication
- Understand YAML-based Kubernetes manifests
- Use basic Kubernetes commands for observation and debugging

## Part 3 - Advanced Kubernetes

The third part introduces more advanced infrastructure concepts, including:
- Cluster configuration and scaling
- Persistent storage
- Resource management
- Advanced networking
- Service availability and resilience
- Deployment strategies and troubleshooting

## Bonus

The bonus section may include optional or advanced tasks such as:
- Monitoring and logging setup
- Security improvements
- More complex networking scenarios
- Additional cluster optimizations
- Infrastructure automation improvements

## Typical Workflow

```bash
git clone https://github.com/ayoub-essarghini/IOT-inception-of-things.git
cd IOT-inception-of-things
```

Then:
- inspect each part directory
- configure the required environment
- build and run Docker containers
- deploy services with Kubernetes manifests
- validate the setup
- troubleshoot and iterate

## Common Commands

### Docker
```bash
docker build -t my-image .
docker run -d -p 8080:80 my-image
docker ps
docker logs <container_id>
```

### Kubernetes
```bash
kubectl get pods
kubectl get deployments
kubectl get services
kubectl apply -f manifest.yaml
kubectl describe pod <pod_name>
kubectl logs <pod_name>
```

## Key Concepts Covered

- Container lifecycle
- Image creation and reuse
- Microservices deployment
- Orchestration
- Service discovery
- Cluster networking
- Configuration management
- High availability and resilience

## Challenges

This project is designed to teach real-world operational habits:
- debugging infrastructure issues
- understanding service dependencies
- writing clean configuration files
- managing deployments efficiently
- ensuring application reliability in distributed systems

## Author

Created by:
- ayoub-essarghini

## License

This project follows the principles of the 42 curriculum and is intended for educational use.

## Conclusion

The Inception of Things project is an introduction to modern DevOps practices. It helps students understand how applications are packaged, deployed, and orchestrated in real-world cloud and infrastructure environments.

This project is an essential step toward understanding modern software deployment, container orchestration, and distributed system management.

---

If you want, I can also write a more formal 42-style README, a shorter GitHub-ready version, or a more polished project description specifically for your repo page.
