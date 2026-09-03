# Runbook: Lots 1 to 3

## Operating boundaries

This runbook provisions and validates only the Scaleway development pilot. Stop if a plan contains Azure, NetBird, DNS, Helm, Onizuka, or any resource outside the intended Scaleway project.

The target architecture is:

- Region: `fr-par`
- Zone: `fr-par-1`
- Cluster: `kapsule-scw-dev-01`
- Control plane: mutualized public Kapsule API, restricted by an explicit non-empty ACL
- Workers: `DEV1-M`, initial size 2, autoscaling from 1 to 3, autohealing, containerd, no public IP
- Networking: routed VPC, custom route propagation, explicit Private Network IPv4 subnet, NAT egress through a Public Gateway and Flexible IP
- State: private and versioned Scaleway Object Storage bucket

## Lot 1: state and CI identity bootstrap

The bootstrap is an optional one-time stack that resolves the dependency cycle between Terraform and its remote backend. The Kapsule stack cannot initialize against a state bucket or run under a CI identity until those resources exist. Skip this stack when an equivalent bucket and IAM application are managed elsewhere.

### Prepare privileged bootstrap credentials

Use a temporary operator credential authorized to create Object Storage and IAM resources:

```bash
export SCW_ACCESS_KEY="<bootstrap-access-key>"
export SCW_SECRET_KEY="<bootstrap-secret-key>"
cp kapsule/bootstrap/terraform.tfvars.example kapsule/bootstrap/terraform.tfvars
```

Set the real project UUID, organization UUID, and a globally unique bucket name in `kapsule/bootstrap/terraform.tfvars`.

### Initialize, review, and apply

```bash
terraform -chdir=kapsule/bootstrap init
terraform -chdir=kapsule/bootstrap fmt -check
terraform -chdir=kapsule/bootstrap validate
terraform -chdir=kapsule/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=kapsule/bootstrap show bootstrap.tfplan
terraform -chdir=kapsule/bootstrap apply bootstrap.tfplan
```

Expected resources:

- one Object Storage bucket with private ACL, versioning enabled, and `force_destroy = false`
- one IAM application for GitHub Actions
- one IAM policy scoped to the pilot project

The project policy contains only the required product permission sets:

- `KubernetesFullAccess`
- `InstancesFullAccess`
- `BlockStorageFullAccess`
- `VPCFullAccess`
- `PrivateNetworksFullAccess`
- `IPAMFullAccess`
- `VPCGatewayFullAccess`
- `LoadBalancersFullAccess`
- `ObjectStorageBucketsRead`
- `ObjectStorageObjectsRead`
- `ObjectStorageObjectsWrite`
- `ObjectStorageObjectsDelete`

The permission sets are broad within their products but are restricted to the pilot project. Review them again when narrower Scaleway permission sets can satisfy the same provider operations.

### Create the CI API key manually

Terraform intentionally does not create `scaleway_iam_api_key`, because its secret would be stored in local bootstrap state.

1. Read the application ID without exposing any secret:

   ```bash
   terraform -chdir=kapsule/bootstrap output -raw ci_application_id
   ```

2. In the Scaleway console, open IAM Applications, select that application, and create an API key.
3. Save the access key and secret key directly in the protected GitHub environment `scaleway-dev`.
4. Delete any temporary plaintext copy immediately.
5. Restrict and back up `kapsule/bootstrap/terraform.tfstate`; it remains the source of truth for the bucket, application, and policy.

### Configure GitHub

Set these `scaleway-dev` environment secrets:

- `SCW_ACCESS_KEY`
- `SCW_SECRET_KEY`

Set these `scaleway-dev` environment variables:

- `SCW_PROJECT_ID`
- `SCW_ORGANIZATION_ID`
- `SCW_TF_STATE_BUCKET`
- `SCW_API_ALLOWED_CIDRS_JSON`

`SCW_API_ALLOWED_CIDRS_JSON` must be valid JSON containing at least one stable IPv4 CIDR, for example:

```json
["198.51.100.10/32"]
```

The example address is reserved for documentation and must be replaced. Configure environment protection and required reviewers. Prefer a self-hosted runner or a controlled egress gateway with a stable address; do not allow all GitHub-hosted runner ranges merely to make API access work.

## Lot 2: network and Kapsule

### Verify address planning

The default pilot ranges are:

- Private Network: `172.30.0.0/20`
- Kubernetes pods: `172.31.0.0/16`
- Kubernetes services: `172.29.0.0/20`

Before deployment, compare all three ranges with:

- Azure VNet and AKS node, pod, and service ranges
- on-premises and VPN ranges
- NetBird routes
- any other Scaleway network, pod, and service ranges

Record the approved non-overlapping CIDR in the change request. This check does not create inter-cloud connectivity; that work is deferred.

### Configure the backend and variables

