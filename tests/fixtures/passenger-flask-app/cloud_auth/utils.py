import os


def create_private_dir(path):
    os.makedirs(path, mode=0o700, exist_ok=True)


def format_errors(errors=[]):
    if not errors:
        return ""
    return "\n".join(f"ERROR: {e}" for e in errors)
