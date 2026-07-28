"""
GRC Phase 4: Application-layer Workflow SoD enforcement.

Provides check_grc_sod() — call it before executing any action that
requires a different actor from the resource owner.

On violation: logs to log.grc_sod_violations and raises HTTP 403.
"""

from fastapi import HTTPException
from utils.log4dbexpert import _get_pool
from utils.log4dbexpert import db_write_log


def check_grc_sod(
    action_type: str,
    resource_id,
    resource_owner: str,
    current_user: str,
):
    """
    Raises HTTP 403 if current_user == resource_owner for this action_type,
    and the corresponding SoD rule is active.

    action_type values:
      approve_policy, approve_exception, complete_access_review,
      delete_audit_data, approve_risk
    """
    if not current_user or not resource_owner:
        return  # can't enforce without both parties

    if current_user.strip().lower() == resource_owner.strip().lower():
        # Check whether the rule is active
        try:
            pool = _get_pool()
            conn = pool.getconn()
            try:
                cur = conn.cursor()
                cur.execute(
                    "SELECT rule_id, rule_name FROM config.grc_sod_rules "
                    "WHERE action_type=%s AND is_active=TRUE",
                    (action_type,),
                )
                rule = cur.fetchone()
                if not rule:
                    return  # rule disabled — allow
                rule_id, rule_name = rule

                reason = (
                    f"User '{current_user}' cannot {action_type.replace('_', ' ')} "
                    f"their own resource (id={resource_id})"
                )
                # Log the violation
                cur.execute(
                    "INSERT INTO log.sod_violations "
                    "(rule_id, rule_name, action_type, attempted_by, resource_id, "
                    " resource_owner, violation_reason) "
                    "VALUES (%s,%s,%s,%s,%s,%s,%s)",
                    (rule_id, rule_name, action_type, current_user,
                     str(resource_id), resource_owner, reason),
                )
                conn.commit()
                cur.close()
            finally:
                pool.putconn(conn)
        except Exception as e:
            db_write_log(f"grc_workflow_sod log error: {e}", "", "grc_workflow_sod", "")

        raise HTTPException(status_code=403, detail=(
            f"SoD violation: {action_type.replace('_', ' ')} — "
            f"creator and approver must be different users."
        ))
