import socket
import re
import sys
import time
import requests
import io
import os
from datetime import datetime

# ═══════════════════════════════════════════════
# CONFIGURATION DU SITE
# ═══════════════════════════════════════════════
SITE_NAME = "EXT OFICINA"
SITE_ID = "SITE01"
DEFAULT_HOST = "192.168.20.214"
DEFAULT_PORT = 9922

# ═══════════════════════════════════════════════
# CONFIGURATION COMMUNE
# ═══════════════════════════════════════════════
DEFAULT_SCRIPT_URL = "https://script.google.com/macros/s/AKfycbx5ZB99TMumMSxC-PPhHMwTv8CR9wxglhq9esns5x75-oFyPAcdHF2CK5NqzPq-8zMB/exec"
CHECK_URL = "https://script.google.com/macros/s/AKfycbwBuyGdeuehHdLJdBmLhJbbCbRhVbBKN0PVIu9ok3S64tiC3yjsIVhkrU4aDNwfraa8/exec"

TELEGRAM_BOT_TOKEN = "7561853556:AAElzI6FYzNb6yNUV6EA_Bnzkec2hUrcP70"
TELEGRAM_CHAT_IDS = [
    "-1003727722771",
    "-1003807821636",
]

IP = DEFAULT_HOST
PORT = DEFAULT_PORT

LOG_FILE = os.path.expanduser("~/sync_log.txt")

def log(msg):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}"
    print(line, flush=True)
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
        if os.path.getsize(LOG_FILE) > 1_000_000:
            with open(LOG_FILE, "r", encoding="utf-8") as f:
                lines = f.readlines()
            with open(LOG_FILE, "w", encoding="utf-8") as f:
                f.writelines(lines[-500:])
    except Exception:
        pass

def is_internet_available():
    try:
        requests.get("https://www.google.com", timeout=5)
        return True
    except Exception:
        return False

def is_hanvon_reachable():
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(3)
            s.connect((IP, PORT))
        return True
    except Exception:
        return False

def check_control_cell():
    try:
        response = requests.get(CHECK_URL, timeout=15)
        value = response.text.strip()
        log(f"Valeur de B1 : '{value}'")
        return value == "1"
    except Exception as e:
        log(f"Echec lecture cellule : {e}")
        return False

def reset_control_cell():
    try:
        separator = "&" if "?" in CHECK_URL else "?"
        reset_url = f"{CHECK_URL}{separator}action=reset"
        response = requests.get(reset_url, timeout=15)
        response_text = response.text.strip()
        log(f"Reponse reset : '{response_text}'")
        return "success" in response_text.lower()
    except Exception as e:
        log(f"Echec reset : {e}")
        return False

def clear_device_records():
    log("Nettoyage Hanvon (DeleteAllRecord)...")
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(15)
            s.connect((IP, PORT))
            s.sendall(b"DeleteAllRecord()\r\n")
            data = b""
            while True:
                try:
                    chunk = s.recv(4096)
                    if not chunk:
                        break
                    data += chunk
                    if b'result=' in data:
                        break
                except socket.timeout:
                    break
            response_text = data.decode('utf-8', errors='replace')
            if 'result="success"' in response_text:
                log("Appareil nettoye avec succes.")
                return True
            else:
                log(f"Echec nettoyage : {response_text}")
                return False
    except Exception as e:
        log(f"Erreur nettoyage : {e}")
        return False

