# Custom Conda Environment

Launch a Jupyter notebook with a user-specified Conda environment on the
Summit cluster, with on-the-fly package installation.

## Overview

This app lets users activate an existing Conda environment or create a new
one, optionally installing additional packages before launching JupyterLab.
Supports custom PyPI indexes for private package repositories and optional
environment setup scripts.

## Requirements

- Anaconda or Miniconda installed as an environment module (`anaconda3/2023.09`)
- Compute nodes with internet access for package installation

## Installation

```bash
cd /var/www/ood/apps/sys
git clone https://github.com/example/ood-custom-conda.git custom_conda
```

## Configuration

- Update `form.yml` cluster name and node types for your site
- Adjust `module load anaconda3/2023.09` in `template/script.sh.erb` if your
  module name differs
- The Singularity definition (`Singularity.def`) can be used to pre-build an
  image for environments that need offline support

## Known Limitations

- Package installation happens at job start and can be slow for large
  dependency trees
- Conda environment creation requires writable home directory space
