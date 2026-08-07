# DBDOME — LDAP / Active Directory Login Configuration Guide

DBDOME can authenticate its users against your corporate directory (Microsoft
Active Directory or any LDAP v3 server). Users then sign in to the DBDOME UI
with their own domain credentials, are created automatically on first login,
and receive their DBDOME role from the Active Directory groups they belong to.

Everything is configured from one page — no files to edit, no server access
needed. The built-in local users (`dbdome`, `admin`) **always keep working**,
so a wrong LDAP configuration can never lock you out.

---

## 1. What to collect before you start

Ask your Active Directory / IT team for the following:

| Item | Example | Notes |
|---|---|---|
| Directory server host | `dc1.corp.local` | Name or IP of a domain controller |
| Port + encryption | `636` (LDAPS) | LDAPS on 636 recommended; StartTLS or plain use 389 |
| CA certificate (PEM) | `corp-root-ca.crt` | Needed when the directory uses an internal CA |
| Service account | `CN=svc_dbdome,OU=Service Accounts,DC=corp,DC=local` | A **read-only** account used only to search the directory; a regular low-privilege user is fine |
| Service account password | — | Stored encrypted by DBDOME |
| Users base DN | `OU=Users,DC=corp,DC=local` | Where your user objects live; several DNs are allowed |
| AD groups for roles | `CN=DBDOME-Admins,OU=Groups,DC=corp,DC=local` | One group per DBDOME role you want to hand out |
| A test user + password | `jdoe` | Any normal account, used once to verify the setup |

---

## 2. Open the configuration page

From the DBDOME UI: open the **Configuration** dashboard and click
**LDAP Login → LDAP / Active Directory** in the *Configuration Tools* panel
(next to the SMTP and TLS-certificate tools). Or browse directly to:

```
https://<dbdome-host>:8080/ldap_settings
```

The top of the page shows the current state: whether LDAP is active, the
DBDOME Grafana service status, and the configuration files in use.

---

## 3. Server section

| Field | What to enter |
|---|---|
| LDAP host | The domain controller name or IP (`dc1.corp.local`) |
| Port | `636` for LDAPS, `389` for StartTLS or unencrypted |
| Encryption | **LDAPS** (recommended), StartTLS, or None |
| Skip TLS certificate verification | Leave **no**. Use *yes* only temporarily while troubleshooting certificate issues |
| CA certificate | Paste the PEM text (`-----BEGIN CERTIFICATE-----` ...) of your internal root CA, if the directory certificate is not publicly trusted |

## 4. Service account section

| Field | What to enter |
|---|---|
| Bind DN / UPN | The service account, as a full DN (`CN=svc_dbdome,OU=Service Accounts,DC=corp,DC=local`) or UPN (`svc_dbdome@corp.local`) |
| Bind password | The account password. Shown as *set* once saved; leave blank on later edits to keep the stored one |

The password is stored **encrypted** on the DBDOME host (the encryption key is
kept outside the database, so DB backups never contain a usable secret).

## 5. User lookup section

| Field | What to enter |
|---|---|
| User search base DN(s) | One per line, e.g. `OU=Users,DC=corp,DC=local`. Users anywhere under these DNs can log in |
| Search filter | `(sAMAccountName=%s)` for Active Directory (the default). `%s` is replaced by what the user types at login. For non-AD directories use e.g. `(uid=%s)` |
| Group search base DN(s) | Optional; only needed when groups live outside the user search bases |

The attribute mapping (username = `sAMAccountName`, email = `mail`, groups =
`memberOf`) fits Active Directory out of the box.

## 6. Group-to-role mappings

Each row maps one AD group to a DBDOME role. **The first matching row wins**,
so put the most privileged groups on top.

| DBDOME role | What it allows |
|---|---|
| Viewer | See all dashboards and data, read-only |
| Editor | Viewer + create and edit dashboards |
| Admin | Editor + manage users, data sources and settings |

Rules:

- Group DNs must be the **full DN**: `CN=DBDOME-Admins,OU=Groups,DC=corp,DC=local`
- A user in none of the mapped groups is **denied login**
- A row with group DN `*` matches everyone — add one last `*` → Viewer row if
  every authenticated domain user should be allowed in
- *Grafana admin* additionally grants server administration of the UI —
  reserve it for the DBA team's group

## 7. Save, Test, Apply

1. **Save** — stores the settings. Nothing is activated yet.
2. **Test** — enter a test username (and optionally their password) first.
   The test runs against your directory **without touching the live login**:
   - verifies the service-account bind,
   - finds the test user under your base DNs,
   - lists the user's groups and shows **which role they would receive**,
   - if a password was entered, verifies it (a real end-to-end login check).
   Fix and re-test until the result looks right.
3. **Enable LDAP login** — set the dropdown to *enabled*.
4. **Apply & restart Grafana** — writes the configuration and restarts the
   DBDOME UI service. Active browser sessions see a ~10 second interruption.

## 8. Verify

Open the DBDOME UI login page and sign in as the test user with their domain
credentials. First login creates the account automatically with the mapped
role. The `/ldap_settings` page should now show **LDAP in Grafana: ACTIVE**.

## 9. Disabling LDAP

Set *Enable LDAP login* to **disabled** and click *Apply & restart Grafana*.
Domain logins stop; local users continue to work throughout.

---

## 10. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Test: *service-account bind failed* | Wrong bind DN or password; account locked/expired; try the UPN form (`svc_dbdome@corp.local`) |
| Test: *user not found* | User is outside the base DN(s); wrong search filter for your directory type |
| Test: TLS / certificate error | Directory cert issued by an internal CA — paste the CA PEM; check host name matches the certificate; as a diagnostic only, set skip-verify to *yes* |
| Test OK but login denied in the UI | User is in no mapped group — add the group or a `*` catch-all row |
| Wrong role assigned | Mapping order — first match wins; check the user's groups in the Test output |
| Apply fails / service does not come back | See the service state on the page. The previous configuration is kept as a `.bak-ldap` file next to Grafana's ini; local logins still work |
| Password check FAILED for the test user | The user's password is wrong, or the account is disabled / must change password at next logon |

## 11. Security notes

- The service (bind) account only ever **reads** the directory — give it no
  other privileges.
- The bind password is stored encrypted; the rendered configuration file on
  the host is readable by administrators and the system service only.
- Prefer LDAPS (or StartTLS) so credentials never cross the network in clear.
- Local emergency access is deliberately retained: keep the local `admin`
  password in your password safe.

## 12. Reference (for administrators)

| Item | Value |
|---|---|
| Configuration page | `https://<dbdome-host>:8080/ldap_settings` |
| Settings storage | `config.ldap_settings` (single row, password `enc:v1:` encrypted) |
| Rendered files | `<conf>/ldap.toml`, `<conf>/ldap_ca.crt`, `[auth.ldap]` in `custom.ini` (backup: `custom.ini.bak-ldap`) |
| Default conf dir | `C:\ProgramData\DBDOME\conf` (Linux: `/etc/grafana`) |
| Service restarted on Apply | `DBDOME_Grafana` (Linux: `grafana-server`) |
| Overrides (env vars) | `GRAFANA_CONF`, `GRAFANA_INI`, `GRAFANA_SERVICE` |
| API | `/api/ldap/status` · `/api/ldap/save` · `/api/ldap/test` · `/api/ldap/apply` |
