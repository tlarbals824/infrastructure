#!/usr/bin/env bash
# Basic OKE cannot cycle a node pool. After Terraform updates the pool spec,
# delete each stale worker with isDecrementSize=false so OKE terminates that
# instance and creates one replacement in the same pool. Never scale above 2.
# Only the boot volume recorded from the instance being deleted may be removed.
set -euo pipefail

: "${OCI_CLI_USER:?}"
: "${OCI_CLI_TENANCY:?}"
: "${OCI_CLI_FINGERPRINT:?}"
: "${OCI_CLI_KEY_CONTENT:?}"
: "${OCI_COMPARTMENT_OCID:?}"
: "${NODE_POOL_ID:?}"

export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True
export SUPPRESS_LABEL_WARNING=True
mkdir -p "${HOME}/.oci"
chmod 700 "${HOME}/.oci"
printf '%s\n' "${OCI_CLI_KEY_CONTENT}" > "${HOME}/.oci/key.pem"
cat > "${HOME}/.oci/config" <<EOF
[DEFAULT]
user=${OCI_CLI_USER}
fingerprint=${OCI_CLI_FINGERPRINT}
tenancy=${OCI_CLI_TENANCY}
region=ap-chuncheon-1
key_file=${HOME}/.oci/key.pem
EOF
chmod 600 "${HOME}/.oci/key.pem" "${HOME}/.oci/config"

command -v oci >/dev/null
command -v jq >/dev/null

pool_json() {
  oci ce node-pool get --node-pool-id "${NODE_POOL_ID}" --output json
}

# OKE keeps DELETED nodes in the pool list. Only ACTIVE nodes count toward size 2.
# A node that is still DELETING or CREATING is waited out, not treated as a third instance.
wait_until_settled() {
  local deadline=$((SECONDS + 1800))
  local pool active inflight
  while (( SECONDS < deadline )); do
    pool="$(pool_json)"
    active="$(jq '[.data.nodes[] | select(.["lifecycle-state"] == "ACTIVE")] | length' <<<"${pool}")"
    inflight="$(jq '[.data.nodes[] | select(.["lifecycle-state"] != "ACTIVE" and .["lifecycle-state"] != "DELETED")] | length' <<<"${pool}")"
    if (( active > 2 )); then
      echo "node pool has ${active} ACTIVE nodes; refusing to continue" >&2
      exit 1
    fi
    if (( active == 2 && inflight == 0 )); then
      printf '%s\n' "${pool}"
      return 0
    fi
    echo "waiting for 2 ACTIVE nodes (active=${active} inflight=${inflight})" >&2
    sleep 20
  done
  echo "node pool did not return to 2 ACTIVE nodes" >&2
  exit 1
}

boot_volume_gone() {
  local bv="$1"
  local state
  state="$(oci bv boot-volume get --boot-volume-id "${bv}" --query 'data."lifecycle-state"' --raw-output 2>/dev/null || echo "GONE")"
  [[ "${state}" != "AVAILABLE" && "${state}" != "PROVISIONING" ]]
}

ensure_boot_volume_deleted() {
  local bv="$1"
  local attempt state
  for attempt in $(seq 1 18); do
    if boot_volume_gone "${bv}"; then
      echo "boot volume ${bv} is no longer available"
      return 0
    fi
    sleep 10
  done
  state="$(oci bv boot-volume get --boot-volume-id "${bv}" --query 'data."lifecycle-state"' --raw-output 2>/dev/null || echo "GONE")"
  if [[ "${state}" == "AVAILABLE" ]]; then
    echo "deleting recorded boot volume ${bv}"
    oci bv boot-volume delete --boot-volume-id "${bv}" --force --wait-for-state TERMINATED --max-wait-seconds 180
  fi
}

pool="$(wait_until_settled)"
desired_version="$(jq -r '.data["kubernetes-version"]' <<<"${pool}")"
desired_image="$(jq -r '.data["node-image-id"] // .data["node-source-details"]["image-id"] // empty' <<<"${pool}")"
if [[ -z "${desired_image}" || "${desired_image}" == "null" ]]; then
  echo "node pool has no image id"
  exit 1
fi
echo "pool ${NODE_POOL_ID} wants ${desired_version} image ${desired_image}"

stale=()
while read -r id; do
  [[ -n "${id}" ]] || continue
  instance="$(oci compute instance get --instance-id "${id}" --output json)"
  image="$(jq -r '.data["source-details"]["image-id"] // empty' <<<"${instance}")"
  version="$(jq -r --arg id "${id}" '.data.nodes[] | select(.id == $id) | .["kubernetes-version"] // empty' <<<"${pool}")"
  if [[ "${image}" != "${desired_image}" ]] || { [[ -n "${version}" ]] && [[ "${version}" != "${desired_version}" ]]; }; then
    echo "stale node ${id} version=${version:-unknown} image=${image}"
    stale+=("${id}")
  else
    echo "node ${id} already matches"
  fi
done < <(jq -r '.data.nodes[] | select(.["lifecycle-state"] == "ACTIVE") | .id' <<<"${pool}")

if (( ${#stale[@]} == 0 )); then
  echo "no stale workers"
  exit 0
fi

for old_id in "${stale[@]}"; do
  pool="$(wait_until_settled)"
  if ! jq -e --arg id "${old_id}" '.data.nodes[] | select(.id == $id)' >/dev/null <<<"${pool}"; then
    echo "node ${old_id} is already gone"
    continue
  fi

  instance="$(oci compute instance get --instance-id "${old_id}" --output json)"
  ad="$(jq -r '.data["availability-domain"]' <<<"${instance}")"
  compartment="$(jq -r '.data["compartment-id"]' <<<"${instance}")"
  if [[ "${compartment}" != "${OCI_COMPARTMENT_OCID}" ]]; then
    echo "instance ${old_id} is in ${compartment}, not the configured compartment"
    exit 1
  fi
  bv="$(oci compute boot-volume-attachment list \
    --compartment-id "${compartment}" \
    --availability-domain "${ad}" \
    --instance-id "${old_id}" \
    --all \
    --query 'data[0]."boot-volume-id"' \
    --raw-output)"
  if [[ -z "${bv}" || "${bv}" == "null" ]]; then
    echo "refusing to delete ${old_id} without its boot volume id"
    exit 1
  fi
  echo "deleting node ${old_id} boot volume ${bv}"

  oci ce node-pool delete-node \
    --node-pool-id "${NODE_POOL_ID}" \
    --node-id "${old_id}" \
    --is-decrement-size false \
    --override-eviction-grace-duration PT20M \
    --is-force-deletion-after-override-grace-duration true \
    --force \
    --wait-for-state SUCCEEDED \
    --max-wait-seconds 2700

  pool="$(wait_until_settled)"
  if jq -e --arg id "${old_id}" '.data.nodes[] | select(.id == $id and .["lifecycle-state"] != "DELETED")' >/dev/null <<<"${pool}"; then
    echo "node ${old_id} is still in the pool"
    exit 1
  fi
  ensure_boot_volume_deleted "${bv}"
done

echo "worker replacement finished"
