"""Catalog facts for the pre-review step: read the Appverse catalog's public
JSON:API, compare each app's declared software, app_type and
implementation_tags with it, suggest a Software entry from the app's names
and README when the declared software does not match one, and render the
report's Catalog checks block.

Used by pre-review.py (check_catalog). Standard library only.

The source is either an http(s) base URL (the live catalog,
https://openondemand.connectci.org by default) or a local directory holding
one JSON file per resource, for tests and offline runs:

    software.json             [{"id": ..., "title": ...}, ...]
    app_types.json            ["batch-connect-basic", ...]
    implementation_tags.json  ["gpu-enabled", ...]
    apps.json                 [{"id": ..., "title": ..., "github_url": ...,
                                "subpath": ..., "software_id": ...}, ...]

Declared values follow the catalog's own sync (RepoSyncService): an apps[]
entry's keys override the app's own appverse.yml whenever the key is
present, even empty; implementation_tags and shared_implementation_tags
count only when they are YAML lists. Software, app_type and tags match
their catalog terms ignoring case. Values from the reviewed repo are
untrusted: every one is rendered through code_span(), one line, capped.
"""
import json
import os
import re
import time
import urllib.parse
import urllib.request

import metadata_facts

DEFAULT_CATALOG = "https://openondemand.connectci.org"
ACCEPT = "application/vnd.api+json"
TIMEOUT = 20
DEADLINE = 120  # seconds for the whole read
MAX_PAGES = 20
PAGE_LIMIT = 50
MAX_VALUE = 80
MAX_REPOS = 10
PLACEHOLDER = ("  - **Duplicate-check rationale:** _<reviewer fills in — the outcome and why, "
               "per the Reviewer Process's Duplicate check; edit before pasting into the issue or email>_")

# resource key -> (JSON:API path, sparse-fieldset type, fields)
RESOURCES = {
    "software": ("node/appverse_software", "node--appverse_software", "title"),
    "app_types": ("taxonomy_term/appverse_app_type", "taxonomy_term--appverse_app_type", "name"),
    "implementation_tags": ("taxonomy_term/appverse_implementation_tags",
                            "taxonomy_term--appverse_implementation_tags", "name"),
    "apps": ("node/appverse_app", "node--appverse_app",
             "title,field_appverse_github_url,field_appverse_app_subpath,field_appverse_software_implemen"),
}


class CatalogError(Exception):
    pass


def code_span(value):
    """An untrusted value as one inline code span: one line, at most
    MAX_VALUE characters, no backticks. Markdown and pandoc render a code
    span's contents literally, so HTML, comments and headings stay text."""
    text = " ".join(str(value).split()).replace("`", "'")
    if len(text) > MAX_VALUE:
        text = text[:MAX_VALUE - 1] + "…"
    return "`%s`" % (text or " ")


def _get(url, deadline):
    req = urllib.request.Request(url, headers={"Accept": ACCEPT, "User-Agent": "appverse-review pre-review"})
    for attempt in (1, 2):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise CatalogError("the catalog read took longer than %d s" % DEADLINE)
        try:
            with urllib.request.urlopen(req, timeout=min(TIMEOUT, remaining)) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except (OSError, ValueError):
            if attempt == 2:
                raise
            time.sleep(2)


def _fetch_resource(base, key, deadline):
    """(items, pages): every page of one resource, sorted, following
    links.next on the catalog's own host only."""
    path, ftype, fields = RESOURCES[key]
    query = urllib.parse.urlencode({"fields[%s]" % ftype: fields, "page[limit]": PAGE_LIMIT,
                                    "sort": "drupal_internal__nid" if key in ("software", "apps")
                                    else "drupal_internal__tid"})
    url = "%s/jsonapi/%s?%s" % (base.rstrip("/"), path, query)
    host = urllib.parse.urlparse(base).netloc
    items, pages, seen = [], 0, set()
    while url:
        if pages >= MAX_PAGES:
            raise CatalogError("%s: more than %d pages" % (key, MAX_PAGES))
        if urllib.parse.urlparse(url).netloc != host:
            raise CatalogError("%s: next page is on another host" % key)
        doc = _get(url, deadline)
        pages += 1
        data = doc.get("data") if isinstance(doc, dict) else None
        if not isinstance(data, list):
            raise CatalogError("%s: response has no data list" % key)
        for x in data:
            if isinstance(x, dict) and x.get("id") not in seen:
                seen.add(x.get("id"))
                items.append(x)
        url = ((doc.get("links") or {}).get("next") or {}).get("href")
    return items, pages


