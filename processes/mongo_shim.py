"""MongoDB transport for the generic collector: read-only gating + spec execution.

A MongoDB detection step is **a JSON document, not SQL**. `metrics.v_custom_metrics.query`
holds a spec such as::

    {"command": {"serverStatus": 1}, "path": "connections"}
    {"collection": "system.users", "find": {}, "limit": 100}
    {"aggregate": [{"$currentOp": {"allUsers": true}}, {"$match": {"secs_running": {"$gt": 60}}}]}
    {"collection": "orders", "count": {"status": "open"}}
    {"collection": "users", "distinct": "role", "filter": {}}

`run_mongo_spec` executes it and flattens the returned BSON into (columns, rows) so the
shared comparison layer sees exactly what it sees for the SQL vendors — `row_count` and
column conditions are authored the same way.

Because there is no SQL parser to lean on, read-only enforcement is a command allowlist
plus a **recursive** scan for the write / server-side-JavaScript operators. The recursion
is the point: a `$out` nested inside a `$facet` slips straight past a top-level check.

Ported from dbdiagnostics (processes/vendor_shims.py + processes/sql_safety.py) so both
products refuse and execute the same specs; kept self-contained here because this repo has
no vendor_shims layer.
"""
import json

CONNECT_TIMEOUT_SEC = 15
DEFAULT_TIMEOUT_MS = 15000
_MONGO_DEFAULT_LIMIT = 1000

_MONGO_READ_OPS = ("command", "find", "aggregate", "count", "distinct")

# Read-only database commands. Deliberately excludes anything that MUTATES server state even
# though it reads as diagnostic: `profile` (sets a level), `validate` (takes locks / can
# repair), `killOp`, `fsync`, `compact`, `setParameter`.
_MONGO_ALLOWED_COMMANDS = frozenset({
    "aggregate", "buildinfo", "collstats", "connpoolstats", "connectionstatus", "count",
    "currentop", "dbhash", "dbstats", "distinct", "explain", "find", "getcmdlineopts",
    "getdefaultrwconcern", "getlog", "getparameter", "hello", "hostinfo", "ismaster",
    "listcollections", "listcommands", "listdatabases", "listindexes", "ping",
    "replsetgetconfig", "replsetgetstatus", "rolesinfo", "serverstatus",
    "shardconnpoolstats", "top", "usersinfo", "whatsmyuri",
})

# $out / $merge WRITE a collection; $function / $accumulator / $where run server-side
# JavaScript. Any of them, at any depth, refuses the spec.
_MONGO_FORBIDDEN_KEYS = frozenset({"$out", "$merge", "$function", "$accumulator", "$where"})


def _scan_forbidden(node):
    """Recursively look for a write / server-side-JS operator. Returns the key or None."""
    if isinstance(node, dict):
        for k, v in node.items():
            if k in _MONGO_FORBIDDEN_KEYS:
                return k
            found = _scan_forbidden(v)
            if found:
                return found
    elif isinstance(node, (list, tuple)):
        for item in node:
            found = _scan_forbidden(item)
            if found:
                return found
    return None


def validate_readonly_mongo(spec):
    """Return (ok, reason) for a MongoDB detection spec (JSON text or a parsed dict)."""
    if isinstance(spec, str):
        if not spec.strip():
            return False, "empty spec"
        try:
            spec = json.loads(spec)
        except (json.JSONDecodeError, ValueError) as e:
            return False, f"unparseable mongodb spec: {str(e)[:120]}"
    if not isinstance(spec, dict):
        return False, f"spec must be a JSON object, got {type(spec).__name__}"

    ops = [op for op in _MONGO_READ_OPS if op in spec]
    if len(ops) != 1:
        return False, f"expected exactly 1 of {list(_MONGO_READ_OPS)}, got {ops or 'none'}"
    op = ops[0]

    if op == "command":
        cmd = spec["command"]
        if not isinstance(cmd, dict) or not cmd:
            return False, "command must be a non-empty JSON object"
        name = next(iter(cmd))              # command NAME is the first key (wire convention)
        if name.lower() not in _MONGO_ALLOWED_COMMANDS:
            return False, f"command not allowed: {name}"
    elif op == "aggregate":
        if not isinstance(spec["aggregate"], list):
            return False, "aggregate must be a pipeline array"
        # 'collection' is OPTIONAL for aggregate: omitting it runs a DATABASE-level
        # aggregation, the only way to reach server-wide stages ($currentOp). The
        # forbidden-operator scan below covers the pipeline either way.
    else:
        if not spec.get("collection"):
            return False, f"'{op}' requires a 'collection'"

    bad = _scan_forbidden(spec)
    if bad is not None:
        return False, f"write/javascript operator not allowed: {bad}"
    return True, "ok"


def connect_mongodb(server, database, username, password, port, auth_source=None):
    """Open a MongoDB client. `server` may be a bare host or a full mongodb:// /
    mongodb+srv:// URI, in which case host/port/credentials come from the URI.

    `auth_source` carries the target's service_name. MongoDB users are scoped to the
    database they were created in, which is usually `admin` rather than the monitored
    database — getting this wrong reports as "Authentication failed" and is routinely
    mistaken for a wrong password.
    """
    from pymongo import MongoClient

    common = dict(
        serverSelectionTimeoutMS=CONNECT_TIMEOUT_SEC * 1000,
        connectTimeoutMS=CONNECT_TIMEOUT_SEC * 1000,
        socketTimeoutMS=max(CONNECT_TIMEOUT_SEC * 1000, DEFAULT_TIMEOUT_MS + 5000),
        appname="dbdome",
    )
    host = (server or "").strip()
    if host.startswith("mongodb://") or host.startswith("mongodb+srv://"):
        return MongoClient(host, **common)
    return MongoClient(
        host=host, port=int(port or 27017),
        username=username or None, password=password or None,
        authSource=(auth_source or database or "admin"),
        **common)


