#!/bin/bash

# This script refreshes all ArgoCD TLS secrets by deleting them,
# allowing the ArgoCD operator to recreate them with updated certificates.
# It does so by identifying secrets controlled by argoproj.io/v1beta1.ArgoCD resources.

set -euo pipefail

for nsname in $(kubectl get secrets -A --field-selector=type=kubernetes.io/tls -ojson | jq -r '.items[] | select(.metadata.ownerReferences // [] | any(.apiVersion=="argoproj.io/v1beta1" and .kind=="ArgoCD" and .controller==true)) | .metadata.namespace+"/"+.metadata.name'); do
  echo "Refreshing ArgoCD TLS secret: $nsname"
  kubectl -n "${nsname%%/*}" delete secret "${nsname##*/}"
done

echo "All ArgoCD TLS secrets have been refreshed."
