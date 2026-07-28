"""Generate the DBDOME 'Grafana User & Dashboard Access' manual as a branded PDF.

Same visual style as the Security Root-Cause catalogs (logo, navy section
bands, tag pills). Content is a step-by-step guide for Grafana OSS covering:
creating users, setting the profile / organisation role, and enabling /
disabling access to a dashboard for individual users.
"""
import datetime
from fpdf import FPDF

NAVY = (23, 42, 77)
BLUE = (37, 99, 175)
LIGHT = (238, 242, 249)
GREY = (90, 90, 90)
LINE = (210, 216, 226)
BASE = "C:/dev/dbdome_dbanalytics_service"
LOGO = f"{BASE}/static/images/dbdome_logo.png"
OUT = f"{BASE}/DBDOME_Grafana_User_Access_Guide.pdf"

TITLE = "Grafana User & Dashboard Access Guide"
SUBTITLE = "Creating Users & Profiles  -  Managing Dashboard Permissions"
META = "Product: Grafana OSS (open-source)   |   Audience: Organisation Admins"

INTRO = (
    "This guide explains how a Grafana administrator creates user accounts, "
    "assigns each user an access profile (organisation role), and controls "
    "which users may view or edit a specific dashboard. The main sections "
    "target Grafana OSS 10.x / 11.x; menu names may differ slightly between "
    "versions. In Grafana OSS, permissions are additive - the most permissive "
    "rule wins and there is no per-user 'deny', so access is restricted by "
    "removing broad grants rather than by explicitly blocking a user. "
    "Appendices A and B cover the fine-grained Role-Based Access Control "
    "(RBAC) available in Grafana Enterprise and paid Grafana Cloud.")

# stat boxes shown on the cover (value, label)
STATS = [("8", "Sections (incl. 2 appendices)"),
         ("3", "Basic roles: Viewer / Editor / Admin"),
         ("+RBAC", "Enterprise / Cloud appendix")]

