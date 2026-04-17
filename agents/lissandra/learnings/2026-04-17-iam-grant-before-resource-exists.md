## IAM grants on non-existent principals are silently orphaned

When a bootstrap script grants IAM to a service account that doesn't exist yet,
`gsutil iam ch` (and `gcloud projects add-iam-policy-binding`) succeed without error
but the binding is silently dropped when the SA is later created — GCP does not
retroactively apply orphaned bindings.

Pattern to flag: any script that grants IAM and has no declared dependency on the
SA/resource existing first. Check whether the SA creation step (typically `gcloud iam
service-accounts create`) precedes the grant within the same script, or whether the
script documents that a prerequisite task must run first with a guard/warning.

Remedy: either check `gcloud iam service-accounts describe $SA --project=$PROJECT`
before granting and abort/warn if absent, or make the IAM step conditional with a
clear message directing the operator to re-run after SA creation.
