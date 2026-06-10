# genieACS-Mikrowire

Multi-tenant GenieACS deployment scripts integrated with HestiaCP on Docker.
This project is customized with a custom UI layout and Dark Mode styling from `genieacs-main`.

## Features
- Multi-tenant GenieACS architecture.
- Shared MongoDB instance with memory limits and WiredTiger cache optimizations.
- Isolated container CPU/RAM limits for low-resource VPS.
- HestiaCP integration with custom Nginx templates for automatic SSL and Reverse Proxy setup.
- Automated provisions, custom menus, and virtual parameters loading from templates.

For installation instructions, please refer to [CARA_INSTALL.md](CARA_INSTALL.md).