# section = (code, title, intro, [ (tag, heading, body), ... ])
SECTIONS = [
    ("SETUP", "Before You Begin",
     "Confirm your access and understand how Grafana decides who can see "
     "what.",
     [
        ("REQ 1", "Sign in with an administrator account",
         "You need a Grafana Server Admin account to create login accounts, "
         "and/or an Organisation Admin account to manage roles, teams and "
         "dashboard permissions. If you cannot see Administration in the left "
         "menu, you do not yet have the required rights."),
        ("REQ 2", "Understand the permission model",
         "Every user has one organisation role - Viewer, Editor or Admin - "
         "that sets their baseline access. Dashboard and folder permissions "
         "then refine that access for individual users or teams."),
        ("REQ 3", "Remember: permissions are additive",
         "OSS has no per-user 'deny'. A user is kept out of a dashboard by NOT "
         "granting access and by removing broad role-based grants - never by "
         "an explicit block. Org Admins always retain access by design."),
        ("TIP", "Organise restricted dashboards into folders",
         "Keep dashboards that need controlled access in a dedicated folder "
         "and manage permissions at the folder level. Dashboards inherit the "
         "folder's permissions, which is far easier to maintain than editing "
         "each dashboard individually."),
     ]),

    ("USER", "Create a New User",
     "Add a login account so the person can sign in to Grafana.",
     [
        ("STEP 1", "Open user administration",
         "In the left menu choose Administration -> Users and access -> Users. "
         "(In older versions this is Server Admin -> Users.)"),
        ("STEP 2", "Start a new user",
         "Click 'New user'. Alternatively click 'Invite' to email an "
         "invitation link - this requires SMTP to be configured on the "
         "Grafana server."),
        ("STEP 3", "Enter the account details",
         "Provide Name, Email, Username and an initial Password, then click "
         "'Create user'. The account can now sign in."),
        ("STEP 4", "Hand over the credentials securely",
         "Share the username and initial password over a secure channel and "
         "ask the user to change it on first sign-in via Profile -> Change "
         "password."),
     ]),

    ("PROFILE", "Set the User Profile & Access Role",
     "A user's profile is their account details plus the organisation role "
     "that defines their baseline privileges. Optionally group users into "
     "Teams to reuse a common access profile.",
     [
        ("STEP 1", "Open the user record",
         "Go to Administration -> Users and access -> Users and click the "
         "user you just created."),
        ("STEP 2", "Assign the organisation role (the access profile)",
         "Under 'Organisations', set the role: Viewer = read dashboards only; "
         "Editor = create and edit dashboards; Admin = manage the org, users "
         "and permissions. This role is the user's baseline profile. Save the "
         "change."),
        ("STEP 3", "Complete the profile details (optional)",
         "The user maintains their own profile - display name, email, theme, "
         "home dashboard, timezone - from the user menu -> Profile. An admin "
         "can edit the name and email from the user's admin page."),
        ("STEP 4", "Use a Team as a reusable profile (optional)",
         "Go to Administration -> Users and access -> Teams -> 'New team', "
         "name it (e.g. 'Finance-Viewers'), open it and add members. You can "
         "then grant dashboard access to the whole team at once instead of "
         "user by user."),
     ]),

    ("GRANT", "Enable Dashboard Privilege for One User",
     "Give a specific user permission to view or edit a particular dashboard "
     "or folder.",
     [
        ("STEP 1", "Open the dashboard (or its folder)",
         "From Dashboards, open the dashboard you want to share. To apply the "
         "same access to many dashboards, open the folder that contains them "
         "instead."),
        ("STEP 2", "Open the Permissions screen",
         "For a dashboard: click the settings (gear) icon -> Permissions. For "
         "a folder: open the folder and choose the Permissions tab."),
        ("STEP 3", "Add the user with a permission level",
         "Click 'Add a permission' -> choose 'User' -> select the user -> set "
         "the level: 'View' to let them read it, or 'Edit' to let them change "
         "it. Click Save."),
        ("STEP 4", "Confirm the grant",
         "The user now appears in the permissions list with their level and "
         "will see the dashboard on their next sign-in or refresh. Note: "
         "granting 'Edit' on a specific dashboard lets a Viewer edit that one "
         "dashboard, even though their org role stays Viewer elsewhere."),
     ]),

    ("RESTRICT", "Disable / Remove Dashboard Privilege for Another User",
     "Prevent a user from seeing or editing a dashboard. Because OSS "
     "permissions are additive (no explicit deny), you remove the broad "
     "access that currently exposes the dashboard and grant it only to the "
     "users who should have it.",
     [
        ("STEP 1", "Open the dashboard or folder permissions",
         "Settings (gear) -> Permissions for a dashboard, or the folder's "
         "Permissions tab."),
        ("STEP 2", "Remove the broad role grants",
         "Delete the default 'Editor' and 'Viewer' role rows using the "
         "remove/trash icon. These rows give every Editor/Viewer in the org "
         "access; removing them closes the dashboard to 'everyone'."),
        ("STEP 3", "Remove the specific user's grant",
         "If the user you want to block has an individual permission row, "
         "delete it as well."),
        ("STEP 4", "Grant access back to only the allowed users/teams",
         "Add back only the users or teams that should keep access (see the "
         "GRANT section). The blocked user, now matching no grant, can no "
         "longer open the dashboard."),
        ("STEP 5", "Check for indirect access",
         "The user can still get in if they are an Org Admin, a folder/"
         "dashboard Admin, or a member of a team that still holds a grant. "
         "Verify none of these apply - Org Admins always retain access."),
     ]),

    ("VERIFY", "Verify & Maintain",
     "Confirm the result and keep permissions tidy over time.",
     [
        ("STEP 1", "Test as the affected user",
         "Ask the user to sign in (or use a private/incognito window with "
         "their account) and confirm they can - or cannot - see the dashboard "
         "as intended."),
        ("STEP 2", "Review the permissions list",
         "The Permissions screen should show exactly the roles, teams and "
         "users you intend, and nothing broader."),
        ("STEP 3", "Prefer folder-level management",
         "For ongoing control, set permissions on the folder and let "
         "dashboards inherit. Move a dashboard into the correct folder rather "
         "than editing each dashboard's permissions."),
        ("STEP 4", "Re-check after any role change",
         "Promoting a user to Org Admin grants broad access. Review your "
         "restricted folders whenever a user's organisation role changes."),
     ]),

    ("APPX-A", "Appendix A - Enterprise RBAC: Concepts",
     "Grafana Enterprise and paid Grafana Cloud add Role-Based Access Control "
     "(RBAC) on top of the OSS model, letting you grant precise, action-level "
     "permissions through roles instead of relying only on the Viewer / "
     "Editor / Admin org roles. Like OSS, RBAC is grant-only: permissions are "
     "additive across all of a user's roles and there is no 'deny' rule - you "
     "restrict access by granting narrowly, not by blocking.",
     [
        ("NOTE 1", "Availability and where to manage it",
         "RBAC ships with Grafana Enterprise and paid Grafana Cloud tiers; it "
         "is not part of OSS. Manage it under Administration -> Users and "
         "access -> Roles, and via the role picker on each user, team or "
         "service account."),
        ("CONCEPT", "Three kinds of role",
         "Basic roles - the now-customizable Viewer / Editor / Admin (and "
         "Grafana Admin) baselines. Fixed roles - Grafana-supplied roles "
         "prefixed 'fixed:' (e.g. fixed:dashboards:reader, fixed:users:writer) "
         "that you cannot edit. Custom roles - roles you define with your own "
         "chosen set of permissions."),
        ("CONCEPT", "A permission = action + scope",
         "Each permission pairs an action (e.g. dashboards:read, "
         "dashboards:write, dashboards.permissions:write) with a scope that "
         "limits where it applies (e.g. dashboards:uid:<uid>, "
         "folders:uid:<uid>, or dashboards:* for everything). Narrow scopes "
         "are how you keep access tightly contained."),
        ("CONCEPT", "Assign roles to users, teams or service accounts",
         "A role can be attached to an individual user, to a team (so every "
         "member inherits it), or to a service account used by automation and "
         "API tokens."),
        ("TIP", "Tighten the defaults by editing basic roles",
         "Because RBAC has no deny, the way to reduce what 'everyone' can do "
         "is to remove permissions from a basic role - e.g. strip "
         "dashboards:create from the Editor basic role so Editors can no "
         "longer create dashboards org-wide."),
        ("TIP", "Manage RBAC as code",
         "Beyond the UI, assign roles and permissions through the HTTP API, "
         "file-based provisioning, or the Terraform provider for repeatable, "
         "reviewable access control across environments."),
     ]),

    ("APPX-B", "Appendix B - RBAC in Practice: Dashboard Access",
     "How the 'grant to one user, restrict another' task from the main guide "
     "is done with RBAC. The dashboard / folder Permissions screen in "
     "Enterprise is backed by RBAC, and you can additionally use custom roles "
     "for reusable, scoped access.",
     [
        ("STEP 1", "Grant one user read access to a dashboard",
         "Option A (UI): open the dashboard -> settings -> Permissions -> Add "
         "-> User -> View. Under the hood this grants dashboards:read scoped "
         "to that dashboard's uid. Option B (role): create a custom role with "
         "action dashboards:read and scope dashboards:uid:<uid>, then assign "
         "it to the user or their team."),
        ("STEP 2", "Give scoped edit rights with a custom role",
         "Create a custom role (e.g. 'Sales Dashboard Editor') containing "
         "dashboards:read + dashboards:write scoped to "
         "folders:uid:<sales-folder-uid>, and assign it to the user or team. "
         "They can edit everything in that folder and nothing else."),
        ("STEP 3", "Restrict another user",
         "RBAC has no deny, so restriction means: (a) ensure the user is not "
         "granted the action by any role; (b) do not add them on the "
         "dashboard's Permissions list; (c) confirm they are not in a team "
         "that holds a granting role; and (d) if a basic role is too broad, "
         "remove the relevant permission from it. The user then has no path "
         "to the dashboard."),
        ("STEP 4", "Verify effective access",
         "Use the user's page -> role picker to see every assigned role, or "
         "query the RBAC HTTP API to confirm exactly which actions and scopes "
         "resolve for that user. Finish by signing in as them to confirm."),
        ("NOTE", "Precedence recap",
         "Effective access is the union of basic + fixed + custom roles plus "
         "any dashboard / folder permissions. If any one of them grants the "
         "action on the scope, the user has access - nothing subtracts it."),
     ]),
]


