# Placeholder phrases from the Appverse README template
# (https://github.com/tamu-edu/appverse_readme_template, README.md). A README
# line containing any of these (case-insensitive substring) is recorded in
# readme.json "placeholders"; a README rung whose section holds nothing else
# is marked placeholder. One phrase per line; blank lines and lines starting
# with "# " are ignored. Keep phrases specific enough that a filled-in README
# does not match them.
[Application Name]
[App Name]
[software name and version]
[desktop / web server / notebook]
[researchers / students / etc.]
[brief use case]
[web-based tool / service]
[widget / dashboard]
[what it does]
[audience]
[software homepage](https://example.com)
[Software Name](https://example.com)
![Application running in browser](docs/screenshot.png)
[software] via [VNC desktop / web server / Jupyter]
[GPU / CPU / both]
[memory / cores / wall time]
[Containerized via Singularity/Apptainer | Module-based]
[Any other notable features
[Software name] [version constraints
[Runtime dependencies, e.g.,
[Container runtime, e.g.,
[Window manager, e.g.,
[Operating System, e.g.,
[minimum version, e.g.,
[Scheduler: Slurm / PBS / LSF]
[Lmod or Environment Modules]
[TurboVNC, VirtualGL]
[Database or dataset paths]
YOUR-ORG/YOUR-APP
module load software/1.0
module spider software
"software/1.0"
"my_cluster"
SOFTWARE_DB_PATH
Override default container image path
[App URL]
[Category]
[Your Institution]
[Any app-specific verification
[e.g.,
[funding agency]
[award number]
In this optional section you can include details of how to install the underlying software
2-3 sentences: What does this app launch?
Pick the app type that matches yours
Add real issues you've encountered during testing.
Be honest about what doesn't work or hasn't been tested.
Replace with your own funding information.
Key feature 1
Please see the [References section](#software-installation)
Batch Connect / Passenger apps:
Widgets / Dashboards — check OOD docs for the correct path
YOUR-APP
Pin to a release (recommended)
git checkout v1.0.0
Edit `form.yml` and update these values for your cluster:
Edit `manifest.yml` and update these values for your organization:
| `description` | Your cluster and your documentation |
| `bc_num_hours` | Maximum wall time (hours) | `4` |
| `bc_num_slots` | Number of cores | `1` |
| `partition` | Default scheduler partition | `"batch"` |
| `memory` | Memory per job (GB) | `8` |
No OOD restart is needed (Batch Connect apps are detected automatically).
Job starts but app doesn't appear
For VNC apps, verify the window manager is installed: `which xfwm4`
"Module not found" error
The module name in `form.yml` doesn't match your system.
The app may need more time to start. Increase the connection timeout
Launch the app from the OOD dashboard with default settings
Confirm the application loads in the browser
