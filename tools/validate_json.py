import json
import os
import sys

DATA_DIR = "data"

# --- SCHEMAS SIMPLES (MINIMUM VITAL) ---

SCHEMAS = {
    "units": ["id", "name", "race", "nation", "base_stats", "mana_type"],
    "mana": ["id", "name", "effect_type"],
    "weapons": ["id", "name", "range", "pattern"],
    "items": ["id", "name", "rarity", "effect"]
}


def validate_file(path, required_fields):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"❌ JSON ERROR in {path}: {e}")
        return False

    missing = [field for field in required_fields if field not in data]
    if missing:
        print(f"❌ MISSING FIELDS in {path}: {missing}")
        return False

    return True


def main():
    print("🔍 Validating JSON files...\n")
    errors = 0

    for folder, required_fields in SCHEMAS.items():
        dir_path = os.path.join(DATA_DIR, folder)

        if not os.path.isdir(dir_path):
            print(f"⚠️ Directory missing: {dir_path}")
            continue

        for filename in os.listdir(dir_path):
            if not filename.endswith(".json"):
                continue

            path = os.path.join(dir_path, filename)
            ok = validate_file(path, required_fields)

            if ok:
                print(f"✅ {path}")
            else:
                errors += 1

    print("\nValidation complete.")
    if errors > 0:
        print(f"❌ {errors} error(s) found.")
        sys.exit(1)
    else:
        print("🎉 All JSON files are valid.")
        sys.exit(0)


if __name__ == "__main__":
    main()
