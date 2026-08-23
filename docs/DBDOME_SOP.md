# DBDOME Standard Operating Procedures

**Product:** DBDOME Database Security and Monitoring Platform
**Applies to:** DBDOME 2.02.x
**Document version:** 1.0
**Date:** 2026-08-23
**Audience:** Security operations, DBAs, platform administrators
**Review cycle:** Annual, or on any major version change
**Classification:** Customer deliverable

---

## 1. Purpose and scope

This document defines the routine procedures for operating DBDOME: daily checks,
alert handling, onboarding of monitored databases, change control, backup and
escalation.

It assumes DBDOME is already installed and verified per the *DBDOME Installation
Guide*. It does not cover installation or upgrade, which that document owns.

**A note on what this platform is.** DBDOME is a detective control. It observes,
records and alerts. It is one control among many and does not replace backups,
patching, access governance or trained staff. Procedures below are written on
that assumption.

---

## 2. Roles and responsibilities

| Role | Responsibility |
|---|---|
| **Platform Administrator** | Availability of DBDOME itself; upgrades; backups; capacity |
| **Security Analyst** | Triage and disposition of alerts; tuning; incident escalation |
| **DBA** | Target-database credentials and access; validating findings against the database |
| **Data Protection Officer / Legal** | Lawful basis for monitoring; retention policy; access to monitoring data |
| **Approver** | Authorizes enabling of any enforcement feature (blocking, masking, suppression) |

Enforcement features are **never** enabled by the person who requests them.
Separation between requester and approver is required — see Section 8.

---

## 3. Daily operations

### 3.1 Morning platform health check

Perform each working day, ideally before the analyst shift starts.

**Step 1 — Services**

```powershell
Get-Service DBDOME_dbanalytics, DBDOME_web, DBDOME_Grafana, DBDOME_Ollama, postgresql-x64-18 |
  Format-Table Name, Status, StartType
```

All must be **Running**. A stopped `DBDOME_dbanalytics` means **no collection and
no alerting is occurring at all** — treat as a P1 incident, not a routine finding.

**Step 2 — Collection is live**

```sql
SELECT max(entry_date) AS last_collection
FROM monitoring.general_metric_metadata_results;
```

Must be recent and advancing between checks. A running service with a static
timestamp is a failure that service state does not reveal.

**Step 3 — Per-server freshness**

```sql
SELECT server, max(entry_date) AS last_seen
FROM monitoring.general_metric_metadata_results
GROUP BY server ORDER BY last_seen;
```

Investigate any server whose `last_seen` is materially behind the others.

> **Known failure mode — a dead target starves the whole sweep.** An unreachable
> target consumes the collection sweep waiting on timeouts. Metric families
> ordered later in the sweep silently stop updating while earlier ones stay
> current. The symptom is *partial* staleness, which looks like a metric problem
> but is actually one unreachable server. Always check this per-server view
> before investigating an individual metric.

**Step 4 — Open alerts**

Review the Open Alerts dashboard. Confirm the overnight queue has been triaged
and nothing is ageing beyond the SLA in Section 5.4.

**Step 5 — Internal health**

Review internal health alerts (disk, CPU, memory, service-down). DBDOME monitors
itself; these alerts are about the DBDOME host, not the targets.

### 3.2 Record

Log the check in the operations record: date, operator, outcome, any action
taken. This record is often the evidence auditors ask for.

---

## 4. Weekly and monthly operations

### 4.1 Weekly

| Task | Notes |
|---|---|
| Review alert volume and top rules | A rule producing constant alerts is a tuning problem, not a security finding |
| Review false-positive rate per rule | Feed into Section 6 tuning |
| Confirm backups completed and are restorable | A backup never test-restored is not a backup |
| Check disk headroom on the DBDOME host and PostgreSQL volume | |
| Review agent verdict quality | Section 7 |
| Confirm all expected servers are reporting | Section 3.1 step 3 |

### 4.2 Monthly

| Task | Notes |
|---|---|
| Review user access to DBDOME itself | Monitoring data is sensitive; restrict accordingly |
| Review retention against policy | |
| Review and re-approve any enabled enforcement feature | Section 8 |
| Patch review — DBDOME, PostgreSQL, Grafana, OS | |
| Capacity trend review | Partition growth, disk, RAM |
| Test the escalation path | Confirm on-call contacts still valid |

