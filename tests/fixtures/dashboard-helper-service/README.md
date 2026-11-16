# Cluster Desktop

An Open OnDemand interactive app that starts an XFCE desktop on a compute
node and connects to it through noVNC. The form shows the latest site news
so users see maintenance notices before they launch.

## Requirements

- Open OnDemand 3.0 or later
- XFCE installed on the compute nodes
- A Slurm cluster named `summit`

## Installation

Copy the app into the system apps directory:

```
cp -r cluster_desktop /var/www/ood/apps/sys/
```

## Usage

Choose the number of cores and hours, give the session a label, and launch.
Click Launch Desktop on the session card once the job starts.

## Known Limitations

Only one desktop per user can run at a time.
