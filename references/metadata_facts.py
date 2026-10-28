"""Each app's catalog metadata, resolved the way the hub's sync resolves it.

The hub (cyberteam_drupal RepoSyncService::applyDeclaredApp) is the source of
these rules, not the schema's comments, so a review judges STR-02 on the
fields the catalog would actually get:

- An app's layer is its <path>/appverse.yml overridden by its inline apps[]
  entry (PHP array_replace), without the structural `path` key. A member
  appverse.yml that cannot be read counts as empty.
- A monorepo member inherits the root `maintainer` mapping, whole, only when
  its layer has no `maintainer` or `maintainer: null` (PHP isset). An app that
  declares any maintainer of its own, even `{}` or a partial one, keeps it.
- For monorepo members only, `name` and `description` fall back to the app's
  manifest.yml when the layer's value is absent or null (PHP ??). A single
  declared repo has no manifest fallback; its `title` stands in for `name`.
- A required field is missing when its value is PHP-falsy.
- A repo with no root appverse.yml (inferred), or one that cannot be read,
  declares nothing, so nothing is demanded of its apps.

resolve() returns the metadata.json document (schema metadata/1).
"""
import os

SCHEMA = "metadata/1"
FIELDS = ("name", "description", "app_type", "software", "implementation_tags",
          "maintainer.name", "maintainer.support_url")
# The hub's required fields, in the order it reports them. `software` is not
# among them: a missing one rejects the app separately (software_missing).
REQUIRED = ("name", "description", "app_type", "maintainer.name", "maintainer.support_url")
MANIFEST_FALLBACK = ("name", "description")
REFUSED_NOTE = "uses YAML anchors or aliases, which this tool does not read; the hub may read it"


def _falsy(value):
    """PHP's empty-value test as the hub applies it: null, "", "0", false, 0
    and empty collections are all missing."""
    return not value or value == "0"


def app_layer(entry, sub_meta):
    """An app's merged Appverse layer: sub_meta overridden by entry, without
    `path`."""
    layer = dict(sub_meta or {})
    layer.update(entry or {})
    layer.pop("path", None)
    return layer


def _entries(root):
    """The root's apps[] entries by normalised path; the last duplicate wins,
    as in check_catalog."""
    out = {}
    for e in root.get("apps") or []:
        if isinstance(e, dict) and isinstance(e.get("path"), str) and e["path"].strip():
            out[os.path.normpath(e["path"].strip()).replace(os.sep, "/")] = e
    return out


def _rel(path, name):
    return name if path in (".", "") else path + "/" + name


def _undeclared(app, status, note):
    return {"app_id": app["app_id"], "status": status, "note": note, "fields": {},
            "missing": [], "software_missing": False}


def _entry_for(app, fields):
    values = {k: v["value"] for k, v in fields.items()}
    return {"app_id": app["app_id"], "status": "declared", "note": None, "fields": fields,
            "missing": [f for f in REQUIRED if _falsy(values.get(f))],
            "software_missing": _falsy(values.get("software"))}


def _fields(layer, sources, maintainer_source):
    """{field: {value, source}} from a resolved layer. sources maps a layer key
    to the file it came from. A maintainer field's source is the file its
    maintainer mapping came from, set even when that sub-field is empty, so a
    reader can tell an app's own partial maintainer from no maintainer."""
    fields = {}
    for f in FIELDS:
        if f.startswith("maintainer."):
            m = layer.get("maintainer")
            value = m.get(f.split(".", 1)[1]) if isinstance(m, dict) else None
            source = maintainer_source if m is not None else None
        else:
            value = layer.get(f)
            source = sources.get(f) if value is not None else None
        fields[f] = {"value": value, "source": source}
    return fields


def resolve(target, apps, load):
    """The metadata.json document for apps (resolve_apps' list). load(path,
    rel) returns (data, status, note), status one of ok, absent, unparsed or
    refused."""
    root, status, note = load(os.path.join(target, "appverse.yml"), "appverse.yml")
    if status == "absent":
        shape = "inferred"
    elif status == "refused":
        shape, note = "refused", REFUSED_NOTE
    elif status != "ok" or not isinstance(root, dict):
        shape = "unparsed"
        note = note or "appverse.yml is not a mapping"
    else:
        decl = root.get("apps")
        shape = "monorepo" if isinstance(decl, list) and decl else "single"

    root_maintainer = None
    if shape == "monorepo" and isinstance(root.get("maintainer"), dict):
        root_maintainer = {"name": root["maintainer"].get("name"),
                           "support_url": root["maintainer"].get("support_url")}

    out = []
    entries = _entries(root) if shape == "monorepo" else {}
    for app in apps:
        if app.get("_skip"):
            out.append(_undeclared(app, "skipped", app["_skip"]))
        elif shape in ("inferred", "unparsed", "refused"):
            out.append(_undeclared(app, shape, None if shape == "inferred" else note))
        elif shape == "single":
            layer = dict(root)
            if layer.get("name") is None and layer.get("title") is not None:
                layer["name"] = layer["title"]
            sources = {k: "appverse.yml" for k in layer}
            out.append(_entry_for(app, _fields(layer, sources, "appverse.yml")))
        else:
            out.append(_member(target, app, entries.get(app["path"]), root, load))
    return {"schema": SCHEMA, "shape": shape, "root_maintainer": root_maintainer, "apps": out}


def _member(target, app, entry, root, load):
    path = app["path"]
    sub_rel = _rel(path, "appverse.yml")
    sub, sub_status, _ = load(os.path.join(target, path, "appverse.yml"), sub_rel)
    if sub_status != "ok" or not isinstance(sub, dict):
        sub = {}
    layer = app_layer(entry, sub)
    sources = {k: sub_rel for k in sub}
    sources.update({k: "appverse.yml" for k in (entry or {})})
    maintainer_source = sources.get("maintainer")
    if layer.get("maintainer") is None and isinstance(root.get("maintainer"), dict):
        layer["maintainer"] = root["maintainer"]
        maintainer_source = "appverse.yml"
    missing_from_layer = [f for f in MANIFEST_FALLBACK if layer.get(f) is None]
    if missing_from_layer:
        man_rel = _rel(path, "manifest.yml")
        man, man_status, _ = load(os.path.join(target, path, "manifest.yml"), man_rel)
        if man_status == "ok" and isinstance(man, dict):
            for f in missing_from_layer:
                if man.get(f) is not None:
                    layer[f] = man[f]
                    sources[f] = man_rel
    return _entry_for(app, _fields(layer, sources, maintainer_source))
