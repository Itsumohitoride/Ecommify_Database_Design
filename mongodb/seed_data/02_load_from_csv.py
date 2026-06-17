#!/usr/bin/env python3
"""
Ecommify — MongoDB Data Loader from CSV Files

Loads Olist CSV data into MongoDB Atlas:
  - geolocation collection from olist_geolocation_dataset.csv
  - products_catalog collection from olist_products_dataset.csv + product_category_name_translation.csv

Usage:
    python mongodb/seed_data/02_load_from_csv.py

Requires:
    - pymongo
    - python-dotenv
    - .env file (src/.env) with MONGO_USER and MONGO_PASSWORD
"""

import csv
import json
import os
import sys
import datetime
from dotenv import load_dotenv
from pymongo import MongoClient, InsertOne
from pymongo.errors import BulkWriteError, ConnectionFailure, ServerSelectionTimeoutError

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.normpath(os.path.join(SCRIPT_DIR, "..", ".."))       # src/Ecommify_Database_Design
HARNESS_DIR = os.path.normpath(os.path.join(PROJECT_DIR, "..", ".."))      # raíz del harness
DATA_DIR = os.path.join(HARNESS_DIR, "src", "data")
ENV_PATH = os.path.join(HARNESS_DIR, "src", ".env")
SCHEMA_DIR = os.path.join(PROJECT_DIR, "mongodb", "schema")

MONGO_URI_TEMPLATE = "mongodb+srv://{user}:{password}@cluster0.d8kyjpl.mongodb.net/?appName=Cluster0"
DB_NAME = "ecommify"
BATCH_SIZE = 5000

def find_file(relative: str) -> str:
    candidates = [
        os.path.join(DATA_DIR, relative),
        os.path.join(HARNESS_DIR, "src", "data", relative),
        os.path.join(os.getcwd(), relative),
        os.path.join(os.getcwd(), "src", "data", relative),
    ]
    for p in candidates:
        if os.path.exists(p):
            return os.path.abspath(p)
    return ""

def load_env():
    if os.path.exists(ENV_PATH):
        load_dotenv(ENV_PATH)
        print(f"[OK] .env: {ENV_PATH}")
    else:
        print(f"[WARN] .env no encontrado en {ENV_PATH}")
        load_dotenv()
    user = os.getenv("MONGO_USER")
    password = os.getenv("MONGO_PASSWORD")
    if not user or not password:
        print("[ERROR] MONGO_USER y MONGO_PASSWORD requeridos en .env")
        sys.exit(1)
    return user, password

def get_client(user, password):
    uri = MONGO_URI_TEMPLATE.format(user=user, password=password)
    client = MongoClient(uri, maxPoolSize=10, serverSelectionTimeoutMS=10000)
    try:
        client.admin.command("ping")
        print(f"[OK] MongoDB Atlas conectado")
    except (ConnectionFailure, ServerSelectionTimeoutError) as e:
        print(f"[ERROR] No se pudo conectar: {e}")
        sys.exit(1)
    return client