def clean(s):
    return (s or "").replace("\r", " ").replace("\n", " ").strip()


class PDF(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        try:
            self.image(LOGO, x=self.l_margin, y=7, w=7)
        except Exception:
            pass
        self.set_xy(self.l_margin + 9, 8)
        self.set_font("Arial", "B", 9)
        self.set_text_color(*GREY)
        self.cell(0, 8, "DBDOME  -  Grafana User & Dashboard Access Guide",
                  align="L")
        self.ln(10)

    def footer(self):
        self.set_y(-15)
        self.set_font("Arial", "", 8)
        self.set_text_color(*GREY)
        self.cell(0, 10, f"Page {self.page_no()}   |   Grafana OSS  -  User & "
                         f"Access Management   |   Confidential", align="C")


pdf = PDF()
pdf.add_font("Arial", "", "C:/Windows/Fonts/arial.ttf")
pdf.add_font("Arial", "B", "C:/Windows/Fonts/arialbd.ttf")
pdf.add_font("Arial", "I", "C:/Windows/Fonts/ariali.ttf")
pdf.set_auto_page_break(auto=True, margin=18)
pdf.add_page()

# ---- cover ----
logo_w = 38
pdf.image(LOGO, x=(pdf.w - logo_w) / 2, y=14, w=logo_w)
pdf.set_xy(0, 14 + logo_w + 2)
pdf.set_text_color(*NAVY)
pdf.set_font("Arial", "B", 24)
pdf.cell(0, 12, "DBDOME", align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_text_color(*BLUE)
pdf.set_font("Arial", "", 14)
pdf.cell(0, 8, TITLE, align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_text_color(*GREY)
pdf.set_font("Arial", "", 10.5)
pdf.cell(0, 7, SUBTITLE, align="C", new_x="LMARGIN", new_y="NEXT")
pdf.set_font("Arial", "", 10)
pdf.cell(0, 6, META, align="C", new_x="LMARGIN", new_y="NEXT")
pdf.ln(2)
pdf.set_fill_color(*NAVY)
pdf.rect(pdf.l_margin, pdf.get_y(), pdf.w - 2 * pdf.l_margin, 1.5, style="F")
pdf.ln(7)

pdf.set_font("Arial", "", 10)
pdf.set_text_color(40, 40, 40)
pdf.multi_cell(0, 5.5, INTRO)
pdf.ln(3)
for val, label in STATS:
    pdf.set_fill_color(*LIGHT)
    pdf.set_text_color(*NAVY)
    pdf.set_font("Arial", "B", 11)
    pdf.cell(28, 9, f"  {val}", fill=True)
    pdf.set_font("Arial", "", 10)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 9, f"  {label}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(1)
pdf.ln(2)
pdf.set_font("Arial", "I", 8)
pdf.set_text_color(*GREY)
pdf.cell(0, 5, f"Generated {datetime.date.today().strftime('%d %b %Y')}",
         new_x="LMARGIN", new_y="NEXT")

# ---- body ----
for code, title, intro, items in SECTIONS:
    pdf.add_page()
    pdf.set_fill_color(*NAVY)
    pdf.set_text_color(255, 255, 255)
    pdf.set_font("Arial", "B", 13)
    pdf.cell(0, 10, f"  {title}  ({code})", fill=True,
             new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)

    if intro:
        pdf.set_text_color(*GREY)
        pdf.set_font("Arial", "I", 9)
        pdf.set_x(pdf.l_margin)
        pdf.multi_cell(0, 4.6, clean(intro))
    pdf.set_draw_color(*LINE)
    pdf.line(pdf.l_margin, pdf.get_y() + 1, pdf.w - pdf.r_margin,
             pdf.get_y() + 1)
    pdf.ln(3)

    for tag, heading, body in items:
        if pdf.get_y() > pdf.h - 32:
            pdf.add_page()
        # tag pill
        pdf.set_font("Courier", "B", 8.5)
        tagw = pdf.get_string_width(tag) + 4
        pdf.set_fill_color(*LIGHT)
        pdf.set_text_color(*NAVY)
        pdf.cell(tagw, 5, tag, fill=True, new_x="RIGHT", new_y="TOP")
        remaining = pdf.w - pdf.r_margin - pdf.get_x()
        if remaining < 40:
            pdf.ln(5)
            pdf.set_x(pdf.l_margin)
            remaining = pdf.w - pdf.r_margin - pdf.l_margin
        pdf.set_font("Arial", "B", 9.5)
        pdf.set_text_color(30, 30, 30)
        pdf.multi_cell(remaining, 5, " " + clean(heading))
        if body:
            pdf.set_x(pdf.l_margin + 3)
            pdf.set_font("Arial", "", 9)
            pdf.set_text_color(70, 70, 70)
            pdf.multi_cell(pdf.w - pdf.l_margin - pdf.r_margin - 3, 4.6,
                           clean(body))
        pdf.ln(2.4)

pdf.output(OUT)
print(f"WROTE {OUT}  | sections={len(SECTIONS)} "
      f"steps={sum(len(s[3]) for s in SECTIONS)}")
