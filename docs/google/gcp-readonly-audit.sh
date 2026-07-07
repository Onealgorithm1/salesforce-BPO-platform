#!/usr/bin/env bash
# gcp-readonly-audit.sh — COMPLETE read-only inventory of onealgorithm-bpo.
# Runs ONLY list/describe calls. Creates, modifies, and deletes NOTHING.
# Prereq: `gcloud auth login` completed. Usage: bash gcp-readonly-audit.sh [PROJECT_ID]
set -uo pipefail
PROJECT="${1:-onealgorithm-bpo}"
run() { echo; echo "===== $1 ====="; shift; "$@" 2>&1 || echo "(command failed / API not enabled / permission denied)"; }

echo "READ-ONLY AUDIT — project: $PROJECT — $(date -u)"
run "1. Authenticated accounts"        gcloud auth list
run "2. Active config"                 gcloud config list
run "3/4. Project (id/number/state)"   gcloud projects describe "$PROJECT" --format="value(projectId,projectNumber,lifecycleState)"
run "5. Billing"                        gcloud billing projects describe "$PROJECT"
run "6. Enabled APIs"                   gcloud services list --enabled --project "$PROJECT"
run "7. IAM policy"                     gcloud projects get-iam-policy "$PROJECT" --format=json
run "8. Service accounts"               gcloud iam service-accounts list --project "$PROJECT"
run "9. API keys"                       gcloud services api-keys list --project "$PROJECT"
run "10. Workload Identity pools"       gcloud iam workload-identity-pools list --location=global --project "$PROJECT"
run "11. Secret Manager secrets"        gcloud secrets list --project "$PROJECT"
run "12. Storage buckets"               gcloud storage buckets list --project "$PROJECT"
run "13. BigQuery datasets"             bq --project_id="$PROJECT" ls
run "14. Cloud Run services"            gcloud run services list --project "$PROJECT"
run "15. Cloud Functions"               gcloud functions list --project "$PROJECT"
run "16. Pub/Sub topics"                gcloud pubsub topics list --project "$PROJECT"
run "17. Cloud Scheduler jobs"          gcloud scheduler jobs list --project "$PROJECT"
run "18. Artifact Registry repos"       gcloud artifacts repositories list --project "$PROJECT"
run "19. Logging sinks"                 gcloud logging sinks list --project "$PROJECT"
run "20. Monitoring policies"           gcloud alpha monitoring policies list --project "$PROJECT"
run "21. Cloud Build (recent)"          gcloud builds list --limit=5 --project "$PROJECT"
run "22. Source repositories"           gcloud source repos list --project "$PROJECT"
run "23. Organizations"                 gcloud organizations list
run "24. Folders (needs org id)"        bash -c 'echo "run: gcloud resource-manager folders list --organization=<ORG_ID> after item 23"'
run "25. AI services enabled"           bash -c "gcloud services list --enabled --project '$PROJECT' | grep -Ei 'aiplatform|generativelanguage|cloudaicompanion' || echo none"
run "26. Consumer quota (sample)"       gcloud services list --enabled --project "$PROJECT" --format="value(config.name)"
echo; echo "AUDIT COMPLETE (read-only). Nothing was created or modified."
