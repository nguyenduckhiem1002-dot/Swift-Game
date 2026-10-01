import json
import os
from PIL import Image

char_dir = "/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters"
for char_id in os.listdir(char_dir):
    d = os.path.join(char_dir, char_id)
    if not os.path.isdir(d): continue
    
    atlas_json = os.path.join(d, f"{char_id}_atlas.json")
    if not os.path.exists(atlas_json): continue
    
    with open(atlas_json) as f:
        atlas = json.load(f)
        
    idle_names = atlas.get('animations', {}).get('idle', [])
    if not idle_names: continue
    
    idle0 = idle_names[0]
    frame_data = atlas['frames'].get(idle0)
    if not frame_data: continue
    
    img_name = frame_data['image']
    img_path = os.path.join(d, f"{img_name}.png")
    if not os.path.exists(img_path): continue
    
    img = Image.open(img_path)
    rect = frame_data['rect']
    x, y, w, h = int(rect['x']), int(rect['y']), int(rect['w']), int(rect['h'])
    
    cropped = img.crop((x, y, x + w, y + h))
    portrait_path = os.path.join(d, f"{char_id}_portrait.png")
    cropped.save(portrait_path)
    print(f"Generated portrait for {char_id}")

