#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly KAPSULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

terraform_dir="${KAPSULE_DIR}/00-kapsule"
namespace="scaleway-platform-validation"
timeout="10m"
keep_resources="false"
kubeconfig_file=""
temporary_kubeconfig="false"
namespace_created="false"

usage() {
  printf '%s\n' "Usage: $0 [--terraform-dir PATH] [--namespace NAME] [--timeout DURATION] [--keep]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --terraform-dir)
      terraform_dir="${2:?Missing value for --terraform-dir}"
      shift 2
      ;;
    --namespace)
      namespace="${2:?Missing value for --namespace}"
      shift 2
      ;;
    --timeout)
      timeout="${2:?Missing value for --timeout}"
      shift 2
      ;;
    --keep)
      keep_resources="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

for command_name in terraform kubectl; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command_name}" >&2
    exit 1
  fi
done

cleanup() {
  local exit_code="$?"
  set +e

  if [[ "${keep_resources}" == "false" && "${namespace_created}" == "true" && -n "${kubeconfig_file}" ]]; then
    kubectl --kubeconfig "${kubeconfig_file}" delete namespace "${namespace}" --ignore-not-found --wait=false >/dev/null 2>&1
  fi

  if [[ "${temporary_kubeconfig}" == "true" && -n "${kubeconfig_file}" ]]; then
    rm -f "${kubeconfig_file}"
  fi

  exit "${exit_code}"
}

trap cleanup EXIT

if [[ -n "${KUBECONFIG:-}" ]]; then
  kubeconfig_file="${KUBECONFIG}"
  if [[ ! -r "${kubeconfig_file}" ]]; then
    printf 'KUBECONFIG is not readable: %s\n' "${kubeconfig_file}" >&2
    exit 1
  fi
else
  kubeconfig_file="$(mktemp "${TMPDIR:-/tmp}/infra-scaleway-kubeconfig.XXXXXX")"
  temporary_kubeconfig="true"
  chmod 600 "${kubeconfig_file}"
  terraform -chdir="${terraform_dir}" output -raw kubeconfig >"${kubeconfig_file}"
fi

kubectl_command=(kubectl --kubeconfig "${kubeconfig_file}")

printf '%s\n' "Checking Kapsule API access and worker nodes."
"${kubectl_command[@]}" version --request-timeout=30s >/dev/null
"${kubectl_command[@]}" wait --for=condition=Ready nodes --all --timeout="${timeout}"

node_count="$("${kubectl_command[@]}" get nodes -o jsonpath='{.items[*].metadata.name}' | awk '{ print NF }')"
if [[ "${node_count}" -lt 1 ]]; then
  printf '%s\n' "No Kubernetes worker nodes were found." >&2
  exit 1
fi

external_ips="$("${kubectl_command[@]}" get nodes -o jsonpath='{range .items[*].status.addresses[?(@.type=="ExternalIP")]}{.address}{"\n"}{end}')"
if [[ -n "${external_ips}" ]]; then
  printf '%s\n' "At least one worker node has an ExternalIP." >&2
  exit 1
fi

if "${kubectl_command[@]}" get namespace "${namespace}" >/dev/null 2>&1; then
  "${kubectl_command[@]}" delete namespace "${namespace}" --wait=true --timeout="${timeout}" >/dev/null
fi

"${kubectl_command[@]}" create namespace "${namespace}" >/dev/null
namespace_created="true"

printf '%s\n' "Checking cluster DNS and outbound internet access."
"${kubectl_command[@]}" apply -n "${namespace}" -f - >/dev/null <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: dns-egress
spec:
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: probe
          image: busybox:1.37.0
          command:
            - /bin/sh
            - -ec
            - nslookup kubernetes.default.svc.cluster.local && nslookup example.com && wget -q -T 20 -O /dev/null http://example.com
EOF

if ! "${kubectl_command[@]}" wait -n "${namespace}" --for=condition=Complete job/dns-egress --timeout="${timeout}"; then
  "${kubectl_command[@]}" logs -n "${namespace}" job/dns-egress >&2 || true
  exit 1
fi

printf '%s\n' "Checking private LoadBalancer provisioning."
"${kubectl_command[@]}" apply -n "${namespace}" -f - >/dev/null <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: private-load-balancer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: private-load-balancer
  template:
    metadata:
      labels:
        app: private-load-balancer
    spec:
      containers:
        - name: server
          image: registry.k8s.io/e2e-test-images/agnhost:2.53
          args:
            - netexec
            - --http-port=8080
          ports:
            - name: http
              containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: private-load-balancer
  annotations:
    service.beta.kubernetes.io/scw-loadbalancer-private: "true"
spec:
  type: LoadBalancer
  selector:
    app: private-load-balancer
  ports:
    - name: http
      port: 80
      targetPort: http
EOF

"${kubectl_command[@]}" rollout status -n "${namespace}" deployment/private-load-balancer --timeout="${timeout}"

load_balancer_ip=""
for _ in $(seq 1 60); do
  load_balancer_ip="$("${kubectl_command[@]}" get service -n "${namespace}" private-load-balancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
  if [[ -n "${load_balancer_ip}" ]]; then
    break
  fi
  sleep 10
done

if [[ -z "${load_balancer_ip}" ]]; then
  printf '%s\n' "The private LoadBalancer did not receive an IP address within 10 minutes." >&2
  exit 1
fi

IFS='.' read -r first_octet second_octet third_octet fourth_octet <<<"${load_balancer_ip}"
if ! {
  [[ "${first_octet}" == "10" ]] ||
    [[ "${first_octet}" == "192" && "${second_octet}" == "168" ]] ||
    [[ "${first_octet}" == "172" && "${second_octet}" -ge 16 && "${second_octet}" -le 31 ]]
}; then
  printf 'The LoadBalancer received a non-private IP address: %s\n' "${load_balancer_ip}" >&2
  exit 1
fi

printf '%s\n' "Checking default StorageClass dynamic PVC provisioning."
default_storage_class="$("${kubectl_command[@]}" get storageclass -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}')"
if [[ -z "${default_storage_class}" ]]; then
  printf '%s\n' "No default StorageClass is configured." >&2
  exit 1
fi

"${kubectl_command[@]}" apply -n "${namespace}" -f - >/dev/null <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: dynamic-storage
spec:
  restartPolicy: Never
  containers:
    - name: writer
      image: busybox:1.37.0
      command:
        - /bin/sh
        - -ec
        - printf validation > /data/result
      volumeMounts:
        - name: storage
          mountPath: /data
  volumes:
    - name: storage
      persistentVolumeClaim:
        claimName: dynamic-storage
EOF

"${kubectl_command[@]}" wait -n "${namespace}" --for=jsonpath='{.status.phase}'=Bound persistentvolumeclaim/dynamic-storage --timeout="${timeout}"
"${kubectl_command[@]}" wait -n "${namespace}" --for=jsonpath='{.status.phase}'=Succeeded pod/dynamic-storage --timeout="${timeout}"

printf '%s\n' "Validation completed successfully."
if [[ "${keep_resources}" == "true" ]]; then
  printf 'Validation resources were retained in namespace %s.\n' "${namespace}"
fi
