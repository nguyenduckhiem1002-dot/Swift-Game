import json
import os
from PIL import Image

def slice_atlas(char_id, atlas_dir):
    json_path = os.path.join(atlas_dir, f"{char_id}_atlas.json")
    if not os.path.exists(json_path):
        return
        
    with open(json_path, 'r') as f:
        atlas = json.load(f)
        
    images = {}
    for img_name in set(f['image'] for f in atlas['frames'].values()):
        img_path = os.path.join(atlas_dir, f"{img_name}.png")
        if os.path.exists(img_path):
            images[img_name] = Image.open(img_path)
            
    out_dir = os.path.join(atlas_dir, "frames")
    os.makedirs(out_dir, exist_ok=True)
    
    new_atlas = atlas.copy()
    
    for frame_name, frame_data in atlas['frames'].items():
        img_name = frame_data['image']
        if img_name not in images:
            continue
            
        rect = frame_data['rect']
        x, y, w, h = rect['x'], rect['y'], rect['w'], rect['h']
        
        img = images[img_name]
        cropped = img.crop((x, y, x + w, y + h))
        
        out_path = os.path.join(out_dir, f"{frame_name}.png")
        cropped.save(out_path)
        
        # update the atlas to point to the new individual frame
        # actually, if we use individual frames, we might just store the pivots
        
    print(f"Sliced {len(atlas['frames'])} frames for {char_id}")

slice_atlas("frost", "/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters/frost")