def _flatten(key, items):
    out = []
    for x in items:
        a = x.get("attributes") or {}
        if key == "software":
            out.append({"id": x.get("id"), "title": a.get("title") or ""})
        elif key in ("app_types", "implementation_tags"):
            if a.get("name"):
                out.append(a["name"])
        else:
            gh = a.get("field_appverse_github_url") or {}
            rel = ((x.get("relationships") or {}).get("field_appverse_software_implemen") or {}).get("data")
            out.append({"id": x.get("id"), "title": a.get("title") or "",
                        "github_url": gh.get("uri") if isinstance(gh, dict) else gh,
                        "subpath": a.get("field_appverse_app_subpath"),
                        "software_id": rel.get("id") if isinstance(rel, dict) else None})
    return out


def _sanity(cat):
    """A field rename in the API would otherwise read as an empty catalog."""
    for key in ("software", "app_types", "implementation_tags", "apps"):
        if not cat[key]:
            raise CatalogError("%s: the catalog returned none" % key)
    if not any(a.get("software_id") for a in cat["apps"]):
        raise CatalogError("apps: no app carries a software link; the API fields may have changed")
    if not any(a.get("github_url") for a in cat["apps"]):
        raise CatalogError("apps: no app carries a repository URL; the API fields may have changed")


def read_catalog(source):
    """{software, app_types, implementation_tags, apps, pages} from a URL or a
    fixture directory. Raises CatalogError, OSError or ValueError when any
    resource cannot be read in full; a partial read is never returned."""
    cat = {"pages": {}}
    if os.path.isdir(source):
        for key in RESOURCES:
            with open(os.path.join(source, key + ".json"), encoding="utf-8") as f:
                cat[key] = json.load(f)
            cat["pages"][key] = 1
    elif source.startswith(("http://", "https://")):
        deadline = time.monotonic() + DEADLINE
        for key in RESOURCES:
            items, pages = _fetch_resource(source, key, deadline)
            cat[key] = _flatten(key, items)
            cat["pages"][key] = pages
    else:
        raise CatalogError("catalog source is neither a URL nor a directory: %s" % source)
    _sanity(cat)
    return cat


def repo_key(url):
    """owner/repo, lowercased, from a GitHub URL or git remote; None if not one."""
    if not url:
        return None
    m = re.search(r"github\.com[/:]([^/\s]+)/([^/\s]+?)(?:\.git)?/?$", str(url).strip(), re.I)
    return ("%s/%s" % (m.group(1), m.group(2))).lower() if m else None


def _tags(layer, key):
    v = layer.get(key)
    return [str(t).strip() for t in v if str(t).strip()] if isinstance(v, list) else None


def declared_values(root_meta, entry, sub_meta, shape):
    """An app's catalog fields, by the sync's rules. shape is single |
    monorepo | inferred | unparsed. Returns {status, software, app_type,
    implementation_tags, tags_note}."""
    if shape in ("inferred", "unparsed"):
        return {"status": shape, "software": None, "app_type": None, "implementation_tags": [],
                "tags_note": None}
    if shape == "monorepo":
        merged = metadata_facts.app_layer(entry, sub_meta)
    else:
        merged = dict(root_meta or {})

    def scalar(field):
        v = merged.get(field)
        return None if v is None or isinstance(v, (list, dict)) or str(v).strip() == "" else str(v).strip()
    tags, note = _tags(merged, "implementation_tags"), None
    if tags is None:
        if merged.get("implementation_tags") not in (None, ""):
            note = "implementation_tags is not a YAML list, so the catalog applies none of it"
        tags = []
    if shape == "monorepo":
        shared = _tags(root_meta, "shared_implementation_tags")
        if shared is None and root_meta.get("shared_implementation_tags") not in (None, ""):
            note = (note + "; " if note else "") + \
                "shared_implementation_tags is not a YAML list, so the catalog applies none of it"
        tags = (shared or []) + tags
    seen, uniq = set(), []
    for t in tags:
        if t.lower() not in seen:
            seen.add(t.lower())
            uniq.append(t)
    return {"status": "declared", "software": scalar("software"), "app_type": scalar("app_type"),
            "implementation_tags": uniq, "tags_note": note}


def _levenshtein(a, b):
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def _type_key(value):
    """An app_type compared loosely: lowercase, runs of spaces, underscores
    and hyphens as one hyphen."""
    return re.sub(r"[\s_-]+", "-", str(value).strip().lower()).strip("-")