def load_geolocation(db):
    """Load geolocation from CSV with fast bulk inserts."""
    print("\n=== GEOLOCATION ===")
    csv_file = find_file("olist_geolocation_dataset.csv")
    if not csv_file:
        print("[ERROR] olist_geolocation_dataset.csv no encontrado")
        return False
    print(f"[OK] CSV: {csv_file}")

    # Crear colección si no existe
    if "geolocation" not in db.list_collection_names():
        db.create_collection("geolocation")
        print("[OK] Coleccion geolocation creada")

    batch = []
    total = 0
    with open(csv_file, encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            batch.append({
                "geolocation_zip_code_prefix": row["geolocation_zip_code_prefix"],
                "geolocation_lat": float(row["geolocation_lat"]),
                "geolocation_lng": float(row["geolocation_lng"]),
                "geolocation_city": row["geolocation_city"],
                "geolocation_state": row["geolocation_state"],
            })
            total += 1
            if len(batch) >= BATCH_SIZE:
                db.geolocation.insert_many(batch, ordered=False)
                batch = []

    if batch:
        db.geolocation.insert_many(batch, ordered=False)

    print(f"[OK] geolocation: {db.geolocation.count_documents({})} docs")

    # Create indexes
    for name, keys in [("state_city_1", [("geolocation_state", 1), ("geolocation_city", 1)]),
                        ("zip_1", [("geolocation_zip_code_prefix", 1)])]:
        if name not in [i["name"] for i in db.geolocation.list_indexes()]:
            db.geolocation.create_index(keys, name=name)
            print(f"  [OK] Indice creado: {name}")
    return True

def load_products(db):
    """Load products_catalog from CSV using bulk_write."""
    print("\n=== PRODUCTS_CATALOG ===")
    trans_file = find_file("product_category_name_translation.csv")
    if not trans_file:
        print("[ERROR] product_category_name_translation.csv no encontrado")
        return False
    trans = {}
    with open(trans_file, encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            trans[row["product_category_name"]] = row["product_category_name_english"]
    print(f"[OK] Traducciones: {len(trans)} categorias")

    prod_file = find_file("olist_products_dataset.csv")
    if not prod_file:
        print("[ERROR] olist_products_dataset.csv no encontrado")
        return False
    print(f"[OK] CSV: {prod_file}")

    if "products_catalog" not in db.list_collection_names():
        db.create_collection("products_catalog")
        print("[OK] Coleccion products_catalog creada")

    all_docs = []
    with open(prod_file, encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            cat = row.get("product_category_name", "")
            all_docs.append({
                "product_id": row["product_id"],
                "product_category_name": cat,
                "category_name_english": trans.get(cat, ""),
                "product_name_lenght": int(row.get("product_name_lenght", 0) or 0),
                "product_description_lenght": int(row.get("product_description_lenght", 0) or 0),
                "product_photos_qty": int(row.get("product_photos_qty", 0) or 0),
                "product_weight_g": int(row.get("product_weight_g", 0) or 0),
                "product_length_cm": int(row.get("product_length_cm", 0) or 0),
                "product_height_cm": int(row.get("product_height_cm", 0) or 0),
                "product_width_cm": int(row.get("product_width_cm", 0) or 0),
            })

    # Bulk insert in batches
    for i in range(0, len(all_docs), BATCH_SIZE):
        batch = all_docs[i:i + BATCH_SIZE]
        requests = [InsertOne(d) for d in batch]
        db.products_catalog.bulk_write(requests, ordered=False)
        print(f"  {min(i + BATCH_SIZE, len(all_docs))}/{len(all_docs)}")

    print(f"[OK] products_catalog: {db.products_catalog.count_documents({})} docs")

    # Create indexes
    for name, keys in [("product_id_1", [("product_id", 1)]),
                        ("category_name_1", [("product_category_name", 1)])]:
        if name not in [i["name"] for i in db.products_catalog.list_indexes()]:
            db.products_catalog.create_index(keys, name=name, unique=(name == "product_id_1"))
            print(f"  [OK] Indice creado: {name}")
    return True

def load_seed_data(db):
    """Load seed data for event_logs and user_sessions."""
    print("\n=== SEED DATA ===")
    now = datetime.datetime.now(datetime.timezone.utc)

    events = [
        {"event_type": "product_view", "customer_unique_id": "d6d5a20df8c820cbce39fd49b34bd9ac", "session_id": "sess_abc123", "product_id": "ffe9c82b9f56afcf0dfe57d81de5f5a5", "category": "informatica_acessorios", "metadata": {"source": "search_results", "position": 3, "search_query": "mouse inalambrico"}, "timestamp": now - datetime.timedelta(days=1), "ttl_expire": now + datetime.timedelta(days=89)},
        {"event_type": "product_view", "customer_unique_id": "d6d5a20df8c820cbce39fd49b34bd9ac", "session_id": "sess_abc123", "product_id": "e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2", "category": "eletronicos", "metadata": {"source": "search_results", "position": 1, "search_query": "fone bluetooth"}, "timestamp": now - datetime.timedelta(hours=23), "ttl_expire": now + datetime.timedelta(days=89)},
        {"event_type": "cart_add", "customer_unique_id": "d6d5a20df8c820cbce39fd49b34bd9ac", "session_id": "sess_abc123", "product_id": "ffe9c82b9f56afcf0dfe57d81de5f5a5", "seller_id": "cca3071a3a8b5b6a7c8d9e0f1a2b3c4d5", "category": "informatica_acessorios", "metadata": {"quantity": 1, "unit_price": 89.90}, "timestamp": now - datetime.timedelta(hours=22), "ttl_expire": now + datetime.timedelta(days=89)},
        {"event_type": "search", "customer_unique_id": "e5a4b3c2d1f0a9b8c7d6e5f4a3b2c1d0", "session_id": "sess_def456", "metadata": {"search_query": "toalha algodao", "results_count": 23, "filters": {"category": "cama_mesa_banho", "min_price": 20, "max_price": 100}}, "timestamp": now - datetime.timedelta(hours=21), "ttl_expire": now + datetime.timedelta(days=89)},
        {"event_type": "product_view", "customer_unique_id": "e5a4b3c2d1f0a9b8c7d6e5f4a3b2c1d0", "session_id": "sess_def456", "product_id": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6", "category": "cama_mesa_banho", "metadata": {"source": "search_results", "position": 2, "search_query": "toalha algodao"}, "timestamp": now - datetime.timedelta(hours=20), "ttl_expire": now + datetime.timedelta(days=89)},
        {"event_type": "cart_abandon", "customer_unique_id": "f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1", "session_id": "sess_ghi789", "metadata": {"cart_value": 245.80, "items_count": 3, "time_spent_min": 12}, "timestamp": now - datetime.timedelta(hours=30), "ttl_expire": now + datetime.timedelta(days=89)},
        {"event_type": "checkout_start", "customer_unique_id": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6", "session_id": "sess_jkl012", "metadata": {"cart_value": 178.50, "items_count": 2, "payment_method": "credit_card"}, "timestamp": now - datetime.timedelta(hours=19), "ttl_expire": now + datetime.timedelta(days=89)},
    ]
    db.event_logs.insert_many(events, ordered=False)
    print(f"[OK] event_logs: {db.event_logs.count_documents({})} docs")

    sessions = [
        {"_id": "sess_abc123", "customer_unique_id": "d6d5a20df8c820cbce39fd49b34bd9ac", "cart": [{"product_id": "ffe9c82b9f56afcf0dfe57d81de5f5a5", "quantity": 1, "unit_price": 89.90, "seller_id": "cca3071a3a8b5b6a7c8d9e0f1a2b3c4d5"}, {"product_id": "e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2", "quantity": 1, "unit_price": 199.90, "seller_id": "d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9"}], "created_at": now - datetime.timedelta(days=1), "expires_at": now + datetime.timedelta(days=1)},
        {"_id": "sess_def456", "customer_unique_id": "e5a4b3c2d1f0a9b8c7d6e5f4a3b2c1d0", "cart": [{"product_id": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6", "quantity": 2, "unit_price": 49.90, "seller_id": "b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5"}], "created_at": now - datetime.timedelta(days=1), "expires_at": now + datetime.timedelta(days=1)},
        {"_id": "sess_ghi789", "customer_unique_id": "f6a5b4c3d2e1f0a9b8c7d6e5f4a3b2c1", "cart": [], "created_at": now - datetime.timedelta(days=2), "expires_at": now - datetime.timedelta(hours=2)},
    ]
    db.user_sessions.insert_many(sessions, ordered=False)
    print(f"[OK] user_sessions: {db.user_sessions.count_documents({})} docs")
    return True

def verify_all(db):
    print("\n=== VERIFICACION FINAL ===")
    print(f"{'Coleccion':<20} {'Documentos':<15}")
    print("-" * 35)
    for name in ["geolocation", "products_catalog", "event_logs", "user_sessions"]:
        count = db[name].count_documents({})
        print(f"{name:<20} {count:<15}")

def main():
    print("=" * 50)
    print("  Ecommify - MongoDB CSV Data Loader")
    print("=" * 50)
    user, password = load_env()
    client = get_client(user, password)
    db = client[DB_NAME]
    load_geolocation(db)
    load_products(db)
    load_seed_data(db)
    verify_all(db)
    client.close()
    print("\n[OK] Completado.")

if __name__ == "__main__":
    main()
