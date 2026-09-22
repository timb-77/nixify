# What do you want to create?

- I want to manage all my linux computers with the Nix package manager and NixOS configuration management system. I want to create a centralized configuration that can be applied to all my Linux machines, allowing me to easily manage packages, services, and system settings across different environments.
- For this, Home Manager and Flakes are essential tools. Home Manager allows me to manage user-specific configurations, while Flakes provide a reproducible and declarative way to define my system configurations. By combining these tools, I can create a unified configuration that can be shared and applied across all my Linux computers, ensuring consistency and ease of maintenance.
- It should be possiblie to have a common set of base configuration files that applie to all computers (a certain set of apps/tools, config files, credentials, etc.), as well as computer specific Nix configuration files.
- Here are some apps/tools that should be made available on all computers via Nix:
    * Vim
    * git
    * tmux
- Vim should come in two flavors (both support debugging):
    * as a C++ development environmet, 
    * and as a Python development environment