### 4.3 Quarterly

* Restore a database backup to a scratch host and verify integrity end to end.
* Review the monitoring scope against the lawful-basis assessment — scope drift
  is common and is a compliance exposure.
* Review this SOP for accuracy.

---

## 5. Alert handling

### 5.1 Lifecycle

```
   detection  ->  alert raised  ->  incident opened  ->  triage
                                                          |
                            +-----------------------------+
                            |                             |
                      true positive                 false positive
                            |                             |
                    contain / escalate              tune the rule
                            |                             |
                            +----------> resolve <--------+
```

Alerts are written to `alerts.alert_log`. Open incidents live in
`alerts.alert_incidents`. Incidents are resolved manually by the customer, or
automatically where auto-resolve is configured for that rule.

### 5.2 Triage procedure

For each new alert:

1. **Read the alert record.** Note the rule, server, login, client program, and
   the statement that triggered it.
2. **Read the agent verdict if present** — the `reason` field on the alert
   metadata. Treat it as a starting hypothesis, never as a conclusion. See
   Section 7.
3. **Establish whether the activity is expected.** Check the statement against
   known application behaviour for that server, and check whether the login and
   client program are ones that normally appear.
4. **Confirm against the database itself.** Independently verify with the DBA
   rather than relying solely on DBDOME's record.
5. **Decide:** true positive, false positive, or benign-but-noteworthy.
6. **Record the disposition and the reason**, then resolve the incident with the
   appropriate resolution type.

### 5.3 Evidence handling

Where an alert may become the basis of a disciplinary, legal or regulatory
process:

* Preserve the alert record and supporting metric rows **before** any retention
  job can age them out.
* Export and store them under the organization's evidence procedure.
* Do not rely on the AI-generated reason as evidence. It is a generated
  explanation, not a record of fact, and must not be presented as one.
* Involve Legal and the DPO early.

### 5.4 Response targets

Set locally; the following is a reasonable default.

| Severity | Acknowledge | Triage complete |
|---|---|---|
| Critical | 15 minutes | 1 hour |
| High | 1 hour | 4 hours |
| Medium | 4 hours | 1 working day |
| Low | 1 working day | 5 working days |

Alert volume that makes these targets unachievable is a tuning problem. Escalate
it as such rather than allowing the queue to age — an unread queue is
indistinguishable from no monitoring.

---

## 6. Rule tuning

### 6.1 When to tune

Tune when a rule produces repeated alerts that triage consistently dismisses.
Persistent false positives are corrosive: they train analysts to dismiss the rule
without reading it, which is worse than not having the rule.

### 6.2 Procedure

1. Quantify: how many alerts, over what period, what proportion dismissed.
2. Identify the discriminator that separates real findings from noise.
3. Propose the change (threshold, exclusion, schedule) with the evidence.
4. **Obtain approval** — tuning reduces detection coverage and is a change to a
   security control.
5. Apply in a change window.
6. Record: what changed, why, who approved, when.
7. Re-review after two weeks.

### 6.3 Constraints

> **Do not silence a rule by disabling it** where narrowing it would do. A
> disabled rule looks identical to a rule that never fires, and the reason is
> lost within weeks.

> **Exclusions are the most dangerous tuning tool.** An exclusion for a login or
> program is exactly what an attacker would want. Every exclusion must be
> reviewed at the monthly review and must have a stated owner and expiry.

> Adding detection or resolution steps to a rule multiplies collection cost —
> each additional detection step multiplies the metric rows written, and each
> resolution step causes repeated execution against the customer database.
> Review the cost of a rule change, not just its logic.

---

## 7. AI security-agent verdicts

### 7.1 What the verdict is

The agent compares the triggering query against activity previously observed on
that server and writes a plain-language reason onto the alert.

### 7.2 How to use it

**Use it to:** orient quickly, spot precedent you would otherwise have to search
for, and prioritize a queue.

**Do not use it to:** close an alert without independent checking, justify a
disciplinary or legal action, or serve as evidence.

