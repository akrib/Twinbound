import os
import subprocess
import ollama

# === CONFIG ===
# Chemins relatifs depuis la racine du projet
source_dir = "."                       # racine du projet
documentation_dir = "./documentation"  # dossier pour les docs
state_file_path = os.path.join(documentation_dir, "documentation_state.txt")
model_name = "qwen2.5-coder:7b"
extensions = [".gd", ".tscn", ".godot"]

# Crée le dossier documentation si nécessaire
os.makedirs(documentation_dir, exist_ok=True)

# --- Lire l'état actuel (si existe) ---
state = {}
if os.path.exists(state_file_path):
    with open(state_file_path, "r", encoding="utf-8") as f:
        for line in f:
            if "|" in line:
                fname, hash_ = line.strip().split("|")
                state[fname.strip()] = hash_.strip()

# --- Parcourir les fichiers suivis par Git ---
result = subprocess.run(["git", "ls-files"], cwd=source_dir, capture_output=True, text=True)
files = result.stdout.splitlines()

for file in files:
    if any(file.endswith(ext) for ext in extensions):
        full_path = os.path.join(source_dir, file)
        
        # --- Calculer hash Git (7 premiers caractères) ---
        hash_result = subprocess.run(
            ["git", "hash-object", full_path],
            cwd=source_dir, capture_output=True, text=True
        )
        file_hash = hash_result.stdout.strip()[:7]
        
        # --- Vérifier si déjà documenté ---
        if file in state and state[file] == file_hash:
            print(f"{file} : déjà documenté, OK.")
            continue
        
        # --- Lire le contenu du fichier ---
        with open(full_path, "r", encoding="utf-8") as f:
            code = f.read()
        
        # --- Créer le prompt pour Qwen ---
        prompt = f"""
You are updating project documentation for a Godot project.

Read the source file (extension {os.path.splitext(file)[1]}).

Generate or update its documentation in markdown format:
- Name the output file: {os.path.basename(file)}.md
- Save it in the documentation folder.
- Use clear headings, code snippets, and explanations relevant to the content.
- Do NOT modify the source code.
- Focus on accuracy and clarity.

Here is the content of the source file:

{code}
"""

        # --- Appel au modèle Ollama ---
        try:
            response = ollama.chat(
                model=model_name,
                messages=[{"role": "user", "content": prompt}]
            )
            doc_content = response["content"]
        except Exception as e:
            print(f"Erreur lors de la génération de doc pour {file}: {e}")
            continue
        
        # --- Sauvegarder la documentation ---
        doc_filename = f"{os.path.basename(file)}.md"
        doc_path = os.path.join(documentation_dir, doc_filename)
        with open(doc_path, "w", encoding="utf-8") as f:
            f.write(doc_content)
        
        print(f"Documentation générée pour {file} -> {doc_path}")

        # --- Mettre à jour l'état ---
        state[file] = file_hash

# --- Réécrire documentation_state.txt ---
with open(state_file_path, "w", encoding="utf-8") as f:
    for fname, hash_ in state.items():
        f.write(f"{fname} | {hash_}\n")

print("documentation_state.txt mis à jour.")