def get_all_records():
    log(f"Recuperation depuis {IP}:{PORT}...")
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(60)
            s.connect((IP, PORT))
            s.sendall(b"GetRecord()\r\n")
            raw_data = b""
            while True:
                try:
                    chunk = s.recv(16384)
                    if not chunk:
                        break
                    raw_data += chunk
                    if b'result="success"' in raw_data and raw_data.strip().endswith(b')'):
                        break
                except socket.timeout:
                    break

        text = raw_data.decode('utf-8', errors='replace')
        if 'result="success"' not in text:
            log("Echec recuperation donnees.")
            return []

        total_match = re.search(r'total="(\d+)"', text)
        total = total_match.group(1) if total_match else "?"
        log(f"Total enregistrements : {total}")

        pattern = r'time="([^"]+)"\s+id="([^"]+)"\s+name="([^"]*)"\s+workcode="([^"]*)"\s+status="([^"]*)"\s+authority="([^"]*)"\s+card_src="([^"]*)"'
        records = re.findall(pattern, text)
        log(f"{len(records)} enregistrements extraits")
        return records
    except Exception as e:
        log(f"Erreur recuperation : {e}")
        return []

def records_to_dicts(records):
    return [
        {
            "site_id": SITE_ID,
            "site_name": SITE_NAME,
            "time": r[0], "id": r[1], "name": r[2],
            "workcode": r[3], "status": r[4],
            "authority": r[5], "card_src": r[6],
        }
        for r in records
    ]

def send_to_google_script(script_url, records):
    if not records:
        return "Aucun enregistrement a envoyer."
    payload = records_to_dicts(records)
    try:
        response = requests.post(
            script_url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=120
        )
        return f"OK Envoi Google : {response.status_code}"
    except Exception as e:
        return f"Echec Google Script : {e}"

def send_to_telegram(records, filename):
    if not records:
        return "Aucun enregistrement."
    try:
        buffer = io.StringIO()
        for r in records:
            dt = datetime.strptime(r[0], "%Y-%m-%d %H:%M:%S")
            buffer.write(f"{r[1]};{dt.day};{dt.month};{dt.year};{dt.hour};{dt.minute};{dt.second}\n")
        content = buffer.getvalue()

        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendDocument"
        results = []
        for chat_id in TELEGRAM_CHAT_IDS:
            files = {'document': (filename, content)}
            data = {'chat_id': chat_id, 'caption': f"{SITE_NAME} ({SITE_ID})"}
            response = requests.post(url, data=data, files=files, timeout=30)
            if response.status_code == 200:
                results.append(f"OK Telegram {chat_id}")
            else:
                results.append(f"Echec {chat_id}")
        return " | ".join(results)
    except Exception as e:
        return f"Erreur Telegram : {e}"

def run_task():
    if not is_hanvon_reachable():
        log(f"Hanvon ({IP}:{PORT}) injoignable. Tache annulee.")
        return

    records = get_all_records()
    if not records:
        log("Aucun enregistrement a traiter.")
        reset_control_cell()
        return

    now = datetime.now()
    filename = f"{SITE_NAME} {now.day}-{now.month}-{now.year}. {now.strftime('%H:%M')}.txt"

    result_tg = send_to_telegram(records, filename)
    log(result_tg)
    telegram_success = "OK" in result_tg

    result_google = send_to_google_script(DEFAULT_SCRIPT_URL, records)
    log(result_google)
    google_success = "OK" in result_google

    reset_success = reset_control_cell()

    if telegram_success and google_success and reset_success:
        log("Toutes les etapes OK. Nettoyage de l'appareil...")
        clear_device_records()
    else:
        log("Nettoyage saute (une etape a echoue).")

if __name__ == "__main__":
    log("=" * 60)
    log(f"Demarrage - Site: {SITE_NAME} ({SITE_ID})")
    log(f"Appareil : {IP}:{PORT}")
    log("=" * 60)

    while True:
        try:
            if not is_internet_available():
                log("Pas d'Internet. Nouvelle tentative dans 60s.")
                time.sleep(60)
                continue

            if check_control_cell():
                log("B1 = 1 -> Lancement des taches")
                run_task()
            else:
                log("B1 = 0 -> En attente...")

            time.sleep(60)
        except KeyboardInterrupt:
            log("Arret manuel du script.")
            break
        except Exception as e:
            log(f"Erreur inattendue : {e}")
            time.sleep(60)
