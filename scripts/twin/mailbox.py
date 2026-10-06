#!/usr/bin/env python3
# The assistant's own mailbox over IMAP. Read-only apart from the \Seen flag.
# Usage: python3 scripts/twin/mailbox.py list            -> unread messages (uid | date | from | subject)
#        python3 scripts/twin/mailbox.py read <uid> [dir] -> headers + plain text; marks it read;
#                                                           with [dir] also saves the attachments there
#        python3 scripts/twin/mailbox.py new             -> uids that arrived since the last `new` (first call only records)
#        python3 scripts/twin/mailbox.py wake <uid>...   -> those uids that must wake the twin: replies to the
#                                                           assistant's sent mail, mail from the owner, or from
#                                                           an address in scripts/twin/mail-watchlist.txt
# Env: MAIL_SERVER, MAIL_LOGIN, MAIL_PASS, OWNER_EMAIL
import email, imaplib, os, re, sys
from email.header import decode_header, make_header
from email.utils import parseaddr
from env import ROOT, RUNS  # loads .env

def h(v): return str(make_header(decode_header(v or "")))

m = imaplib.IMAP4_SSL(os.environ["MAIL_SERVER"], 993, timeout=30)
m.login(os.environ["MAIL_LOGIN"], os.environ["MAIL_PASS"])
m.select("INBOX")

if sys.argv[1] == "new":
    # Tracks the highest uid seen in a file, so mail the owner already opened elsewhere still counts as new.
    state = os.path.join(RUNS, "mailbox-lastuid")
    uids = [int(u) for u in m.uid("search", None, "ALL")[1][0].split()]
    last = int(open(state).read()) if os.path.exists(state) else None
    if last is not None:
        for u in uids:
            if u > last: print(u)
    if uids: open(state, "w").write(str(max(uids + [last or 0])))
elif sys.argv[1] == "wake":
    def ids(v): return set(re.findall(r"<[^>]+>", v or ""))
    watch = {os.environ.get("OWNER_EMAIL", "").lower()}
    wl = os.path.join(ROOT, "scripts/twin/mail-watchlist.txt")
    if os.path.exists(wl):
        watch |= {l.strip().lower() for l in open(wl) if l.strip() and not l.startswith("#")}
    msgs = {u: email.message_from_bytes(m.uid("fetch", u, "(BODY.PEEK[HEADER.FIELDS (FROM IN-REPLY-TO REFERENCES)])")[1][0][1])
            for u in sys.argv[2:]}
    m.select("Sent", readonly=True)
    sent = set()
    for u in m.uid("search", None, "ALL")[1][0].split():
        sent |= ids(email.message_from_bytes(m.uid("fetch", u, "(BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])")[1][0][1])["Message-ID"])
    for u, msg in msgs.items():
        sender = parseaddr(msg["From"] or "")[1].lower()
        if (ids(msg["In-Reply-To"]) | ids(msg["References"])) & sent or sender in watch or sender.split("@")[-1] in watch:
            print(u)
elif sys.argv[1] == "list":
    uids = m.uid("search", None, "UNSEEN")[1][0].split()
    for u in uids:
        msg = email.message_from_bytes(m.uid("fetch", u, "(BODY.PEEK[HEADER])")[1][0][1])
        print(f"{u.decode()} | {msg['Date']} | {h(msg['From'])} | {h(msg['Subject'])}")
    if not uids: print("(no unread mail)")
elif sys.argv[1] == "read":
    msg = email.message_from_bytes(m.uid("fetch", sys.argv[2], "(BODY[])")[1][0][1])
    for k in ("From", "To", "Cc", "Date", "Subject", "Message-ID", "In-Reply-To", "References"):
        if msg[k]: print(f"{k}: {h(msg[k])}")
    print()
    text = html = None
    outdir = sys.argv[3] if len(sys.argv) > 3 else None
    if outdir: os.makedirs(outdir, exist_ok=True)
    for part in msg.walk():
        # Apple Mail sends dragged-in files as inline parts with a filename; treat those as attachments too.
        if part.get_content_disposition() == "attachment" or (part.get_filename() and part.get_content_maintype() != "text"):
            name = os.path.basename(h(part.get_filename()) or "attachment")
            if outdir:
                path = os.path.join(outdir, name)
                with open(path, "wb") as f: f.write(part.get_payload(decode=True))
                print(f"[attachment: {name} -> {path}]")
            else:
                print(f"[attachment: {name}]")
            continue
        ct = part.get_content_type()
        if ct in ("text/plain", "text/html"):
            body = part.get_payload(decode=True).decode(part.get_content_charset() or "utf-8", "replace")
            if ct == "text/plain" and text is None: text = body
            if ct == "text/html" and html is None: html = body
    print(text if text is not None else re.sub(r"<[^>]+>", "", html or ""))
m.logout()