```bash
cp kapsule/environments/scw-dev-01/backend.tfvars.example kapsule/environments/scw-dev-01/backend.tfvars
cp kapsule/environments/scw-dev-01/variables.tfvars.example kapsule/environments/scw-dev-01/variables.tfvars
```

Set the bootstrap bucket name in `kapsule/environments/scw-dev-01/backend.tfvars`. Set the project and organization UUIDs, approved Private Network CIDR, and operator API CIDRs in `kapsule/environments/scw-dev-01/variables.tfvars`.

Export the manually created CI API key:

```bash
export AWS_ACCESS_KEY_ID="<ci-access-key>"
export AWS_SECRET_ACCESS_KEY="<ci-secret-key>"
export SCW_ACCESS_KEY="<ci-access-key>"
export SCW_SECRET_KEY="<ci-secret-key>"
```

The `AWS_*` variables authenticate the S3-compatible backend. The `SCW_*` variables authenticate the Scaleway provider. Do not add these values to HCL files.

### Initialize and plan

```bash
cd kapsule/00-kapsule
terraform init -backend-config=../environments/scw-dev-01/backend.tfvars
terraform fmt -check -recursive ../..
terraform validate
terraform plan \
  -var-file=../environments/scw-dev-01/variables.tfvars \
  -lock-timeout=10m \
  -out=dev.tfplan
terraform show dev.tfplan
```

Review these invariants before apply:

- cluster type is `kapsule`, CNI is `cilium`, and the Kubernetes version is explicit
- `delete_additional_resources` is `false`
- the ACL contains only approved CIDRs and never `0.0.0.0/0`
- the pool has `public_ip_disabled = true`
- initial, minimum, and maximum pool sizes are 2, 1, and 3
- the node security group drops unmatched inbound traffic
- the Gateway Network enables masquerade and pushes the default route

Scaleway initially creates a Kapsule cluster with a default `0.0.0.0/0` ACL. Terraform then replaces it through `scaleway_k8s_acl`. Treat this short provisioning window as a known provider/API limitation; the final state must contain only the explicit allowlist.

### Apply

Only apply an approved saved plan:

```bash
terraform apply -lock-timeout=10m dev.tfplan
```

Do not print the `kubeconfig` output. Non-sensitive operational outputs can be read individually:

```bash
terraform output cluster_name
terraform output cluster_api_url
terraform output vpc_id
terraform output private_network_id
terraform output public_gateway_ip
```

### GitHub deployment workflow

Run `Terraform plan or apply` manually:

1. Select `plan` for review-only execution.
2. Inspect the workflow output and Scaleway environment approval.
3. Start a new dispatch and select `apply` only after approval.

The workflow serializes executions with one concurrency group. It never embeds backend or provider credentials in command arguments.

## Lot 3: runtime validation

### Run all probes

Run from an ACL-authorized network:

```bash
./kapsule/scripts/validate-cluster.sh
```

If a kubeconfig is already managed securely:

```bash
KUBECONFIG="/secure/path/scaleway.kubeconfig" ./kapsule/scripts/validate-cluster.sh
```

The script:

1. waits for all worker nodes to become `Ready`
2. fails if any worker node reports an `ExternalIP`
3. verifies internal and external DNS plus HTTP egress
4. provisions a Service annotated with `service.beta.kubernetes.io/scw-loadbalancer-private: "true"` and verifies that its address is private
5. provisions an unqualified PVC through the default StorageClass and mounts it in a workload
6. deletes the dedicated `scaleway-platform-validation` namespace by default

The Terraform kubeconfig output is redirected to a mode `0600` temporary file and removed by the exit trap. Its value is never logged.

For troubleshooting, retain resources explicitly:

```bash
./kapsule/scripts/validate-cluster.sh --keep
```

Delete retained resources after inspection:

```bash
kubectl delete namespace scaleway-platform-validation
```

### Failure handling

- API timeout: verify the caller's public egress CIDR is present in `api_allowed_cidrs`.
- Node lacks egress: inspect the Gateway Network default route, masquerade setting, and Public Gateway status.
- Node has an ExternalIP: stop the pilot and reconcile the pool before deploying workloads.
- Private LoadBalancer receives a public address: delete the validation namespace and inspect the service annotation and cloud controller events.
- PVC remains pending: inspect the default StorageClass and CSI controller events.

## Deferred work and known limits

- No Azure or inter-cloud route is configured.
- No NetBird route or peer is configured.
- No DNS record is created.
- No Helm chart or Onizuka component is deployed.
- The control plane is public and ACL-filtered, not private.
- Required credentials and real project identifiers are intentionally absent from the repository.
- Kubernetes-created load balancers and volumes survive cluster deletion because `delete_additional_resources = false`; they must be inventoried and removed deliberately when decommissioning.
