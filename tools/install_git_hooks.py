import os
import shutil
import stat

HOOKS_DIR = ".git/hooks"
SOURCE_DIR = "tools/git-hooks"

def install_hook(name):
    src = os.path.join(SOURCE_DIR, name)
    dst = os.path.join(HOOKS_DIR, name)

    if not os.path.exists(src):
        print(f"Missing {src}")
        return

    shutil.copy(src, dst)

    try:
        st = os.stat(dst)
        os.chmod(dst, st.st_mode | stat.S_IEXEC)
    except Exception as e:
        print(f"chmod failed on {dst}: {e}")

    print(f"{name} installed.")

if not os.path.exists(HOOKS_DIR):
    print("ERROR: .git/hooks not found")
    exit(1)

install_hook("pre-commit")
install_hook("post-commit")

print("Git hooks installation complete.")
