"""Catalog facts for the pre-review step: read the Appverse catalog's public
JSON:API, compare each app's declared software, app_type and
implementation_tags with it, and render the report's Catalog checks block.

Used by pre-review.py (check_catalog). Standard library only.

The source is either an http(s) base URL (the live catalog,
https://openondemand.connectci.org by default) or a local directory holding
one JSON file per resource, for tests and offline runs:

    software.json             [{"id": ..., "title": ...}, ...]
    app_types.json            ["batch-connect-basic", ...]
    implementation_tags.json  ["gpu-enabled", ...]
    apps.json                 [{"title": ..., "github_url": ..., "subpath": ...,
                                "software_id": ...}, ...]

Matching follows the appverse.yml reference: software by Software entry
name, app_type and implementation_tags by vocabulary term, all ignoring case.
"""
import difflib
import json
import os
import urllib.parse
import urllib.request

DEFAULT_CATALOG = "https://openondemand.connectci.org"
ACCEPT = "application/vnd.api+json"
TIMEOUT = 20
MAX_PAGES = 20
PAGE_LIMIT = 50
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


def _get(url):
    req = urllib.request.Request(url, headers={"Accept": ACCEPT, "User-Agent": "appverse-review pre-review"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _fetch_resource(base, key):
    """(items, pages): every page of one resource, following links.next."""
    path, ftype, fields = RESOURCES[key]
    query = urllib.parse.urlencode({"fields[%s]" % ftype: fields, "page[limit]": PAGE_LIMIT})
    url = "%s/jsonapi/%s?%s" % (base.rstrip("/"), path, query)
    items, pages = [], 0
    while url:
        if pages >= MAX_PAGES:
            raise CatalogError("%s: more than %d pages" % (key, MAX_PAGES))
        doc = _get(url)
        pages += 1
        data = doc.get("data")
        if not isinstance(data, list):
            raise CatalogError("%s: response has no data list" % key)
        items += data
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
            out.append({"title": a.get("title") or "",
                        "github_url": gh.get("uri") if isinstance(gh, dict) else gh,
                        "subpath": a.get("field_appverse_app_subpath"),
                        "software_id": rel.get("id") if isinstance(rel, dict) else None})
    return out


def read_catalog(source):
    """{software, app_types, implementation_tags, apps, pages} from a URL or a
    fixture directory. Raises CatalogError (or an OSError/ValueError from the
    network or the files) when any resource cannot be read in full."""
    cat = {"pages": {}}
    if os.path.isdir(source):
        for key in RESOURCES:
            with open(os.path.join(source, key + ".json"), encoding="utf-8") as f:
                cat[key] = json.load(f)
            cat["pages"][key] = 1
        return cat
    if not source.startswith(("http://", "https://")):
        raise CatalogError("catalog source is neither a URL nor a directory: %s" % source)
    for key in RESOURCES:
        items, pages = _fetch_resource(source, key)
        cat[key] = _flatten(key, items)
        cat["pages"][key] = pages
    return cat


def _as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v).strip() for v in value if str(v).strip()]
    return [s.strip() for s in str(value).split(",") if s.strip()]


def declared_values(root_meta, entry, sub_meta, inferred):
    """{software, app_type, implementation_tags, declared}: an app's catalog
    fields by the setup precedence (apps[] entry, then <path>/appverse.yml,
    then the root appverse.yml for a single-app repo). An inferred repo
    (no appverse.yml) declares none of them."""
    if inferred:
        return {"declared": False, "software": None, "app_type": None, "implementation_tags": []}
    layers = [l for l in (entry, sub_meta, root_meta if entry is None else None) if isinstance(l, dict)]

    def first(field):
        for layer in layers:
            v = layer.get(field)
            if v not in (None, ""):
                return str(v).strip()
        return None
    tags = []
    for layer in layers:
        if layer.get("implementation_tags") is not None:
            tags = _as_list(layer.get("implementation_tags"))
            break
    if entry is not None:
        tags = _as_list(root_meta.get("shared_implementation_tags")) + tags
    seen, uniq = set(), []
    for t in tags:
        if t.lower() not in seen:
            seen.add(t.lower())
            uniq.append(t)
    return {"declared": True, "software": first("software"), "app_type": first("app_type"),
            "implementation_tags": uniq}