def closest_app_types(value, app_types):
    """The vocabulary terms an unknown app_type most likely meant, in
    vocabulary order: those equal to it compared loosely (_type_key); else
    those it is a prefix of, or that are a prefix of it ("Batch Connect" ->
    batch-connect-basic and batch-connect-VNC); else those within edit
    distance 3 of it, the nearest only. Empty when nothing is close. A
    suggestion only: app_type itself must match exactly."""
    key = _type_key(value)
    if not key:
        return []
    keyed = [(t, _type_key(t)) for t in app_types]
    same = [t for t, k in keyed if k == key]
    if same:
        return same
    prefix = [t for t, k in keyed if k.startswith(key + "-") or key.startswith(k + "-")]
    if prefix:
        return prefix
    dist = [(_levenshtein(key, k), t) for t, k in keyed]
    best = min((d for d, _ in dist), default=None)
    return [t for d, t in dist if d == best] if best is not None and best <= 3 else []


MAX_TITLE_LINES = 200  # lines of a README searched for its title
MAX_TITLE = 300  # characters of a title line read
# The order an app's names are read for a suggestion; the first with a hit wins.
SUGGEST_SOURCES = ("app_path", "repo_name", "manifest", "readme")
SUGGEST_LABELS = {"app_path": "app's folder name", "repo_name": "repository name",
                  "manifest": "`manifest.yml` name", "readme": "README title"}
SETEXT_H1 = re.compile(r" {0,3}=+[ \t]*")


def strip_markup(line):
    """One title line without the places a title is named in passing:
    images and badges, link targets, HTML and comments, bare URLs and code
    spans. Link text stays. Capped at MAX_TITLE characters first, so every
    pattern runs on a short string."""
    line = line[:MAX_TITLE]
    line = re.sub(r"<!--.*?-->|<[^<>]*>", " ", line)
    line = re.sub(r"!\[[^\[\]]*\]\([^()]*\)", " ", line)
    line = re.sub(r"\[([^\[\]]*)\]\([^()]*\)", r"\1", line)
    line = re.sub(r"(`+).*?\1|https?://\S+", " ", line)
    return line


def readme_title(text):
    """A README's title: its first level-1 heading (ATX "# " or setext
    "==="), outside code fences and HTML comments, within the first
    MAX_TITLE_LINES lines, after strip_markup; None when it has none. The
    body is not read: against the published apps it named the wrong entry
    more often than the right one (a cluster called Grace, "visit" for
    VisIt), while titles and names rarely did. Line by line, so a hostile
    README costs no more than its first lines."""
    fence, comment, prev = None, False, None
    for line in text.splitlines()[:MAX_TITLE_LINES]:
        bare = line.strip()
        if comment:
            comment = "-->" not in bare
            prev = None
            continue
        if fence:
            fence = None if bare.startswith(fence) else fence
            continue
        if bare.startswith(("```", "~~~")):
            fence, prev = bare[:3], None
            continue
        if bare.startswith("<!--") and "-->" not in bare:
            comment, prev = True, None
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent <= 3 and (bare == "#" or bare.startswith(("# ", "#\t"))):
            return strip_markup(bare[1:].strip().rstrip("#").strip()) or None
        if prev is not None and SETEXT_H1.fullmatch(line[:MAX_TITLE]):
            return strip_markup(prev.strip()) or None
        prev = line if bare and indent <= 3 and not bare.startswith("#") else None
    return None


def first_title(text, titles):
    """(title, text as written) for the catalog title named first in text,
    as whole words, ignoring case; None if none is. Underscores count as
    word breaks, so a name like bc_osc_rstudio_server names RStudio. At one
    place the longest title wins ("Jupyter Notebook" over "Jupyter")."""
    if not text or not titles:
        return None
    by_key = {}
    for t in sorted(titles, key=lambda t: (-len(t), t)):
        by_key.setdefault(t.lower(), t)
    rx = re.compile(r"(?<![^\W_])(%s)(?![^\W_])" % "|".join(re.escape(k) for k in by_key), re.I)
    m = rx.search(text)
    return (by_key[m.group(1).lower()], m.group(1)) if m else None


