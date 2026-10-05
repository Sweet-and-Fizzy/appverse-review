# Fixture Shared-Risk Monorepo

Two Batch Connect apps used to test that a security finding in one app
decides every app in the repo.

## Requirements
JupyterLab installed on compute nodes.

## Installation
Clone into your OOD app directory and link the app you want under
`/var/www/ood/apps/sys/`.

## Configuration
Set the cluster in each app's `form.yml` for your site.
