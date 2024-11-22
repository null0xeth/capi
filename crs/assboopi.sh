#!/bin/bash

# Ensure kubectl is installed and configured correctly
if ! command -v kubectl &>/dev/null; then
	echo "kubectl is not installed. Please install it first."
	exit 1
fi

# Get all CRDs
crds=$(kubectl get crds -o name)

# Check if there are any CRDs
if [ -z "$crds" ]; then
	echo "No CRDs found in the cluster."
	exit 0
fi

echo "Found the following CRDs:"
echo "$crds"

# Iterate through each CRD
for crd in $crds; do
	echo "Processing $crd..."

	# Get the namespace and names of all resources for the CRD
	resources=$(kubectl get "$crd" --all-namespaces -o json | jq -r '.items[] | [.metadata.namespace, .metadata.name] | @tsv')

	if [ -z "$resources" ]; then
		echo "No resources found for $crd."
	else
		# Iterate over each resource
		echo "Removing resources for CRD: $crd"
		while IFS=$'\t' read -r namespace name; do
			if [ -z "$namespace" ]; then
				namespace="default"
			fi

			echo "Removing finalizers for resource: $name in namespace: $namespace"
			kubectl patch "$crd" "$name" -n "$namespace" --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'

			echo "Deleting resource: $name in namespace: $namespace"
			kubectl delete "$crd" "$name" -n "$namespace" --force --grace-period=0
		done <<<"$resources"
	fi

	# Finally, delete the CRD itself
	echo "Deleting CRD: $crd"
	kubectl delete "$crd" --force --grace-period=0
done

echo "All CRDs and their resources have been processed."
