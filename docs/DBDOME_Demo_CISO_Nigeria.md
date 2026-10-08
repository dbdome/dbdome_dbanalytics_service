# DBDOME Demo — CISO, Nigerian Financial Institution

| | |
|---|---|
| **Audience** | CISO |
| **Environment** | Oracle · DBDOME on-premises appliance |
| **Length** | 60 minutes |
| **Deck** | `DBDOME_Demo_CISO_Nigeria.pptx` (editable) · `DBDOME_Demo_CISO_Nigeria.ppsx` (opens as a slideshow) |
| **Run-sheet** | `DBDOME_Demo_RunSheet_Nigeria_CISO_2026-10-06.pdf` |
| **Date** | 6 October 2026 |

> **Internal document.** The speaker notes contain cautions that must not be shown to the customer.

---

## Before you start (5 minutes)

1. **Log into DBDOME** and open the Fleet overview. Check that the Oracle demo server is green and shows recent findings.
2. **Check the dry-run switches** (Webhook Alerts Configuration). Arm the blocker only if the target is your own demo database, never one of theirs.
3. **Open these tabs in advance:** Fleet, Security findings, Sensitive data (PII), Alerts, Threat response, Risk scoring, Compliance reports.
4. **Have the attack script ready**: the SQL injection or suspicious query you have run before.
   - **On Oracle, show only what you have already seen work there.**
   - Automatic masking was built on SQL Server's masking feature, so don't demonstrate masking on Oracle unless it has been tested.
5. Keep the **signed VAPT report** PDF open in case they ask about it.

---

## Timing

| Time | Segment | Slides |
|---|---|---|
| 0–5 | Open | 1–3 |
| 5–12 | Agentless, on-premises | 4 |
| 12–25 | What's exposed right now | 5 |
| 25–32 | Sensitive data | 6 |
| 32–42 | **Live attack** (the key moment) | 7 |
| 42–48 | Insider risk | 8 |
| 48–54 | Regulators and audit | 9 |
| 54–60 | Integrations and close | 10–11 |

---

## Slides

### 1. Protecting the data layer

*Title slide: DBDOME logo.*

- DBDOME database security
- Agentless · On-premises · Oracle-ready
- dbexpert.ai · October 2026

> **Speaker notes (0–5 min).** "Your perimeter is well protected. Your Oracle databases, holding BVN, NIN, card and transaction data, are where attackers and insiders end up. DBDOME watches that layer, with no agent on your database servers and all data staying inside your network."

### 2. Your databases are where attacks end up

| # | Threat | Detail |
|---|---|---|
| 1 | **SQL injection** | Attacks through the application reach customer data directly |
| 2 | **Privileged abuse** | SYSDBA and DBA accounts can read and change anything |
| 3 | **Insider access** | Legitimate users querying data they do not need |
| 4 | **Data exfiltration** | BVN, NIN, card and transaction data leave quietly |

> **Speaker notes.** Keep it short: the CISO knows the threats. Land the point: the database is the last line, and most controls stop before it.

### 3. What DBDOME does

| Capability | What it covers |
|---|---|
| **Agentless monitoring** | Oracle, SQL Server, PostgreSQL, MySQL, MariaDB, Informix |
| **7,000+ root causes** | Security, performance and health checks, ranked by risk |
| **Sensitive-data discovery** | Finds PII columns and who queries them |
| **Threat detection** | SQL injection, anomalous access, privilege abuse |
| **Automated response** | Block sessions and IPs, suspend users, escalate |
| **Data masking** | Dynamic masking on SQL Server, triggered by policy |
| **GRC suite** | Compliance, SoD, access reviews, CVE watch |
| **Integrations** | SIEM, email, webhooks and REST API |

> **Speaker notes.** A one-slide overview of the platform before the live tour. Don't dwell: the demo shows each of these. Masking is SQL Server dynamic data masking, so **do not promise it on Oracle**.

