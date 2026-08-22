"""Precedent retrieval -- "has this server run something like this before?"

Deterministic first, model second, exactly like dbdiagnostics/resolution_agent:

  1. Pull a bounded set of recent calls for this server from
     monitoring.general_metric_metadata_results (the ix_gmmr_server_metric_date
     index makes that a seek, not a scan of 1.4M rows).
  2. Extract whatever query text each stored call carries and normalize it to a
     fingerprint. An EXACT fingerprint hit is the strongest possible evidence of
     "this is routine application traffic" and costs no model time at all.
  3. Only if there is no exact hit do we spend embeddings ranking near matches.

Everything here is best-effort: any failure returns "no precedent found", which
pushes the decision toward alerting rather than silence.
"""
import psycopg2.extras

from security_agent import config, fingerprint as fp
from security_agent import llm

# Keys that have been observed to carry statement text in metric_metadata
# payloads, most specific first. The jsonb shape varies by collector and vendor,
# so extraction is by key-name priority rather than a fixed path.
_QUERY_KEYS = (
    "query", "query_text", "sql_text", "statement", "sqltext", "sql",
    "command_text", "text", "batch_text", "last_query", "objectname_query",
)
_CONTEXT_KEYS = (
    "login_name", "program_name", "host_name", "database_name", "nt_user_name",
    "client_net_address", "object_name", "schema_name",
)


def _walk_for_query(node, depth=0):
    """First plausible statement text anywhere in a nested json payload."""
    if depth > 6 or node is None:
        return ""
    if isinstance(node, str):
        return node if len(node) > 12 else ""
    if isinstance(node, list):
        for item in node:
            got = _walk_for_query(item, depth + 1)
            if got:
                return got
        return ""
    if isinstance(node, dict):
        lowered = {str(k).lower(): v for k, v in node.items()}
        for key in _QUERY_KEYS:
            v = lowered.get(key)
            if isinstance(v, str) and len(v) > 12:
                return v
        for v in node.values():
            got = _walk_for_query(v, depth + 1)
            if got:
                return got
    return ""


def extract_query(metadata) -> str:
    """Best-effort statement text out of one metric_metadata payload."""
    try:
        return (_walk_for_query(metadata) or "").strip()
    except Exception:
        return ""


def extract_context(metadata) -> dict:
    """Login / program / host style fields, when the payload carries them."""
    out = {}

    def walk(node, depth=0):
        if depth > 4 or not isinstance(node, (dict, list)):
            return
        if isinstance(node, list):
            for i in node[:20]:
                walk(i, depth + 1)
            return
        for k, v in node.items():
            lk = str(k).lower()
            if lk in _CONTEXT_KEYS and isinstance(v, (str, int)) and str(v).strip():
                out.setdefault(lk, str(v))
            elif isinstance(v, (dict, list)):
                walk(v, depth + 1)

    try:
        walk(metadata)
    except Exception:
        pass
    return out


def _fetch_candidates(conn, server, metric_name=None):
    """Recent stored calls for this server, newest first, bounded.

    NOTE ON entry_date: in this table it is the ONSET of a state, not a
    freshness stamp, so a narrow window returns nothing at all. We order by
    entry_date DESC to ride ix_gmmr_server_metric_date but deliberately do NOT
    require a recent date -- the lookback is a generous floor, not a filter that
    the data is expected to satisfy.
    """
    sql = """
        SELECT id, row_id, server, metric_name, metric_metadata, entry_date
        FROM monitoring.general_metric_metadata_results
        WHERE server = %s
          AND metric_metadata IS NOT NULL
    """
    params = [server]
    if metric_name:
        # Same metric family first: the most relevant precedent for "is this
        # login/query normal" is other observations of the same metric.
        sql += " AND metric_name = %s"
        params.append(metric_name)
    sql += " ORDER BY entry_date DESC LIMIT %s"
    params.append(config.candidate_limit())

    with conn.cursor(cursor_factory=psycopg2.extras.DictCursor) as cur:
        cur.execute(sql, params)
        return [dict(r) for r in cur.fetchall()]


def _cosine(a, b) -> float:
    if not a or not b:
        return 0.0
    dot = na = nb = 0.0
    for x, y in zip(a, b):
        dot += x * y
        na += x * x
        nb += y * y
    if na <= 0 or nb <= 0:
        return 0.0
    return dot / ((na ** 0.5) * (nb ** 0.5))


def find_precedent(conn, server: str, query_text: str, metric_name: str = None) -> dict:
    """What this server has run that resembles `query_text`.

    Returns a dict the prompt layer renders and the agent records:
        exact_matches   int   calls with an identical normalized fingerprint
        distinct_shapes int   how many distinct statements this server runs
        neighbours      list  up to top_k {query, similarity, metric_name, entry_date}
        searched        int   candidates actually examined
        method          str   'fingerprint' | 'fingerprint+embedding' | 'none'
    """
    empty = {"exact_matches": 0, "distinct_shapes": 0, "neighbours": [],
             "searched": 0, "method": "none", "error": None}
    if not query_text:
        return empty

    try:
        rows = _fetch_candidates(conn, server, metric_name)
        # A metric-scoped lookup can be too narrow to establish a baseline; widen
        # to the whole server rather than concluding "no precedent" from silence.
        if len(rows) < 20 and metric_name:
            rows = _fetch_candidates(conn, server, None)
    except Exception as e:
        out = dict(empty)
        out["error"] = f"candidate fetch failed: {e}"
        return out

    target_fp = fp.fingerprint(query_text)
    seen_fps, cand = set(), []
    exact = 0
    for r in rows:
        q = extract_query(r.get("metric_metadata"))
        if not q:
            continue
        f = fp.fingerprint(q)
        if not f:
            continue
        seen_fps.add(f)
        if f == target_fp:
            exact += 1
        elif len(cand) < 200:
            cand.append({"query": q, "metric_name": r.get("metric_name"),
                         "entry_date": r.get("entry_date")})

    out = {
        "exact_matches": exact,
        "distinct_shapes": len(seen_fps),
        "neighbours": [],
        "searched": len(rows),
        "method": "fingerprint",
        "error": None,
    }

    # An exact fingerprint hit settles it -- no reason to spend seconds of CPU
    # embedding neighbours when the statement itself is already known traffic.
    if exact or not cand or not config.use_embeddings() or not llm.available():
        return out

    try:
        q_vec = llm.embed(query_text[:2000])
        scored = []
        for c in cand[:60]:                      # bounded: embeddings are the slow part
            try:
                s = _cosine(q_vec, llm.embed(c["query"][:2000]))
            except Exception:
                s = 0.0
            if s >= config.min_similarity():
                scored.append((s, c))
        scored.sort(key=lambda t: t[0], reverse=True)
        out["neighbours"] = [
            {"query": c["query"][:600], "similarity": round(s, 3),
             "metric_name": c.get("metric_name"), "entry_date": c.get("entry_date")}
            for s, c in scored[:config.top_k()]
        ]
        out["method"] = "fingerprint+embedding"
    except Exception as e:
        # Ranking is a nicety; losing it must not lose the fingerprint verdict.
        out["error"] = f"embedding rank failed: {e}"
    return out