> Verdicts are **not currently trustworthy enough to suppress alerts.** Benign
> queries have been classified as alerts, and reasons have contained factual
> slips about the query being described. Annotate-only is the supported mode.

### 7.3 Verdict quality review — weekly

```sql
SELECT decided_by, count(*), round(avg(elapsed_ms))
FROM alerts.security_agent_verdict
GROUP BY decided_by;
```

`decided_by='model'` is a genuine verdict. Any other value means the agent failed
open — alerts still fired, without a reason attached.

Sample a handful of `model` verdicts each week and compare them against the
analyst's own disposition. Record agreement. **If agreement is poor, say so and
stop relying on the verdicts** — a confidently wrong reason is worse than none,
because it anchors the analyst.

### 7.4 If verdicts stop appearing

Work through, in order:

1. `SECURITY_AGENT_ENABLED=true` in `.env`?
2. Model reachable? Run the agent check per the Installation Guide, Section 8.3.
3. Sweep registered and running? Check `metrics.registered_processes`, and check
   the service log for `Unknown process name`.
4. Ollama port owned by SYSTEM? Installation Guide, Section 8.4.
5. Is collection healthy? With no precedent data the agent has nothing to compare
   against.

---

## 8. Enforcement features — blocking, masking, suppression

DBDOME can terminate sessions, block logins, mask data and suppress alerts.
**These are disruptive and are disabled by default.**

### 8.1 Mandatory conditions before enabling

- [ ] Documented business case
- [ ] Tested in a non-production environment against realistic traffic
- [ ] Dry-run mode observed for a defined period with the actions it *would*
      have taken reviewed
- [ ] Blast radius understood — what breaks if it fires wrongly
- [ ] Approved by someone other than the requester
- [ ] Rollback procedure written and tested
- [ ] Application owners notified

### 8.2 Ongoing

* Review every enforcement action taken, weekly.
* Re-approve the feature monthly.
* Any wrongful block is an incident: record it, review the rule, and consider
  returning the feature to dry-run.

> **Alert suppression by AI verdict is the highest-risk setting in the platform.**
> It allows a model to decide that a security alert is not worth telling anyone
> about. Given the accuracy limits in Section 7.2, it should remain off.

---

## 9. Onboarding a monitored database

1. **Confirm authorization in writing** to monitor that system.
2. **Confirm lawful basis** — notification, consultation or DPIA as required.
3. Create a **read-only** monitoring login on the target. Do not grant
   `sysadmin`, `DBA` or ownership.
4. Confirm network reachability from the DBDOME host.
5. Register the server in DBDOME with vendor, host, port and **the specific
   database**.
6. Verify collection within 30 minutes:
   ```sql
   SELECT max(entry_date) FROM monitoring.general_metric_metadata_results
   WHERE server = '<new server>';
   ```
7. Observe for a baseline period before enabling alerting, so normal traffic is
   represented.
8. Record the server in the monitored-systems inventory with its owner.

> **Common onboarding failure.** `Login failed for <user> (18456)` together with
> `4060 Cannot open database None` is a **NULL database in the configuration**,
> not a credential problem. Set the database explicitly. Hours are routinely lost
> re-issuing credentials that were never wrong.

### 9.1 Offboarding

Remove the server from DBDOME, revoke the monitoring login on the target, and
record the removal. Confirm no alert rule still references it.

---

## 10. Backup and recovery

### 10.1 What must be backed up

| Item | Why |
|---|---|
| DBDOME PostgreSQL database | All configuration, metrics, alerts, incidents |
| `bin\.env` | Connection settings **and the encryption key** |
| `bin\_internal\security_agent\rules.json` | Local rule customization; replaced by upgrades |
| Grafana `grafana.db` | Dashboards and their customizations |
| Any custom report templates | |

> **`DBDOME_SECRET_KEY` deserves separate treatment.** Stored credentials are
> encrypted with it. **Back it up somewhere other than the DBDOME host.** Losing
> it means every stored target credential must be re-entered by hand, and a host
> failure that takes the key with it turns a restore into a re-onboarding
> exercise.

### 10.2 Schedule

| Item | Frequency | Retention |
|---|---|---|
| Full database backup | Daily | Per policy |
| Configuration files | On change, and weekly | 3 versions minimum |
| Encryption key | On change | Permanent, offsite, access-controlled |
| Restore test | Quarterly | Record the result |