def suggest_software(cat, sources):
    """The Software entry an app most likely implements, for an app whose
    software status is not match: {value, source, entry}, or None. sources
    maps a SUGGEST_SOURCES key to its text; they are read in that order and
    the first with a hit wins. Of the README only its title is read
    (readme_title). value is the text as written. A suggestion only: same_software_apps stays a declared
    match, and the reviewer decides."""
    titles = [s["title"] for s in cat["software"] if s.get("title")]
    for source in SUGGEST_SOURCES:
        text = (sources or {}).get(source)
        if not isinstance(text, str) or not text.strip():
            continue
        hit = first_title(readme_title(text) if source == "readme" else text, titles)
        if hit:
            return {"value": hit[1], "source": source, "entry": hit[0]}
    return None


def _apps_for(cat, entry, this_repo):
    sw_id = next((s["id"] for s in cat["software"] if s.get("title") == entry), None) if entry else None
    return [{"title": a["title"], "github_url": a.get("github_url"), "subpath": a.get("subpath"),
             "this_repo": bool(this_repo) and repo_key(a.get("github_url")) == this_repo}
            for a in cat["apps"] if sw_id and a.get("software_id") == sw_id]


def compare(cat, decl, this_repo, sources=None):
    """The checks for one app against the catalog. this_repo is the reviewed
    repo's owner/repo (or None), used to mark its own published apps. For an
    app whose software is not a match, sources (suggest_software) give
    software.suggested and suggested_same_software_apps."""
    sw_by_name = {s["title"].lower(): s for s in cat["software"] if s.get("title")}
    types = {t.lower() for t in cat["app_types"]}
    tags = {t.lower() for t in cat["implementation_tags"]}
    res = {"shape": decl["status"]}
    sw = decl["software"]
    if decl["status"] != "declared":
        res["software"] = {"status": decl["status"]}
    elif not sw:
        res["software"] = {"status": "not_declared"}
    elif sw.lower() in sw_by_name:
        res["software"] = {"status": "match", "value": sw, "entry": sw_by_name[sw.lower()]["title"]}
    else:
        near = sorted((_levenshtein(sw.lower(), k), k) for k in sw_by_name)
        res["software"] = {"status": "no_match", "value": sw,
                           "closest": sw_by_name[near[0][1]]["title"] if near and near[0][0] <= 3 else None}
    at = decl["app_type"]
    if decl["status"] != "declared":
        res["app_type"] = {"status": decl["status"]}
    elif not at:
        res["app_type"] = {"status": "not_declared"}
    else:
        res["app_type"] = {"status": "known" if at.lower() in types else "unknown", "value": at}
        if res["app_type"]["status"] == "unknown":
            res["app_type"]["closest"] = closest_app_types(at, cat["app_types"])
    res["implementation_tags"] = {
        "declared": decl["implementation_tags"],
        "known": [t for t in decl["implementation_tags"] if t.lower() in tags],
        "unknown": [t for t in decl["implementation_tags"] if t.lower() not in tags],
        "note": decl.get("tags_note")}
    res["same_software_apps"] = _apps_for(cat, res["software"].get("entry"), this_repo)
    suggested = suggest_software(cat, sources) if res["software"]["status"] != "match" else None
    if suggested:
        res["software"]["suggested"] = suggested
    res["suggested_same_software_apps"] = _apps_for(cat, suggested["entry"], this_repo) if suggested else []
    return res


def _same_software(entry, apps):
    """One line naming the repos whose published apps implement this software,
    the reviewed repo marked; at most MAX_REPOS repos named."""
    by_repo = {}
    for a in apps:
        key = repo_key(a["github_url"]) or (a["github_url"] or "no repository link")
        by_repo.setdefault(key, []).append(a)
    others = [k for k, v in by_repo.items() if not v[0]["this_repo"]]
    mine = [k for k, v in by_repo.items() if v[0]["this_repo"]]
    n_other = sum(len(by_repo[k]) for k in others)
    parts = []
    for k in mine:
        parts.append("%s (this repo, already published: %d app%s)" % (
            code_span(k), len(by_repo[k]), "" if len(by_repo[k]) == 1 else "s"))
    for k in sorted(others, key=lambda r: (-len(by_repo[r]), r))[:MAX_REPOS]:
        n = len(by_repo[k])
        parts.append("%s (%d app%s)" % (code_span(k), n, "" if n == 1 else "s"))
    if len(others) > MAX_REPOS:
        parts.append("and %d more repos" % (len(others) - MAX_REPOS))
    if not apps:
        return "No published app implements the Software entry %s." % code_span(entry)
    lead = ("%d published app%s from other repos implement%s %s" % (
        n_other, "" if n_other == 1 else "s", "s" if n_other == 1 else "", code_span(entry))
            if n_other else "No published app from another repo implements %s" % code_span(entry))
    return "%s: %s." % (lead, "; ".join(parts))


