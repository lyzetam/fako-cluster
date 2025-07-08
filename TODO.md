# TODO

## Secrets and IP Removal
- ✔ Remove direct IP references from `apps/base/ollama-webui/configmap.yaml`; new configmap is generated without IPs and credentials are loaded from `gpustack-config`.
- ✔ Use `apply-storageclass-job.yaml` with templates so storage classes read the NFS server address from `nfs-server-config`.
- ✔ Confirmed `apply-storageclass-job.yaml` handles storage class creation with decrypted secrets via Flux.

## Documentation
- ✔ Update `README.md` with notes on new secrets management approach using SOPS and `apply-storageclass-job`.


