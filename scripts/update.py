#!/usr/bin/env python3
"""Update this claudeOS copy to a newer template version, keeping the owner's data and edits.

  python3 scripts/update.py --check         is there a newer version? (prints what changed since yours)
  python3 scripts/update.py                 update to the newest version
  python3 scripts/update.py --ref <branch>  update to a branch of the template (for testing)

Data folders (wiki/, raw/, staging/, .obsidian/) and files the template does not have are never changed;
the template may only add files there that are new and missing. Every other template file is merged three
ways (template at your version, template at the new version, your file), so your own edits stay. A conflict
is left in the file with markers and the script exits 2; otherwise the update is one commit (undo: git revert).
Needs .claudeos/profile (USER_NAME=, ASSISTANT_NAME=, DATE=): the values the first-time setup put in
place of {{USER_NAME}}, {{ASSISTANT_NAME}} and {{DATE}}.
"""
import os
import subprocess
import sys
import tempfile

TEMPLATE = os.environ.get("CLAUDEOS_TEMPLATE", "https://github.com/pdovhomilja/claudeos-template.git")
DATA = ("wiki/", "raw/", "staging/", ".obsidian/")


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, check=True).stdout


def tree(ref):   # {path: (mode, blob)}
    files = {}
    for line in git("ls-tree", "-r", "-z", ref).split(b"\0"):
        if line:
            meta, path = line.split(b"\t", 1)
            mode, _, blob = meta.split()
            files[path.decode()] = (mode.decode(), blob.decode())
    return files


def version_of(ref):
    try:
        return git("show", f"{ref}:VERSION").decode().strip()
    except subprocess.CalledProcessError:
        return "0 (before versioning)"


def guess_base():   # copies made before VERSION existed: the template commit they were created from
    root = tree(git("rev-list", "--max-parents=0", "HEAD").split()[-1].decode())
    best, score = None, -1
    for commit in git("rev-list", "refs/claudeos/main").decode().split():
        same = len(set(tree(commit).items()) & set(root.items()))
        if same > score:
            best, score = commit, same
    return best


def read(path):
    try:
        with open(path, "rb") as f:
            return f.read()
    except FileNotFoundError:
        return None


def write(path, data, mode):
    if os.path.dirname(path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    os.chmod(path, 0o755 if mode == "100755" else 0o644)


def merge(local, base, new, labels):
    with tempfile.TemporaryDirectory() as tmp:
        names = []
        for name, data in (("local", local), ("base", base), ("new", new)):
            names.append(os.path.join(tmp, name))
            with open(names[-1], "wb") as f:
                f.write(data)
        r = subprocess.run(["git", "merge-file", "-p", "-L", labels[0], "-L", labels[1], "-L", labels[2], *names],
                           capture_output=True)
    if r.returncode > 127:
        raise SystemExit(f"git merge-file failed: {r.stderr.decode()}")
    return r.stdout, r.returncode


def main():
    args = sys.argv[1:]
    check = "--check" in args
    ref = args[args.index("--ref") + 1] if "--ref" in args else None
    os.chdir(git("rev-parse", "--show-toplevel").decode().strip())

    specs = ["+refs/tags/v*:refs/claudeos/tags/v*", "+refs/heads/main:refs/claudeos/main"]
    if ref:
        specs.append(f"+refs/heads/{ref}:refs/claudeos/ref")
    git("fetch", "-q", "--no-tags", TEMPLATE, *specs)
    tags = git("for-each-ref", "--format=%(refname:lstrip=3)", "refs/claudeos/tags").decode().split()
    tags.sort(key=lambda t: tuple(int(x) for x in t[1:].split(".")))
    if ref:
        new = "refs/claudeos/ref"
    elif tags:
        new = f"refs/claudeos/tags/{tags[-1]}"
    else:
        raise SystemExit("The template has no released version yet.")
    mine = read("VERSION")
    mine = mine.decode().strip() if mine else None
    base = f"refs/claudeos/tags/v{mine}" if mine and f"v{mine}" in tags else guess_base()
    mine, newest = mine or version_of(base), version_of(new)

    if tree(base) == tree(new):
        print(f"Up to date (version {mine}).")
        return
    if check:
        print(f"Installed: {mine}. Newest: {newest}.\n")
        sections = git("show", f"{new}:CHANGELOG.md").decode().split("\n## ")[1:]
        for section in sections:
            if section.startswith(f"{mine} "):
                break
            print("## " + section.strip() + "\n")
        return

    if git("status", "--porcelain", "--untracked-files=no"):
        raise SystemExit("There are uncommitted changes. Commit them first, then run the update again.")
    profile = {}
    for line in (read(".claudeos/profile") or b"").decode().splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            profile[key.strip()] = value.strip()
    missing = [k for k in ("USER_NAME", "ASSISTANT_NAME", "DATE") if not profile.get(k)]
    if missing:
        raise SystemExit(f".claudeos/profile is missing {', '.join(missing)} (see the update skill).")

    def render(r, path):
        data = git("show", f"{r}:{path}")
        if b"\0" not in data:
            for key, value in profile.items():
                data = data.replace(b"{{" + key.encode() + b"}}", value.encode())
        return data

    labels = ("yours", f"template {mine}", f"template {newest}")
    old_files, new_files = tree(base), tree(new)
    changed, conflicts, notes = [], [], []
    for path in sorted(set(old_files) | set(new_files)):
        b, n = old_files.get(path), new_files.get(path)
        if b == n:
            continue
        local = read(path)
        if path.startswith(DATA):
            if n and not b and local is None:
                write(path, render(new, path), n[0])
                changed.append(path)
            continue
        old_text = render(base, path) if b else b""
        new_text = render(new, path) if n else None
        if local == new_text:
            continue
        if not n:   # removed from the template
            if local is None:
                continue
            if local == old_text:
                os.remove(path)
                changed.append(path)
            else:
                notes.append(f"{path}: no longer in the template; kept because it was changed here")
        elif local is None:
            if b:
                notes.append(f"{path}: deleted here earlier; not brought back")
            else:
                write(path, new_text, n[0])
                changed.append(path)
        elif local == old_text:
            write(path, new_text, n[0])
            changed.append(path)
        elif b"\0" in local or b"\0" in new_text:
            write(path + ".new", new_text, n[0])
            conflicts.append(f"{path} (binary; the template's new version is {path}.new)")
        else:
            merged, n_conflicts = merge(local, old_text, new_text, labels)
            write(path, merged, n[0])
            changed.append(path)
            if n_conflicts:
                conflicts.append(path)

    if changed:
        git("add", "-A", "--", *changed)
    for note in notes:
        print(note)
    if conflicts:
        print(f"\nUpdate {mine} → {newest} needs a decision in these files (markers <<<<<<< yours … >>>>>>>):")
        for path in conflicts:
            print(f"  {path}")
        print(f'Resolve them, then: git add -A && git commit -m "claudeOS update {mine} → {newest}"')
        sys.exit(2)
    if not changed:
        print(f"Nothing to change; this copy already matches {newest}.")
        return
    git("commit", "-q", "-m", f"claudeOS update {mine} → {newest}")
    print(f"Updated {mine} → {newest} ({len(changed)} files). Undo: git revert HEAD")


main()
