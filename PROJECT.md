## What's docker?
Docker is an open-source platform designed to make it easier to create, deploy, and run applications by using containers.
Instead of running an application directly on a physical or virtual computer's operating system, a container packages up the application code along with everything it needs to run such as libraries, system tools, code, and runtime into a single, standardized unit.

## What's a Docker Container?
Lightweight, standalone, and executable packages of software that include everything needed to run an application. They share the host machine's operating system kernel, making them much faster and more efficient than traditional virtual machines (VMs).

## What's a Docker Image?
A read-only template that contains instructions for creating a Docker container (think of it as a blueprint). Images are built from a Dockerfile and can be stored and shared via registries like Docker Hub.

## What's a Dockerfile?
A simple text file containing a list of commands that the Docker client calls to create an automatically assembled image.

## What's a Registry?
A storage and distribution system for Docker images. Docker Hub is the default public registry, but organizations often use private registries.

## Why Do Developers Use Docker?
1. "It works on my machine" is solved: Because containers package dependencies along with the code, applications run reliably across different environments—whether that is a developer's local laptop, a staging server, or a cloud production environment.

2. Isolation: Multiple containers can run on the same server simultaneously without interfering with one another. Each container has its own isolated filesystem, network, and process space.

3. Efficiency & Speed: Unlike Virtual Machines, which require a heavy guest operating system for every instance, containers share the host OS kernel and start up in mere seconds.

4. Scalability: Docker makes it easy to spin up new instances of an application quickly, which integrates seamlessly with orchestration tools like Kubernetes for managing large-scale cloud applications.
