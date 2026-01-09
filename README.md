# Ansible Random Stuff

A collection of utility scripts for working with Ansible Core / Automation Platform (AAP) and Ansible Galaxy collections.

## Scripts

### [reconstruct_collection](./reconstruct_collection/)

**Purpose**: Reconstructs an Ansible `galaxy.yml` file from an existing `MANIFEST.json` found in an unpacked collection tarball. This is essentially the reverse operation of `ansible-galaxy collection build`.

**Quick Start**:
```bash
cd reconstruct_collection
./reconstruct_collection.sh <target_folder_or_tar.gz>
```

**Documentation**: See [reconstruct_collection/README.md](./reconstruct_collection/README.md) for detailed usage, examples, and requirements.

## Overview

These scripts are designed to help automate and simplify common tasks when working with Ansible collections and Ansible Automation Platform. Each script is self-contained in its own directory with its own documentation.

## Requirements

Individual script requirements are documented in each script's directory. Common dependencies may include:
- `jq` - JSON processor
- `tar` - Archive extraction tool
- `bash` - Shell interpreter

## Contributing

Each script should:
- Be self-contained in its own directory
- Include a comprehensive README.md
- Have clear error handling and user feedback
- Follow bash best practices

## License

[Add your license information here]

