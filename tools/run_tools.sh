#!/bin/bash

# Script de menu pour lancer les scripts Python du dossier tools
# À lancer depuis la racine du projet via Git Bash

TOOLS_DIR="./tools"

while true; do
    echo "=========================="
    echo "    Menu des outils Python"
    echo "=========================="
    echo "1) export_debug_info.py"
    echo "2) install_git_hooks.py"
    echo "3) qwen_scan.py"
    echo "4) validate_json.py"
    echo "5) Générer repomix.txt"
    echo "6) Quitter"
    echo "--------------------------"
    read -p "Choisissez un numéro: " choice

    case $choice in
        1)
            python "$TOOLS_DIR/export_debug_info.py"
            ;;
        2)
            python "$TOOLS_DIR/install_git_hooks.py"
            ;;
        3)
            python "$TOOLS_DIR/qwen_scan.py"
            ;;
        4)
            python "$TOOLS_DIR/validate_json.py"
            ;;
        5)
            echo "Génération de repomix.txt depuis la racine du projet..."
            # Sauvegarde le répertoire courant
            #CUR_DIR=$(pwd)
            # Change temporairement vers la racine (une fois au-dessus de tools/)
            # Exécute repomix
            pwd
            repomix --compress --style markdown --remove-comments --include "**/*.gd,**/*.tscn,**/*.godot" --output documentation/repomix_by_tools.md 
            # Reviens au répertoire initial
            #cd "$CUR_DIR"
            echo "repomix_by_tools.md généré dans documentation/"
            ;;
        6)
            echo "Au revoir !"
            break
            ;;
        *)
            echo "Choix invalide, réessayez."
            ;;
    esac

    echo ""
done
