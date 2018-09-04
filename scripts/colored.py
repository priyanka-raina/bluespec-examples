import re
import os

info = re.compile(r'\b(info)\b', flags=re.I)
warn = re.compile(r'\b(warning)\b', flags=re.I)
error = re.compile(r'\b(error)\b', flags=re.I)
critical = re.compile(r'\b(critical)\b', flags=re.I)

def colorize(message):
    a = info.sub('\033[32m\\1\033[39m', message)
    a = warn.sub('\033[34m\\1\033[39m', a)
    a = error.sub('\033[31m\\1\033[39m', a)
    a = critical.sub('\033[33m\\1\033[39m', a)
    return a

def main(msg_queue, stream):
    msgfile = os.fdopen(msg_queue.fileno(), 'r', 0)
    while True:
        line = msgfile.readline()
        if line is None: break
        stream.write(colorize(line))
        stream.flush()
