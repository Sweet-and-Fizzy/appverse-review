# HPC Debugger

Interactive parallel debugger (DDT/MAP) for MPI applications, running inside a
VNC desktop session on the Falcon cluster.

## Overview

Launches ARM Forge DDT or MAP inside a Batch Connect VNC session, with MPI
host discovery and multi-node support.

## Requirements

- ARM Forge DDT/MAP 21.x or 22.x installed as environment modules
- Intel MPI or MVAPICH2 available on compute nodes
- VirtualGL for GPU-accelerated rendering (optional)

## Installation

Clone into your OOD apps directory:

```bash
cd /var/www/ood/apps/sys
git clone https://github.com/example/ood-hpc-debugger.git hpc_debugger
```

## Configuration

Edit `form.yml.erb` to adjust:
- Available debugger versions (update the `version` select options)
- Node types and core counts for your cluster
- Cluster name (currently set to `falcon`)

The `account_cache` module in `form.yml.erb` provides dynamic account lookups —
replace with your site's account resolution mechanism.