### 10.3 Recovery

1. Restore the database from backup.
2. Restore `bin` and `.env`.
3. Confirm `ORG_IP` matches the recovered host's LAN IP — if the host changed,
   this must be corrected or dashboards and ingest will fail.
4. Start services and run the full verification in the Installation Guide,
   Section 7.
5. Confirm collection resumed and stored credentials still decrypt.

---

## 11. Change control

Any of the following is a change to a security control and requires the process
below:

* Enabling, disabling or modifying a detection rule
* Adding or removing an exclusion
* Changing a threshold
* Enabling any enforcement feature
* Upgrading DBDOME
* Adding or removing a monitored server
* Changing retention

**Process:** request → impact assessment → approval → scheduled window →
implementation → verification → record.

Record, at minimum: what changed, why, who approved it, when it was applied, how
it was verified, and how to reverse it.

---

## 12. Escalation

| Situation | Escalate to | Timeframe |
|---|---|---|
| Confirmed data exfiltration or ransomware indicators | Security incident response | Immediate |
| DBDOME collection stopped | Platform Administrator | Immediate |
| Suspected insider misuse | Security lead + HR + Legal | Immediate, before confronting anyone |
| Wrongful block or mask affecting production | Platform Administrator + application owner | Immediate |
| Alert queue beyond SLA | Security lead | Same day |
| Repeated false positives on one rule | Security lead for tuning approval | Weekly review |
| Suspected DBDOME defect | support@dbexpert.ai | Per support agreement |

Maintain a current on-call contact list. Test it monthly — an escalation path
that has never been exercised usually fails on first use.

---

## 13. Health indicators

Track these. They describe whether monitoring is actually working, which service
state alone does not.

| Indicator | Target |
|---|---|
| Collection freshness (all servers) | Within one collection interval |
| Servers reporting vs. servers registered | 100% |
| Alerts triaged within SLA | > 95% |
| False-positive rate | Trending down |
| Open incidents ageing beyond SLA | 0 |
| Backup success | 100% |
| Restore test | Passed within the quarter |
| Agent verdicts `decided_by='model'` | Stable; investigate drops |
| Analyst/agent agreement on sampled verdicts | Recorded weekly |

---

## 14. Records to retain

| Record | Retain |
|---|---|
| Daily health check log | 12 months |
| Alert dispositions | Per policy; typically 12–24 months |
| Change records | Life of the system + 12 months |
| Approvals for enforcement features | Life of the system |
| Exclusion register with owner and expiry | Life of the system |
| Backup and restore-test results | 12 months |
| Monitored-systems inventory with authorization | Current + history |
| Lawful-basis assessment | Per DPO policy |

---

## 15. Appendix — quick command reference

**Service state**
```powershell
Get-Service DBDOME_dbanalytics, DBDOME_web, DBDOME_Grafana, DBDOME_Ollama, postgresql-x64-18
```

**Restart collection** (requires elevation)
```powershell
Restart-Service DBDOME_dbanalytics
```

**Collection freshness**
```sql
SELECT server, max(entry_date) FROM monitoring.general_metric_metadata_results
GROUP BY server ORDER BY 2;
```

**Open incidents**
```sql
SELECT * FROM alerts.alert_incidents WHERE resolved_at IS NULL ORDER BY 1 DESC;
```

**Agent verdict summary**
```sql
SELECT decided_by, count(*) FROM alerts.security_agent_verdict GROUP BY 1;
```

**Scheduled processes**
```sql
SELECT process_name, is_active FROM metrics.registered_processes ORDER BY 1;
```

**Ollama port ownership**
```powershell
Get-NetTCPConnection -LocalPort 11434 -State Listen |
  ForEach-Object { (Get-Process -Id $_.OwningProcess).ProcessName }
```

**Logs:** `C:\ProgramData\DBDOME\bin\logs\`, and the `log` schema in the database.

---

## 16. Support

| | |
|---|---|
| Technical support | support@dbexpert.ai |
| Licensing | legal@dbexpert.ai |

---

*Copyright (c) 2026 DBEXPERT. All rights reserved. DBDOME is a trademark of
DBEXPERT.*
