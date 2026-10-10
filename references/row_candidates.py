"""The candidate rows a review must carry for each manifest check and app,
read from the pre-review facts. check-rows.py checks a report against them
and check-evidence.py checks their citations; both import them from here.
"""
import json
import os
import re

from repo_paths import parse_citations  # noqa: F401


class InputError(Exception):
    pass


SECURITY_KINDS = {
    "sec-interpolation": ("interpolation", "unquoted_expansion"),
    "sec-eval-exec": ("eval_exec",),
    "sec-credential-string": ("credential_string",),
    "sec-permissive-mode": ("permission_change",),
    "sec-network-call": ("network_call",),
    "sec-file-write-outside-job": ("file_write_outside_job",),
    "sec-config-flag": ("config_flag",),
    "sec-binary-in-template": ("binary_in_template",),
    "sec-tool-finding": ("tool_finding",),
}


TEMPLATE_KEYS = {
    "hardcoded-site-paths": ("absolute_paths",),
    "magic-numbers": ("numeric_literals", "hex_colors"),
    "dead-code": ("commented_code",),
    "icon-matches-target-os": ("icons",),
}


CONSTRAINED_WIDGETS = {"select", "radio_button", "radio", "check_box", "checkbox", "hidden_field"}


# sec-tool-finding: a candidate's label carries its code after the last ':',
# so a row's Evidence-citing answer can be checked separately for naming the
# code as a whole token in its Summary (the code-naming rule).
TOOL_FINDING_LABEL = "{site}:{code}"


def load_json(path, what):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        raise InputError("cannot read {} '{}': {}".format(what, path, e))


def fact(out, app_id, name):
    """A per-app fact file, or None when absent or unreadable."""
    path = os.path.join(out, name) if name == "syntax.json" else os.path.join(out, app_id, name)
    if not os.path.isfile(path):
        return None
    try:
        return load_json(path, name)
    except InputError:
        return None


def app_prefix(app):
    p = (app.get("path") or ".").strip().strip("/")
    p = p[2:] if p.startswith("./") else p
    return "" if p in ("", ".") else p + "/"


def paths_for(prefix, path):
    """Repo-relative first, then the path as written when it differs."""
    if prefix and not path.startswith(prefix):
        return [prefix + path, path]
    return [path]


def site(prefix, path, line):
    return [(p, line) for p in paths_for(prefix, path)]


def label(path, line):
    return path if line is None else "{}:{}".format(path, line)


def form_candidates(check_id, form, prefix):
    if not isinstance(form, dict) or form.get("error"):
        return []
    ffile = form.get("file") or "form.yml"
    sfile = form.get("submit_file") or "submit.yml.erb"
    out = []
    for a in form.get("attributes") or []:
        if not a.get("in_form", True) or a.get("defined") is False:
            continue
        cites = site(prefix, ffile, a.get("line"))
        if check_id == "numeric-field-bounds":
            if not a.get("reaches_scheduler"):
                continue
            widget = a.get("widget")
            # A floor (min, or required) is what input validation asks for.
            # A max is site policy and may come from site config, so a
            # missing max alone does not make a candidate.
            floor = a.get("min") is not None or a.get("required") is True
            if widget in CONSTRAINED_WIDGETS:
                continue
            if widget == "number_field":
                bounded = floor
            else:
                bounded = floor or a.get("pattern") is not None
            if bounded:
                continue
            out.append((label(cites[0][0], a.get("line")), cites, None))
        elif check_id == "erb-missing-value":
            if not a.get("interpolated_in_submit") or a.get("guarded") is True:
                continue
            lines = a.get("submit_lines") or []
            for n in lines:
                cites = cites + site(prefix, sfile, n)
            first = site(prefix, sfile, lines[0])[0] if lines else cites[0]
            out.append((label(*first), cites, None))
    return out


def candidates(check, app, out):
    """[(label, cites, rule)]: rule is the candidate's own rule when its fact
    carries one (security.json), else None (the check's rule applies)."""
    cid = check["id"]
    app_id = app["app_id"]
    prefix = app_prefix(app)
    found = []
    if cid == "str-06-syntax":
        for e in fact(out, app_id, "syntax.json") or []:
            p = e.get("path") or ""
            if e.get("ok") is False and p.startswith(prefix):
                found.append((p, [(p, None)], None))
    elif cid == "entry-point-parses":
        ep = fact(out, app_id, "entry_point.json")
        if isinstance(ep, dict) and ep.get("parses") is False and ep.get("file"):
            p = ep["file"]
            found.append((p, [(x, None) for x in paths_for(prefix, p)], None))
    elif cid == "sec-tool-finding":
        sec = fact(out, app_id, "security.json")
        for c in (sec.get("candidates") or []) if isinstance(sec, dict) else []:
            if c.get("kind") != "tool_finding":
                continue
            code = c.get("code")
            if c.get("file"):
                cites = [(p, n) for p, _ in site(prefix, c["file"], None) for n in (c.get("lines") or [])]
                site_label = label(paths_for(prefix, c["file"])[0], None)
            else:
                cites, sites_seen = [], []
                for entry in c.get("lines") or []:
                    path, _, tail = str(entry).rpartition(":")
                    if path and tail.isdigit():
                        cites.extend(site(prefix, path, int(tail)))
                        sites_seen.append(path)
                site_label = ",".join(sites_seen) or "?"
            found.append((TOOL_FINDING_LABEL.format(site=site_label, code=code), cites, None))
    elif cid in SECURITY_KINDS:
        sec = fact(out, app_id, "security.json")
        for c in (sec.get("candidates") or []) if isinstance(sec, dict) else []:
            if c.get("kind") in SECURITY_KINDS[cid] and c.get("file"):
                cites = site(prefix, c["file"], c.get("line"))
                found.append((label(cites[0][0], c.get("line")), cites, c.get("rule")))
    elif cid in TEMPLATE_KEYS:
        tpl = fact(out, app_id, "template.json")
        if isinstance(tpl, dict):
            for key in TEMPLATE_KEYS[cid]:
                for c in tpl.get(key) or []:
                    if c.get("file"):
                        cites = site(prefix, c["file"], c.get("line"))
                        found.append((label(cites[0][0], c.get("line")), cites, None))
    elif cid in ("numeric-field-bounds", "erb-missing-value"):
        found = form_candidates(cid, fact(out, app_id, "form.json"), prefix)
    seen, unique = set(), []
    for lab, cites, rule in found:
        if lab not in seen:
            seen.add(lab)
            unique.append((lab, cites, rule))
    return unique
