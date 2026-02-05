import re
from collections import defaultdict

def parse_xkb_file(file_path):
    """
    Parse un fichier de symboles XKB et extrait les keymaps pour chaque variante.
    """
    layouts = defaultdict(dict)
    current_layout = None
    layout_regex = re.compile(r'xkb_symbols\s+"([^"]+)"')
    key_regex = re.compile(r'key\s+<(\w+)>\s*\{\s*\[\s*([^\]]+)\s*\]\s*};')

    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            match_layout = layout_regex.search(line)
            if match_layout:
                layout_name = match_layout.group(1)
                if layout_name in ["default", "pc"]:
                    current_layout = "basic"
                else:
                    current_layout = layout_name
                continue

            if current_layout:
                match_key = key_regex.search(line)
                if match_key:
                    key_code = match_key.group(1)
                    symbols = [s.strip() for s in match_key.group(2).split(',')]
                    layouts[current_layout][key_code] = symbols

    return layouts

def compare_layouts(layouts, layout1_name, layout2_name):
    """
    Compare deux layouts et affiche leurs différences.
    Affiche aussi le caractère de base pour une identification facile.
    """
    print(f"\n--- Comparaison entre '{layout1_name}' et '{layout2_name}' ---")
    
    layout1 = layouts.get(layout1_name, {})
    layout2 = layouts.get(layout2_name, {})
    basic_layout = layouts.get("basic", {}) # On récupère le layout de base pour référence
    
    all_keys = sorted(list(set(layout1.keys()) | set(layout2.keys())))
    
    found_diff = False
    for key in all_keys:
        symbols1 = layout1.get(key, "N/A")
        symbols2 = layout2.get(key, "N/A")
        
        if symbols1 != symbols2:
            found_diff = True
            
            # --- MODIFICATION ICI ---
            # Récupère le caractère de base (ex: 'a', 'é', '²') pour l'afficher
            basic_symbols = basic_layout.get(key)
            base_char_display = f"({basic_symbols[0]})" if basic_symbols else ""
            # --- FIN DE LA MODIFICATION ---
            
            print(f"Touche <{key}> {base_char_display}:")
            print(f"  - {layout1_name:<10}: {symbols1}")
            print(f"  - {layout2_name:<10}: {symbols2}")
            
    if not found_diff:
        print("Aucune différence trouvée.")


if __name__ == "__main__":
    XKB_FR_FILE = "/usr/share/X11/xkb/symbols/fr"
    
    try:
        all_layouts = parse_xkb_file(XKB_FR_FILE)
        
        print(f"Layouts trouvés dans '{XKB_FR_FILE}': {list(all_layouts.keys())}")
        
        # --- LIGNES À RAJOUTER ---
        # Comparer la version de base avec la version latin9
        compare_layouts(all_layouts, "basic", "latin9")
        
        # Comparer la version de base avec la version OSS
        compare_layouts(all_layouts, "basic", "oss")
        
        # Comparer la version latin9 avec la version OSS
        compare_layouts(all_layouts, "latin9", "oss")
        # --- FIN DES AJOUTS ---

    except FileNotFoundError:
        print(f"Erreur : Le fichier '{XKB_FR_FILE}' n'a pas été trouvé.")
    except Exception as e:
        print(f"Une erreur est survenue : {e}")
