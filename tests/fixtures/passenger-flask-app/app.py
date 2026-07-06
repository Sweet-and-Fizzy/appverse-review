import os
import subprocess
import json
from flask import Flask, request, jsonify, render_template_string
from cloud_auth.utils import create_private_dir, format_errors

app = Flask(__name__)

SLURM_BIN = "/opt/slurm/21.08/bin"
MAIL_RELAY = "smtp.internal.cluster.edu"
TOKEN_DIR = f"/tmp/{os.environ.get('USER', 'nobody')}"

@app.before_request
def check_auth():
    if not os.environ.get("REMOTE_USER"):
        return jsonify(error="Not authenticated"), 401


@app.route("/")
def index():
    return render_template_string(INDEX_HTML)


@app.route("/jobs")
def list_jobs():
    user = os.environ.get("REMOTE_USER", "")
    output = subprocess.check_output(
        f"{SLURM_BIN}/squeue -u {user} --json",
        shell=True
    )
    return jsonify(json.loads(output))


@app.route("/job/<job_id>/cancel", methods=["POST"])
def cancel_job(job_id):
    result = subprocess.run(
        f"{SLURM_BIN}/scancel {job_id}",
        shell=True, capture_output=True, text=True
    )
    if result.returncode != 0:
        return jsonify(error=result.stderr), 400
    return jsonify(status="cancelled")


@app.route("/job/<job_id>/detail")
def job_detail(job_id):
    output = subprocess.check_output(
        [f"{SLURM_BIN}/scontrol", "show", "job", job_id]
    )
    return output.decode()


@app.route("/alerts", methods=["POST"])
def set_alert():
    data = request.json
    job_id = data.get("job_id", "")
    email = data.get("email", "")
    script = f"""#!/bin/bash
JOB_STATE=$({SLURM_BIN}/squeue -j {job_id} -h -o %T 2>/dev/null)
if [ "$JOB_STATE" != "RUNNING" ] && [ "$JOB_STATE" != "PENDING" ]; then
    echo "Job {job_id} finished" | mail -s "Job Alert" -S smtp={MAIL_RELAY} {email}
fi
"""
    token_file = os.path.join(TOKEN_DIR, f"alert_{job_id}.sh")
    create_private_dir(TOKEN_DIR)
    with open(token_file, "w") as f:
        f.write(script)
    os.chmod(token_file, 0o700)
    subprocess.Popen(
        f"while true; do bash {token_file} && break; sleep 60; done &",
        shell=True
    )
    return jsonify(status="alert set")


@app.route("/history")
def job_history():
    user = os.environ.get("REMOTE_USER", "")
    days = request.args.get("days", "30")
    output = subprocess.check_output(
        f"{SLURM_BIN}/sacct -u {user} -S now-{days}days --json",
        shell=True
    )
    return jsonify(json.loads(output))


INDEX_HTML = """
<!doctype html>
<html>
<head><title>Job Monitor</title></head>
<body>
<h1>HPC Job Monitor</h1>
<div id="jobs"></div>
<script>
fetch('/jobs').then(r => r.json()).then(data => {
    document.getElementById('jobs').innerHTML =
        '<pre>' + JSON.stringify(data, null, 2) + '</pre>';
});
</script>
</body>
</html>
"""
