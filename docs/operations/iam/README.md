# IAM policies for in-cluster ESO users

Policy documents only. Nothing here is applied by Flux; a human (Landry, or
with his OK) creates the IAM objects.

## monitoring-eso-policy.json

Identity policy for IAM user `monitoring-eso`, the External Secrets Operator
user behind SecretStore `monitoring/aws-secret-store` (PR #386, reused by #390).

- `ssm:GetParameter` on exactly three SecureString parameters in account
  584144127892, us-east-1: `/grafana/admin` (#386), `/alertmanager/smtp` and
  `/alertmanager/healthchecks` (#390). No `GetParameterHistory`, no
  `GetParametersByPath`, no other parameters. The parameters use the
  AWS-managed `aws/ssm` key, so no KMS grant is needed.
- The user is created under path `/svc/`
  (`arn:aws:iam::584144127892:user/svc/monitoring-eso`) with its own
  permissions boundary `svc-monitoring-boundary`, not the shared
  `svc-boundary`. That boundary allows the same three ARNs and nothing else;
  it is defined in Mel's grok-bots narrow-policy proposal (under review by
  Norbert, not yet created).
- Its access key goes only into the SOPS-encrypted `aws-credentials` Secret in
  the `monitoring` namespace.
