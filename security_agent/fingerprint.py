"""Normalize SQL into a comparable fingerprint.

This is the cheap, deterministic half of "have we seen this query before" and it
carries most of the weight: application traffic is the same handful of statements
with different literals, so stripping the literals collapses thousands of calls
onto a few dozen fingerprints. The model is only needed for what survives that.

Deliberately conservative -- this is a security control, so normalization must
never merge two statements that differ in a way an attacker could exploit. We
erase literals and whitespace, and nothing else: table names, columns, operators,
function calls and statement structure all survive.
"""
import hashlib
import re

# Order matters: comments first (they can contain quotes), then strings (they can
# contain digits), then numbers.
_RE_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
_RE_LINE_COMMENT = re.compile(r"--[^\n]*")
_RE_SQSTRING = re.compile(r"N?'(?:''|[^'])*'")
_RE_DQSTRING = re.compile(r'"(?:""|[^"])*"')
_RE_BRACKETED = re.compile(r"\[[^\]]*\]")          # [dbo].[Table] -- keep the name
_RE_NUMBER = re.compile(r"\b\d+(?:\.\d+)?\b")
_RE_HEX = re.compile(r"\b0x[0-9a-fA-F]+\b")
_RE_PARAM = re.compile(r"[@:$]\w+")                 # @p1, :name, $1
_RE_INLIST = re.compile(r"\(\s*\?(?:\s*,\s*\?)+\s*\)")
_RE_WS = re.compile(r"\s+")


def normalize(sql: str) -> str:
    """Literal-free, whitespace-collapsed, lower-cased form of a statement."""
    if not sql:
        return ""
    s = str(sql)
    s = _RE_BLOCK_COMMENT.sub(" ", s)
    s = _RE_LINE_COMMENT.sub(" ", s)
    s = _RE_HEX.sub("?", s)
    s = _RE_SQSTRING.sub("?", s)
    s = _RE_DQSTRING.sub("?", s)
    # [dbo].[MyTable] -> dbo.mytable : identifier survives, quoting does not.
    s = _RE_BRACKETED.sub(lambda m: m.group(0)[1:-1], s)
    s = _RE_PARAM.sub("?", s)
    s = _RE_NUMBER.sub("?", s)
    s = _RE_WS.sub(" ", s).strip().rstrip(";").strip()
    # IN (?, ?, ?) and IN (?) are the same statement with a different batch size.
    s = _RE_INLIST.sub("(?)", s)
    return s.lower()


def fingerprint(sql: str) -> str:
    """Stable short hash of the normalized statement."""
    n = normalize(sql)
    if not n:
        return ""
    return hashlib.sha1(n.encode("utf-8", "replace")).hexdigest()[:16]


def shape(sql: str) -> str:
    """Coarse statement class, used for grouping and for the prompt header."""
    n = normalize(sql)
    if not n:
        return "unknown"
    head = n.split(" ", 1)[0]
    if head in ("select", "insert", "update", "delete", "merge", "exec",
                "execute", "create", "alter", "drop", "grant", "revoke",
                "truncate", "backup", "restore", "declare", "with", "use"):
        return head
    return "other"


# Statement classes that are inherently privileged. Precedent alone must not
# excuse these: "the attacker did it yesterday too" is not a reason to stay
# quiet, so the agent is told to weight these heavily regardless of history.
PRIVILEGED_SHAPES = {"grant", "revoke", "drop", "alter", "create",
                     "truncate", "backup", "restore"}


def is_privileged(sql: str) -> bool:
    return shape(sql) in PRIVILEGED_SHAPES
