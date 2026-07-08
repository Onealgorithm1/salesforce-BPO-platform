#!/usr/bin/env bash
# Daily Lead Enrichment Audit — read-only SOQL evidence pack + PASS/WARN/FAIL verdict.
# Answers the operational questions in docs/LEAD_ENRICHMENT_MONITORING.md §6 from live telemetry.
# Read-only: SELECT/COUNT only. Makes NO writes and enables nothing.
#
# Usage:  scripts/shell/daily_enrichment_audit.sh [orgUsername] [lookbackDays]
#   orgUsername   default: oauser@pboedition.com   (must resolve to org 00Dbn00000plgUfEAI)
#   lookbackDays  default: 1                        (window for "today"; use 7 for a weekly sweep)
set -euo pipefail

O="${1:-oauser@pboedition.com}"
DAYS="${2:-1}"
REQUIRED_ORG="00Dbn00000plgUfEAI"

cnt(){ sf data query -o "$O" ${2:+-t} -q "$1" --json 2>/dev/null \
        | grep -o '"totalSize": *[0-9]*' | head -1 | grep -o '[0-9]*'; }
say(){ printf '%-42s %s\n' "$1" "$2"; }

# --- Guardrail: confirm the org before reading anything ---
ORG_ID="$(sf org display -o "$O" --json 2>/dev/null | grep -o '"id": "[^\"]*"' | head -1 | cut -d'"' -f4)"
if [ "$ORG_ID" != "$REQUIRED_ORG" ]; then
  echo "STOP — authenticated org is '$ORG_ID', expected '$REQUIRED_ORG'. Aborting."; exit 2
fi
echo "=== Daily Lead Enrichment Audit ==="
echo "org=$ORG_ID  user=$O  window=LAST_N_DAYS:$DAYS"
echo

# --- Run activity in window ---
W="Started__c = LAST_N_DAYS:${DAYS}"
RUNS=$(cnt "SELECT COUNT() FROM OA_Connector_Run__c WHERE $W")
RUNS_FAILED=$(cnt "SELECT COUNT() FROM OA_Connector_Run__c WHERE $W AND Status__c='Failed'")
RUNS_PARTIAL=$(cnt "SELECT COUNT() FROM OA_Connector_Run__c WHERE $W AND Status__c='PartialErrors'")
HTTP_ERR=$(sf data query -o "$O" -q "SELECT SUM(HTTP_Errors__c) s FROM OA_Connector_Run__c WHERE $W" --json 2>/dev/null | grep -o '"s": *[0-9.]*' | grep -o '[0-9.]*' | head -1)
ENRICHED_FIELDS=$(sf data query -o "$O" -q "SELECT SUM(Records_Enriched__c) s FROM OA_Connector_Run__c WHERE $W" --json 2>/dev/null | grep -o '"s": *[0-9.]*' | grep -o '[0-9.]*' | head -1)
say "runs in window:"        "${RUNS:-0}  (failed=${RUNS_FAILED:-0}, partial=${RUNS_PARTIAL:-0})"
say "HTTP errors (sum):"     "${HTTP_ERR:-0}"
say "fields written (sum):"  "${ENRICHED_FIELDS:-0}"

# --- Field-level activity in window ---
CW="Changed_At__c = LAST_N_DAYS:${DAYS}"
WRITES=$(cnt "SELECT COUNT() FROM OA_Enrichment_Change_Log__c WHERE $CW AND Change_Type__c='Enrich'")
ROLLBACKS=$(cnt "SELECT COUNT() FROM OA_Enrichment_Change_Log__c WHERE $CW AND Change_Type__c='Rollback'")
NONREVERSIBLE=$(cnt "SELECT COUNT() FROM OA_Enrichment_Change_Log__c WHERE $CW AND Change_Type__c='Enrich' AND Reversible__c=false")
LEADS_ENRICHED=$(sf data query -o "$O" -q "SELECT COUNT_DISTINCT(Target_Record_Id__c) d FROM OA_Enrichment_Change_Log__c WHERE $CW AND Change_Type__c='Enrich'" --json 2>/dev/null | grep -o '"d": *[0-9]*' | grep -o '[0-9]*' | head -1)
say "leads enriched (distinct):" "${LEADS_ENRICHED:-0}"
say "field writes / rollbacks:"  "${WRITES:-0} / ${ROLLBACKS:-0}"
say "writes NOT reversible:"     "${NONREVERSIBLE:-0}"

# --- Exceptions / conflicts ---
CONFLICTS_NEW=$(cnt "SELECT COUNT() FROM OA_Enrichment_Exception__c WHERE CreatedDate = LAST_N_DAYS:${DAYS} AND Exception_Type__c='SourceConflict'")
EXC_OPEN=$(cnt "SELECT COUNT() FROM OA_Enrichment_Exception__c WHERE Status__c!='Resolved'")
say "new source conflicts:"    "${CONFLICTS_NEW:-0}"
say "open exceptions (total):" "${EXC_OPEN:-0}"

# --- Dormant state ---
CONN_ON=$(cnt "SELECT COUNT() FROM OA_Connector_Registry__mdt WHERE Enabled__c=true")
POL_ON=$(cnt "SELECT COUNT() FROM OA_Field_Write_Policy__mdt WHERE Active__c=true")
CRON=$(cnt "SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE '%nrich%'")
JOBS=$(cnt "SELECT COUNT() FROM AsyncApexJob WHERE Status IN ('Processing','Queued','Preparing') AND ApexClass.Name LIKE 'OA_Enrichment%'")
say "enabled connectors:"      "${CONN_ON:-0}"
say "active write policies:"   "${POL_ON:-0}"
say "enrichment cron / jobs:"  "${CRON:-0} / ${JOBS:-0}"
DORMANT=$([ "${CONN_ON:-0}" = 0 ] && [ "${POL_ON:-0}" = 0 ] && [ "${CRON:-0}" = 0 ] && [ "${JOBS:-0}" = 0 ] && echo yes || echo no)
say "platform dormant now:"    "$DORMANT"

# --- Verdict ---
echo
VERDICT="PASS — No action required"
# WARN conditions
if [ "${RUNS_PARTIAL:-0}" -gt 0 ] || [ "${CONFLICTS_NEW:-0}" -gt 0 ] || [ "${EXC_OPEN:-0}" -gt 0 ] || [ "$DORMANT" != "yes" ]; then
  VERDICT="WARN — Operational review required"
fi
# FAIL conditions (override WARN)
if [ "${RUNS_FAILED:-0}" -gt 0 ] || [ "${NONREVERSIBLE:-0}" -gt 0 ]; then
  VERDICT="FAIL — Engineering fix required"
fi
echo "$VERDICT"
