#!/usr/bin/env python3
"""Send a mail from the assistant's own mailbox, always with the owner in Cc.

Usage: send-mail.py --to a@x.com[,b@y.com] [--cc c@z.com] --subject "..." --body-file path.txt [--attach file ...]
                    [--wait "what we asked → what to do on reply" [--due YYYY-MM-DD]] [--in-reply-to "<Message-ID>"]
Run only after the owner approved the exact text (tier 1).
--wait adds a row with the Message-ID to wiki/topics/waiting-for.md, so the twin knows what to do when the answer comes.
Env: MAIL_SERVER, MAIL_LOGIN, MAIL_PASS, MAIL_FROM ("Name <address>"), OWNER_EMAIL
"""
import argparse, imaplib, mimetypes, os, smtplib, sys, time
from email.message import EmailMessage
from email.utils import formatdate, make_msgid, parseaddr
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "twin"))
from env import ROOT  # loads .env

p = argparse.ArgumentParser()
p.add_argument("--to", required=True)
p.add_argument("--cc", default="")
p.add_argument("--subject", required=True)
p.add_argument("--body-file", required=True)
p.add_argument("--attach", action="append", default=[])
p.add_argument("--wait", default="")
p.add_argument("--due", default="")
p.add_argument("--in-reply-to", default="", help="Message-ID of the mail being answered (threads the reply)")
a = p.parse_args()

host, user, pw = os.environ["MAIL_SERVER"], os.environ["MAIL_LOGIN"], os.environ["MAIL_PASS"]
owner = os.environ["OWNER_EMAIL"]
to = [t.strip() for t in a.to.split(",") if t.strip()]
cc = [c.strip() for c in a.cc.split(",") if c.strip()]
if owner not in to + cc:
    cc.append(owner)

m = EmailMessage()
m["From"] = os.environ["MAIL_FROM"]
m["To"] = ", ".join(to)
if cc: m["Cc"] = ", ".join(cc)
m["Subject"] = a.subject
m["Date"] = formatdate(localtime=True)
m["Message-ID"] = make_msgid(domain=parseaddr(os.environ["MAIL_FROM"])[1].split("@")[-1])
if a.in_reply_to:
    m["In-Reply-To"] = a.in_reply_to
    m["References"] = a.in_reply_to
m.set_content(Path(a.body_file).read_text())
for f in map(Path, a.attach):
    maintype, subtype = (mimetypes.guess_type(f.name)[0] or "application/octet-stream").split("/")
    m.add_attachment(f.read_bytes(), maintype=maintype, subtype=subtype, filename=f.name)

with smtplib.SMTP(host, 587, timeout=30) as s:
    s.starttls()
    s.login(user, pw)
    print("refused:", s.send_message(m))
print("Message-ID:", m["Message-ID"])

if a.wait:
    wf = Path(ROOT) / "wiki/topics/waiting-for.md"
    row = f"- [ ] {a.due or 'no due'} · {m['To']} · {a.subject} · {a.wait} · sent {time.strftime('%F')} · `{m['Message-ID']}`\n"
    wf.write_text(wf.read_text().replace("## Open\n", "## Open\n" + row, 1))
    print("waiting-for row added")

try:
    i = imaplib.IMAP4_SSL(host)
    i.login(user, pw)
    r = i.append("Sent", "\\Seen", imaplib.Time2Internaldate(time.time()), m.as_bytes())
    print("saved to Sent" if r[0] == "OK" else f"sent copy not saved: {r}")
    i.logout()
except Exception as e:
    print("sent copy not saved:", e)
