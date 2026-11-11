# Generates schedule.ics: recurring classes, upper week = week of 2026-11-09.
import json, datetime as dt, pathlib
here = pathlib.Path(__file__).parent
D = json.loads((here / "data.json").read_text(encoding="utf-8"))
UPPER_MONDAY = dt.date(2026, 11, 9)
UNTIL = "20261231T235959Z"
L = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//study-schedule//RU", "CALSCALE:GREGORIAN",
     "X-WR-CALNAME:Пары", "X-WR-TIMEZONE:Asia/Chita",
     "BEGIN:VTIMEZONE", "TZID:Asia/Chita", "BEGIN:STANDARD", "DTSTART:19700101T000000",
     "TZOFFSETFROM:+0900", "TZOFFSETTO:+0900", "TZNAME:+09", "END:STANDARD", "END:VTIMEZONE"]
stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
def esc(s): return s.replace("\\", "\\\\").replace(",", "\\,").replace(";", "\\;")
for i, l in enumerate(D["lessons"]):
    full, short, teacher = D["subjects"][l["s"]]
    both = l["w"] == "вн"
    monday = UPPER_MONDAY if (both or l["w"] == "в") else UPPER_MONDAY + dt.timedelta(days=7)
    day = monday + dt.timedelta(days=l["day"] - 1)
    a, b = D["times"][str(l["n"])]
    f = lambda t: day.strftime("%Y%m%d") + "T" + t.replace(":", "") + "00"
    kind = "Лек" if l["t"] == "лекция" else "Пр"
    week = "каждую неделю" if both else ("верхняя неделя" if l["w"] == "в" else "нижняя неделя")
    L += ["BEGIN:VEVENT", f"UID:lesson-{i}@study-schedule", f"DTSTAMP:{stamp}",
          f"DTSTART;TZID=Asia/Chita:{f(a)}", f"DTEND;TZID=Asia/Chita:{f(b)}",
          f"RRULE:FREQ=WEEKLY;INTERVAL={1 if both else 2};UNTIL={UNTIL}",
          f"SUMMARY:{esc(l['r'] + ' · ' + short + ' (' + kind + ')')}",
          f"LOCATION:{esc('Ауд. ' + l['r'])}",
          f"DESCRIPTION:{esc(full + ' — ' + l['t'] + '. ' + teacher + ' ' + str(l['n']) + ' пара, ' + week + '.')}",
          "BEGIN:VALARM", "ACTION:DISPLAY", f"DESCRIPTION:{esc(short + ' — ауд. ' + l['r'])}",
          "TRIGGER:-PT10M", "END:VALARM", "END:VEVENT"]
L.append("END:VCALENDAR")
(here / "schedule.ics").write_bytes(("\r\n".join(L) + "\r\n").encode("utf-8"))
print(len(D["lessons"]), "events")
