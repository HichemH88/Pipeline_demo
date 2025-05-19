import psycopg2
import time

while True:
    try:
        conn = psycopg2.connect(
            dbname="mydb",
            user="admin",
            password="admin",
            host="pg-db",
            port="5432"
        )
        print("✅ Connected to database")
        
        cur = conn.cursor()
        cur.execute("SELECT CURRENT_TIMESTAMP;")
        current_time = cur.fetchone()[0]
        print("🕒 Current DB time:", current_time)

        cur.close()
        conn.close()
        break
    except psycopg2.OperationalError as e:
        print(f"❌ Database not ready: {e}")
        time.sleep(3)
