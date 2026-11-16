"""Serves the site news list that form.js shows on the form."""
import json
import subprocess

from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)


@app.route("/api/latest")
def latest():
    out = subprocess.run("cat /var/www/news/*.json", shell=True, capture_output=True, text=True)
    return jsonify(items=[json.loads(line) for line in out.stdout.splitlines() if line])


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8443)
