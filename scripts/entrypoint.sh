#!/bin/bash
set -e

function error_exit
{
  echo "ERROR: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

# Kubectl setup
aws eks update-kubeconfig --name $K8S_CLUSTER_NAME 1>/dev/null

exec "$@"