### 4. Agentless, on-premises, Oracle-ready

| | |
|---|---|
| **0** | agents installed on your database servers |
| **100%** | of your data stays inside your network |
| **6** | database engines supported, including Oracle |

Read-only collection · no change to your Oracle servers · deployment in days, not a project

> **Speaker notes (5–12 min).** Show the Fleet overview, and add or show the Oracle server. "Read-only, agentless, no change to your Oracle servers." The six engines: Oracle, SQL Server, PostgreSQL, MySQL, MariaDB, Informix.

### 5. What is exposed right now · *LIVE DEMO*

1. Super-user and SYSDBA accounts
2. Weak password enforcement
3. Credentials stored inside tables
4. Hidden database-link credentials

**7,000+ root causes checked automatically.** Findings ranked by risk across Security, Performance and Health: the same issues auditors and attackers look for.

> **Speaker notes (12–25 min).** Security findings dashboards. Stop on **one** striking finding and let it land. "These are the findings auditors and attackers both look for, found automatically."

### 6. Know where customer data lives and who touches it · *LIVE DEMO*

| # | Step | What it does |
|---|---|---|
| 1 | **Discover** | Sensitive columns found automatically: BVN, NIN, card and account data |
| 2 | **Watch** | Who queries them, when, and from where |
| 3 | **Respond** | Alert or block when access looks wrong |

> **Speaker notes (25–32 min).** Sensitive-data (PII) dashboard. "You'll know where customer data sits and who touches it."
> - **Check beforehand** that discovery recognises BVN and NIN on the demo database.
> - Don't demonstrate masking on Oracle unless it has been tested there; masking was built on SQL Server's dynamic data masking.

### 7. Detected and stopped in seconds · *LIVE DEMO*

**Attack** → **Detect** → **Alert** → **Block** → **Evidence**

| Step | What happens |
|---|---|
| Attack | SQL injection or suspicious query |
| Detect | Matched against detection rules |
| Alert | Dashboard, email or SIEM |
| Block | Session stopped by policy |
| Evidence | Recorded for audit and response |

*Enforcement runs in log-only mode until you choose to arm it.*

> **Speaker notes (32–42 min). The key moment.**
> - Run the attack and stay quiet while it runs, then say: "Detected and stopped in seconds, with the evidence recorded."
> - **Arm the blocker only on your own demo database.** Show only the steps you've already rehearsed on Oracle.
> - If it breaks, say "This is a live system; let me show you this morning's run," and switch to the Alerts dashboard or the recording.

### 8. Catch the trusted insider

| # | Capability | What it does |
|---|---|---|
| 1 | **User risk scoring** | Every login scored on behaviour; high-risk users surface first |
| 2 | **Segregation of duties** | Conflicting privileges detected and tracked to resolution |
| 3 | **Privilege-change tracking** | New DBA or SYSDBA rights flagged as they happen |

> **Speaker notes (42–48 min).** Show risk scoring, segregation-of-duties violations and privilege changes. "Most bank data breaches involve someone with legitimate access."

### 9. Audit-ready, every day

| # | Capability | What it does |
|---|---|---|
| 1 | **Compliance reports** | PCI-DSS, SOX, SOC 2 and GDPR, scheduled or on demand |
| 2 | **72-hour incident clock** | Tracks the breach-notification window the NDPA requires |
| 3 | **Evidence packages** | One package per audit or incident, ready to hand over |
| 4 | **Tamper-evident audit log** | Hash-chained records that show any alteration |

> **Speaker notes (48–54 min).** Show the PCI-DSS report, an evidence package, the incident 72-hour timer and the audit-log integrity check. "The NDPA gives you 72 hours to notify the regulator. This tracks that clock and produces the evidence."
> - **Do not claim NDPA or CBN certification.** The ready-made reports are PCI-DSS, SOX, SOC 2 and GDPR. Offer an NDPA dashboard instead.

