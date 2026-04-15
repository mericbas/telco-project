import csv
import os
import sys

try:
    import oracledb
except ImportError:
    print("Hata: 'oracledb' paketi bulunamadi.")
    print("Lutfen once kurun: pip install oracledb")
    sys.exit(1)

# ── Baglanti ayarlari ────────────────────────────────────────────────────────
DB_HOST     = "localhost"
DB_PORT     = 1521
DB_SERVICE  = "TELCODB"
DB_USER     = "TELCO_USER"
DB_PASSWORD = "Telco2026!"

DSN = f"{DB_HOST}:{DB_PORT}/{DB_SERVICE}"

# ── CSV dosya yolu ───────────────────────────────────────────────────────────
CSV_FILE = os.path.join("data", "MONTHLY_STATS.csv")

# ── SQL ─────────────────────────────────────────────────────────────────────
INSERT_SQL = """
    INSERT INTO MONTHLY_STATS
        (STAT_ID, CUSTOMER_ID, DATA_USAGE, MINUTE_USAGE, SMS_USAGE, PAYMENT_STATUS)
    VALUES
        (:1, :2, :3, :4, :5, :6)
"""


def parse_row(row: list) -> tuple:
    """
    Ham CSV satirini (6 veya 7 alan) islenir ve tuple olarak dondurur.

    MONTHLY_STATS.csv sutun sirasi:
        STAT_ID, CUSTOMER_ID, DATA_USAGE, MINUTE_USAGE, SMS_USAGE, PAYMENT_STATUS

    DATA_USAGE Avrupa ondaligi iceriyorsa (ornek: 18420,61) CSV okuyucu
    bunu iki ayri alan olarak gorur ve satirda 7 alan olusur.
    Bu durumda alan [2] ve alan [3] birlestirilerek gercek deger elde edilir.
    """
    if len(row) == 7:
        # Ornek: ['1', '100', '18420', '61', '500', '200', 'PAID']
        stat_id        = int(row[0])
        customer_id    = int(row[1])
        data_usage     = float(f"{row[2]}.{row[3]}")   # 18420.61
        minute_usage   = int(row[4])
        sms_usage      = int(row[5])
        payment_status = row[6].strip()
    elif len(row) == 6:
        # Ornek: ['1', '100', '18420.61', '500', '200', 'PAID']
        stat_id        = int(row[0])
        customer_id    = int(row[1])
        data_usage     = float(row[2].replace(',', '.'))
        minute_usage   = int(row[3])
        sms_usage      = int(row[4])
        payment_status = row[5].strip()
    else:
        raise ValueError(
            f"Beklenmedik alan sayisi: {len(row)} | icerik: {row}"
        )

    return (stat_id, customer_id, data_usage, minute_usage, sms_usage, payment_status)


def main() -> None:
    # 1. CSV dosyasinin varligini kontrol et
    if not os.path.exists(CSV_FILE):
        print(f"Hata: '{CSV_FILE}' dosyasi bulunamadi.")
        print("Lutfen scripti proje ana dizininden calistirin.")
        sys.exit(1)

    # 2. CSV'yi oku ve satirlari isle
    print(f"[1/3] {CSV_FILE} okunuyor...")
    rows   = []
    errors = []

    with open(CSV_FILE, "r", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader)           # baslik satirini atla
        print(f"      Baslik: {header}")

        for line_num, raw_row in enumerate(reader, start=2):
            try:
                rows.append(parse_row(raw_row))
            except Exception as exc:
                errors.append((line_num, exc, raw_row))

    print(f"      Islenecek: {len(rows)} satir | Hata: {len(errors)} satir")

    if errors:
        print("\n      Hata detaylari (ilk 10):")
        for ln, exc, raw in errors[:10]:
            print(f"        Satir {ln}: {exc} | ham={raw}")
        if len(errors) > 10:
            print(f"        ... ve {len(errors) - 10} hata daha")

    if not rows:
        print("Iceri aktarilacak gecerli satir bulunamadi. Cikiliyor.")
        sys.exit(1)

    # 3. Veritabanina baglan
    print(f"\n[2/3] {DSN} adresine baglaniliyor ({DB_USER})...")
    try:
        conn   = oracledb.connect(user=DB_USER, password=DB_PASSWORD, dsn=DSN)
        cursor = conn.cursor()
        print("      Baglanti basarili.")
    except oracledb.Error as exc:
        print(f"Veritabani baglanti hatasi: {exc}")
        print(
            "\nIpucu: Docker container'in calistigini kontrol edin:\n"
            "  docker ps\n"
            "  docker compose logs -f"
        )
        sys.exit(1)

    # 4. Mevcut verileri temizle (yeniden calistirma guvenligi)
    try:
        cursor.execute("SELECT COUNT(*) FROM MONTHLY_STATS")
        mevcut_sayi = cursor.fetchone()[0]
        if mevcut_sayi > 0:
            print(f"\n      MONTHLY_STATS tablosunda {mevcut_sayi} mevcut satir var.")
            yanit = input("      Temizlenip yeniden yukleme yapilsin mi? [e/H]: ").strip().lower()
            if yanit == "e":
                cursor.execute("DELETE FROM MONTHLY_STATS")
                conn.commit()
                print(f"      {mevcut_sayi} satir silindi.")
            else:
                print("      Mevcut veriler korunuyor. Cikiliyor.")
                cursor.close()
                conn.close()
                sys.exit(0)
    except oracledb.Error as exc:
        print(f"Tablo sorgusu hatasi: {exc}")
        cursor.close()
        conn.close()
        sys.exit(1)

    # 5. Toplu ekleme
    print(f"\n[3/3] {len(rows)} satir ekleniyor...")
    try:
        cursor.executemany(INSERT_SQL, rows)
        conn.commit()
        print(f"      Basariyla eklendi: {len(rows)} satir.")
    except oracledb.Error as exc:
        conn.rollback()
        print(f"Ekleme hatasi (geri alindi): {exc}")
        cursor.close()
        conn.close()
        sys.exit(1)

    # 6. Dogrulama
    cursor.execute("SELECT COUNT(*) FROM MONTHLY_STATS")
    toplam = cursor.fetchone()[0]
    print(f"\n      Dogrulama: MONTHLY_STATS tablosunda toplam {toplam} satir.")

    cursor.close()
    conn.close()
    print("\nTamamlandi.")


if __name__ == "__main__":
    main()