def render(cat, per_app, monorepo):
    """The report's Catalog checks block, as lines of Markdown."""
    n_apps = len(cat["apps"])
    lines = ["Read from the catalog's public API: %d published apps (%d page%s), %d Software entries, "
             "%d app types, %d implementation tags." % (
                 n_apps, cat["pages"].get("apps", 1), "" if cat["pages"].get("apps", 1) == 1 else "s",
                 len(cat["software"]), len(cat["app_types"]), len(cat["implementation_tags"])), ""]
    for app_id, res in per_app:
        prefix = "**%s** — " % code_span(app_id) if monorepo else ""
        sw = res["software"]
        if sw["status"] == "match":
            dup = _same_software(sw["entry"], res["same_software_apps"])
        elif sw["status"] == "inferred":
            dup = ("no `software` value is declared, so no catalog app can be matched by software; "
                   "compare by name against the %d published apps." % n_apps)
        elif sw["status"] == "unparsed":
            dup = "`appverse.yml` did not parse, so the declared values could not be read."
        elif sw["status"] == "not_declared":
            dup = "no `software` value is declared, so no catalog app can be matched by software."
        else:
            dup = "the `software` value has no catalog entry, so no catalog app can be matched by software."
        if sw.get("suggested"):
            sug = sw["suggested"]
            dup += " The %s suggests the Software entry %s (not a declared match): %s" % (
                SUGGEST_LABELS.get(sug["source"], sug["source"]), code_span(sug["entry"]),
                _same_software(sug["entry"], res.get("suggested_same_software_apps") or []))
        lines.append("- %sDuplicate check — %s" % (prefix, dup[0].upper() + dup[1:]))
        lines.append(PLACEHOLDER)
        if sw["status"] == "match":
            s = "matches the Software entry %s." % code_span(sw["entry"])
        elif sw["status"] == "no_match":
            s = "%s has no Software entry%s. The reviewer creates the entry (should it exist) or asks for " \
                "the value to be corrected." % (code_span(sw["value"]), "; the catalog would suggest %s"
                                                % code_span(sw["closest"]) if sw.get("closest") else "")
        elif sw["status"] == "not_declared":
            s = "not declared; `software` is required in `appverse.yml`."
        elif sw["status"] == "unparsed":
            s = "not checked (`appverse.yml` did not parse)."
        else:
            s = "not applicable (inferred repo, no `software` value)."
        lines.append("- %s`software` — %s" % (prefix, s))
        at = res["app_type"]
        if at["status"] == "known":
            t = "%s is in the app-type vocabulary." % code_span(at["value"])
        elif at["status"] == "unknown":
            t = "%s is not in the published app-type vocabulary (%s)." % (
                code_span(at["value"]), ", ".join(code_span(x) for x in cat["app_types"]))
            if at.get("closest"):
                t += " Did you mean %s?" % " or ".join(code_span(x) for x in at["closest"])
        elif at["status"] == "not_declared":
            t = "not declared; `app_type` is required in `appverse.yml`."
        elif at["status"] == "unparsed":
            t = "not checked (`appverse.yml` did not parse)."
        else:
            t = "not applicable (inferred repo; the type comes from `manifest.yml`)."
        lines.append("- %s`app_type` — %s" % (prefix, t))
        tg = res["implementation_tags"]
        if res["shape"] in ("inferred", "unparsed"):
            g = "not applicable." if res["shape"] == "inferred" else "not checked (`appverse.yml` did not parse)."
        elif not tg["declared"]:
            g = "none declared."
        elif tg["unknown"]:
            g = "not in the published vocabulary: %s (known: %s)." % (
                ", ".join(code_span(t) for t in tg["unknown"]),
                ", ".join(code_span(t) for t in tg["known"]) or "none")
        else:
            g = "all in the vocabulary: %s." % ", ".join(code_span(t) for t in tg["known"])
        if tg.get("note"):
            g += " Note: %s." % tg["note"]
        lines.append("- %s`implementation_tags` — %s" % (prefix, g))
    return lines


def not_read_block(reason):
    return ["The catalog was not read (%s). Run the checks by hand: see the Reviewer Process appendix, "
            "\"Reading the catalog by hand\"." % reason, "", PLACEHOLDER.strip()]