### 10. Fits your security operations

| Integration | What it does |
|---|---|
| **SIEM** | Events forwarded in CEF format; built-in Rapid7 and CrowdStrike forwarders |
| **Email alerts** | Routed by risk level to the right team |
| **Webhooks** | Alerts pushed to your own tools |
| **REST API** | Findings and incidents available as JSON |

> **Speaker notes.** On Splunk or QRadar: "We forward events to SIEMs in CEF format; we'll confirm your SIEM during the pilot." Don't promise a specific SIEM connector beyond Rapid7 and CrowdStrike.

### 11. Next step: a 30-day pilot

*Closing slide: DBDOME logo.*

1. 2–3 Oracle servers
2. Read-only and agentless
3. Board-ready findings report

**Which databases worry you most?**

> **Speaker notes (54–60 min).** Propose the pilot, then ask the question and stop talking.
> - If they ask whether DBDOME itself was tested, have the signed VAPT report ready.
> - **Impact on production:** agentless, read-only and scheduled. Offer to measure it in the pilot.
> - **Data location:** nowhere; it stays on the appliance.

---

## If the CISO asks

| Question | Answer |
|---|---|
| "Impact on production?" | Agentless and read-only, collecting on a schedule. Offer to measure it in the pilot. |
| "Where does our data go?" | Nowhere. Everything stays on the appliance inside your network. |
| "NDPA / CBN compliance?" | "We map to PCI-DSS, SOX and GDPR today, and the NDPA follows the same principles. We can add an NDPA-specific dashboard." **Do not claim NDPA or CBN certification.** |
| "Splunk / QRadar?" | "We forward events to SIEMs in CEF format. We'll confirm your SIEM during the pilot." |
| "Has DBDOME itself been tested?" | "Yes, it has an independent VAPT," and offer the report. |

## If something breaks

Say: "This is a live system; let me show you the result from this morning's run," and switch to the Alerts dashboard or your recording. **Do not debug in front of the CISO.**

---

## Slides 12–21 · Full DBDOME capability catalog (reference)

Appended so the deck covers **every** DBDOME capability. Not part of the timed
60-minute flow — use as a reference / "what else does it do?" backstop, and lead
with what matters to the customer. Mirrored in the run-sheet appendix.

| Slide | Domain |
|---|---|
| 12 | Divider — "The complete DBDOME capability catalog" |
| 13 | Coverage & agentless collection (9 engines, scheduling, encrypted vault, exec-plan capture) |
| 14 | Detection & threat analytics (7,000+ root causes, decision trees, SQLi, anomaly agent, user-risk, adaptive thresholds) |
| 15 | Incidents & alerting (lifecycle, co-firing correlation, App Login Guard, self-monitoring) |
| 16 | Active response (session kill, IP block, user suspend, threat/ransomware engines, dry-run gate) |
| 17 | Data protection (discovery, dynamic/static masking, anonymisation, tokenisation, auto-mask) |
| 18 | GRC & compliance (PCI/SOX/SOC 2/GDPR, regional packs, SoD, privilege-change, DDL audit, CVE, cross-border/TLS) |
| 19 | Audit, evidence & integrity (DAM, hash-chain log, evidence packages, 72h clock, scheduled reports, retention) |
| 20 | Integrations & access (SIEM connectors + generic CEF/LEEF/RFC5424/JSON, email, webhooks, REST API, Grafana+PWA, LDAP/AD, cloud ingest) |
| 21 | Platform, security & resilience (air-gap, bundled PG + least-privilege, secret & content encryption, TLS, RBAC, HA/DR PG_HOST failover, AI assist) |

> **Speaker notes.** These slides are a catalog, not a pitch — most CISOs won't need all of them. Keep them in reserve; pull up the one domain a question lands on. The masking caution still applies (dynamic masking is SQL Server); do not claim NDPA/CBN certification.