def _scalarize(v):
    if v is None or isinstance(v, (bool, int, float, str)):
        return v
    if isinstance(v, (dict, list, tuple)):
        try:
            return json.dumps(v, default=str)
        except (TypeError, ValueError):
            return str(v)
    return str(v)                            # ObjectId / datetime / Decimal128 / Binary / …


def _rows_from_documents(documents):
    """Flatten BSON documents into (columns, rows).

    Column order is first-seen across the batch: Mongo is schemaless, so a later document
    can introduce a key the first one lacked. A missing key becomes None rather than a
    shifted row. Nested documents and non-JSON BSON types are stringified so the shared
    comparison layer, which only compares scalars, sees a stable value.
    """
    columns, seen = [], set()
    for doc in documents:
        for k in doc:
            if k not in seen:
                seen.add(k)
                columns.append(k)
    rows = [tuple(_scalarize(doc.get(c)) for c in columns) for doc in documents]
    return columns, rows


def _command_result_rows(doc, path=None):
    """A command reply is ONE document. Emit it as a single row so row_count conditions
    behave (1 row = the command answered), each top-level field a column.

    `path` is an optional dotted selector into the reply, and it is what makes the richest
    command - serverStatus - usable: its interesting numbers (connections.current,
    globalLock.currentQueue, wiredTiger.cache, opcounters) are nested, and without a
    selector they arrive as one JSON blob no detection condition can compare against. A
    path landing on a list yields one row per element.
    """
    if not isinstance(doc, dict):
        return ["result"], [(_scalarize(doc),)]
    if path:
        node = doc
        for part in str(path).split("."):
            if not isinstance(node, dict) or part not in node:
                return [], []                # absent path -> 0 rows, a clean "not applicable"
            node = node[part]
        if isinstance(node, list):
            return _rows_from_documents([n if isinstance(n, dict) else {path: n} for n in node])
        if isinstance(node, dict):
            return _rows_from_documents([node])
        return [path.split(".")[-1]], [(_scalarize(node),)]
    doc = {k: v for k, v in doc.items() if k not in ("ok", "operationTime", "$clusterTime")}
    return _rows_from_documents([doc])


def run_mongo_spec(client, default_db, spec, max_time_ms=None):
    """Execute one read-only MongoDB spec and return (columns, rows).

    Raises ValueError for a malformed or non-read-only spec. The validation is repeated
    here rather than trusted from the caller so no path can bypass it.
    """
    ok, reason = validate_readonly_mongo(spec)
    if not ok:
        raise ValueError(f"unsupported mongodb spec: {reason}")
    if isinstance(spec, str):
        spec = json.loads(spec)

    db = client[spec.get("db") or default_db or "admin"]
    mt = int(max_time_ms) if max_time_ms else None

    if "command" in spec:
        doc = db.command(spec["command"], maxTimeMS=mt) if mt else db.command(spec["command"])
        return _command_result_rows(doc, spec.get("path"))

    limit = int(spec.get("limit") or _MONGO_DEFAULT_LIMIT)

    if "aggregate" in spec:
        pipeline = list(spec["aggregate"])
        if not any("$limit" in st for st in pipeline if isinstance(st, dict)):
            pipeline = pipeline + [{"$limit": limit}]
        target = db if "collection" not in spec else db[spec["collection"]]
        cur = target.aggregate(pipeline, maxTimeMS=mt) if mt else target.aggregate(pipeline)
        return _rows_from_documents(list(cur))

    coll = db[spec["collection"]]

    if "count" in spec:
        n = coll.count_documents(spec["count"] or {}, **({"maxTimeMS": mt} if mt else {}))
        return ["count"], [(n,)]

    if "distinct" in spec:
        vals = coll.distinct(spec["distinct"], spec.get("filter") or {},
                             **({"maxTimeMS": mt} if mt else {}))
        return [spec["distinct"]], [(_scalarize(v),) for v in vals]

    cur = coll.find(spec.get("find") or {}, spec.get("projection") or None)
    if spec.get("sort"):
        cur = cur.sort(list(spec["sort"].items()))
    cur = cur.limit(limit)
    if mt:
        cur = cur.max_time_ms(mt)
    return _rows_from_documents(list(cur))


def substitute_parameters_json(spec_text, parameters):
    """Parameter substitution for a Mongo spec.

    The shared collection.comparison.substitute_parameters emits **SQL** literals ('admin'),
    which is invalid JSON and corrupts a spec. Mongo therefore substitutes with json.dumps
    so a string lands as "admin" and a number lands bare.
    """
    if not parameters or not spec_text:
        return spec_text
    out = spec_text
    for key, value in (parameters or {}).items():
        try:
            literal = json.dumps(value, default=str)
        except (TypeError, ValueError):
            literal = json.dumps(str(value))
        # Quoted forms FIRST. A spec has to stay valid JSON while it is authored, so a
        # string placeholder is written inside quotes ("db": ":dbname"). Substituting the
        # bare token there would leave the surrounding quotes behind and produce ""admin"".
        # Replacing the quoted token with the JSON literal yields "admin" for a string and
        # a bare 5 for a number, which is what each position needs.
        for token in (f'":{key}"', f'"{{{key}}}"', f'"${key}"'):
            out = out.replace(token, literal)
        for token in (f":{key}", f"{{{key}}}", f"${key}"):
            out = out.replace(token, literal)
    return out
