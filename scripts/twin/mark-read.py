#!/usr/bin/env python3
"""Mark an answered mail as read, so it does not stay unread in the owner's mail app.
Usage: python3 scripts/twin/mark-read.py "<Message-ID>"
Sets \\Seen on that Message-ID in INBOX of the assistant's mailbox (MAIL_*) and of every box in scripts/twin/mailboxes.txt.
send-mail.py calls it after a reply goes out.
"""
import imaplib, os, sys
from env import ROOT  # loads .env

mid = sys.argv[1].strip()
boxes = ["MAIL"]
if os.path.exists(os.path.join(ROOT, "scripts/twin/mailboxes.txt")):
    boxes += [l.split()[0] for l in open(os.path.join(ROOT, "scripts/twin/mailboxes.txt")) if l.strip() and not l.startswith("#")]

for b in boxes:
    try:
        m = imaplib.IMAP4_SSL(os.environ[b + "_SERVER"], 993, timeout=30)
        m.login(os.environ[b + "_LOGIN"], os.environ[b + "_PASS"])
        m.select("INBOX")
        for u in m.uid("search", None, "HEADER", "Message-ID", f'"{mid}"')[1][0].split():
            m.uid("store", u, "+FLAGS", "(\\Seen)")
            print(f"marked read: {b} uid {u.decode()}")
        m.logout()
    except Exception as e:  # one box with stale creds must not stop the others
        print(f"mailbox {b}: {e}", file=sys.stderr)