def compare(cat, decl):
    """The checks for one app against the catalog."""
    sw_by_name = {s["title"].lower(): s for s in cat["software"] if s.get("title")}
    types = {t.lower(): t for t in cat["app_types"]}
    tags = {t.lower(): t for t in cat["implementation_tags"]}
    res = {}
    sw = decl["software"]
    if not decl["declared"]:
        res["software"] = {"status": "not_applicable"}
    elif not sw:
        res["software"] = {"status": "not_declared"}
    elif sw.lower() in sw_by_name:
        res["software"] = {"status": "match", "value": sw, "entry": sw_by_name[sw.lower()]["title"]}
    else:
        close = difflib.get_close_matches(sw.lower(), list(sw_by_name), n=1, cutoff=0.6)
        res["software"] = {"status": "no_match", "value": sw,
                           "closest": sw_by_name[close[0]]["title"] if close else None}
    at = decl["app_type"]
    if not decl["declared"]:
        res["app_type"] = {"status": "not_applicable"}
    elif not at:
        res["app_type"] = {"status": "not_declared"}
    elif at.lower() in types:
        res["app_type"] = {"status": "known", "value": at}
    else:
        res["app_type"] = {"status": "unknown", "value": at}
    unknown = [t for t in decl["implementation_tags"] if t.lower() not in tags]
    known = [t for t in decl["implementation_tags"] if t.lower() in tags]
    res["implementation_tags"] = {"declared": decl["implementation_tags"], "known": known, "unknown": unknown}
    sw_entry = res["software"].get("entry")
    sw_id = next((s["id"] for s in cat["software"] if s.get("title") == sw_entry), None) if sw_entry else None
    res["same_software_apps"] = [
        {"title": a["title"], "github_url": a.get("github_url"), "subpath": a.get("subpath")}
        for a in cat["apps"] if sw_id and a.get("software_id") == sw_id]
    return res


def _q(v):
    return "\"%s\"" % v


def render(cat, per_app, monorepo):
    """The report's Catalog checks block, as lines of Markdown."""
    n_apps = len(cat["apps"])
    lines = ["Read from the catalog's public API: %d published apps (%d page%s), %d Software entries, "
             "%d app types, %d implementation tags." % (
                 n_apps, cat["pages"].get("apps", 1), "" if cat["pages"].get("apps", 1) == 1 else "s",
                 len(cat["software"]), len(cat["app_types"]), len(cat["implementation_tags"])), ""]
    for app_id, res in per_app:
        prefix = "**%s** — " % app_id if monorepo else ""
        same = res["same_software_apps"]
        sw = res["software"]
        if sw["status"] == "match":
            if same:
                names = "; ".join("%s (%s)" % (a["title"], a["github_url"] or "no repo link") for a in same)
                dup = "%d published app%s implement %s: %s." % (len(same), "" if len(same) == 1 else "s",
                                                              _q(sw["entry"]), names)
            else:
                dup = "No published app implements %s." % _q(sw["entry"])
        elif sw["status"] == "not_applicable":
            dup = ("No `software` value is declared, so no catalog app can be matched by software; "
                   "compare by name against the %d published apps." % n_apps)
        else:
            dup = "The `software` value has no catalog entry, so no catalog app can be matched by software."
        lines.append("- %sDuplicate check — %s" % (prefix, dup))
        lines.append(PLACEHOLDER)
        if sw["status"] == "match":
            s = "matches the Software entry %s." % _q(sw["entry"])
        elif sw["status"] == "no_match":
            s = "%s has no Software entry%s. The reviewer creates the entry (should it exist) or asks for " \
                "the value to be corrected." % (_q(sw["value"]), "; closest is %s" % _q(sw["closest"])
                                                if sw.get("closest") else "")
        elif sw["status"] == "not_declared":
            s = "not declared; `software` is required in `appverse.yml`."
        else:
            s = "not applicable (inferred repo, no `software` value)."
        lines.append("- %s`software` — %s" % (prefix, s))
        at = res["app_type"]
        if at["status"] == "known":
            t = "%s is in the app-type vocabulary." % _q(at["value"])
        elif at["status"] == "unknown":
            t = "%s is not in the app-type vocabulary (%s)." % (_q(at["value"]), ", ".join(cat["app_types"]))
        elif at["status"] == "not_declared":
            t = "not declared; `app_type` is required in `appverse.yml`."
        else:
            t = "not applicable (inferred repo; the type comes from `manifest.yml`)."
        lines.append("- %s`app_type` — %s" % (prefix, t))
        tg = res["implementation_tags"]
        if not tg["declared"]:
            g = "none declared."
        elif tg["unknown"]:
            g = "not in the vocabulary: %s (known: %s)." % (", ".join(_q(t) for t in tg["unknown"]),
                                                            ", ".join(_q(t) for t in tg["known"]) or "none")
        else:
            g = "all in the vocabulary: %s." % ", ".join(_q(t) for t in tg["known"])
        lines.append("- %s`implementation_tags` — %s" % (prefix, g))
    return lines


def not_read_block(reason):
    return ["The catalog was not read (%s). Run the checks by hand: see the Reviewer Process appendix, "
            "\"Reading the catalog by hand\"." % reason, "", PLACEHOLDER.strip()]
