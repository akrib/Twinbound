import json
import subprocess
from datetime import datetime
import os

OUTPUT_PATH = "documentation/build_info.json"


def git_command(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        return "unknown"


def main():
    print("Exporting debug build info...")

    info = {
        "build_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "git_commit": git_command(["git", "rev-parse", "--short", "HEAD"]),
        "git_branch": git_command(["git", "rev-parse", "--abbrev-ref", "HEAD"]),
        "git_dirty": bool(git_command(["git", "status", "--porcelain"])),
        "game_version": read_game_version()
    }

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(info, f, indent=2)

    print(f"Debug info written to {OUTPUT_PATH}")
    print(json.dumps(info, indent=2))


def read_game_version():
    # OPTION SIMPLE : version globale dans un fichier texte
    path = "VERSION.txt"
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    return "0.0.0"


if __name__ == "__main__":
    main()
