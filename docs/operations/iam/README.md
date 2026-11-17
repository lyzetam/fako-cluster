# IAM policies for in-cluster ESO users

Policy documents only. Nothing here is applied by Flux; a human (Landry, or
with his OK) creates the IAM objects.

## monitoring-eso-policy.json

Identity policy for IAM user `monitoring-eso`, the External Secrets Operator
user behind SecretStore `monitoring/aws-secret-store` (PR #386, reused by #390).

- `ssm:GetParameter` on exactly three SecureString parameters in account
  <ACCOUNT_ID>, us-east-1: `/grafana/admin` (#386), `/alertmanager/smtp` and
  `/alertmanager/healthchecks` (#390). No `GetParameterHistory`, no
  `GetParametersByPath`, no other parameters. The parameters use the
  AWS-managed `aws/ssm` key, so no KMS grant is needed.
- The user is created under path `/svc/`
  (`arn:aws:iam::<ACCOUNT_ID>:user/svc/monitoring-eso`) with its own
  permissions boundary `svc-monitoring-boundary`, not the shared
  `svc-boundary`. That boundary is this same policy document, so it allows the
  same three ARNs and nothing else.
- Its access key goes only into the SOPS-encrypted `aws-credentials` Secret in
  the `monitoring` namespace
  (`monitoring/controllers/base/kube-prometheus-stack/aws-credentials-secret.yaml`).

Created 2026-11-17: policy `svc-monitoring-boundary`, user `svc/monitoring-eso`
(boundary attached), inline policy `monitoring-eso-ssm-read`, SSM parameter
`/grafana/admin`. The account ID is kept out of this public repo; substitute it
before use:

```bash
ACCT=$(aws sts get-caller-identity --query Account --output text)
sed "s/<ACCOUNT_ID>/$ACCT/g" docs/operations/iam/monitoring-eso-policy.json > /tmp/p.json
```
