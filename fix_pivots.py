import json
import os
from PIL import Image

def fix_pivots(char_id):
    char_dir = f"/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters/{char_id}"
    atlas_json = os.path.join(char_dir, f"{char_id}_atlas.json")
    if not os.path.exists(atlas_json): return
    
    with open(atlas_json) as f:
        atlas = json.load(f)
        
    images = {}
    for img_name in set(f['image'] for f in atlas['frames'].values()):
        img_path = os.path.join(char_dir, f"{img_name}.png")
        if os.path.exists(img_path):
            images[img_name] = Image.open(img_path)
            
    for frame_name, frame_data in atlas['frames'].items():
        img_name = frame_data['image']
        if img_name not in images: continue
        
        rect = frame_data['rect']
        x, y, w, h = int(rect['x']), int(rect['y']), int(rect['w']), int(rect['h'])
        
        img = images[img_name]
        cropped = img.crop((x, y, x + w, y + h))
        
        # Pure Python pixel processing
        pixels = cropped.load()
        opaque_pixels = []
        for py in range(h):
            for px in range(w):
                if pixels[px, py][3] > 128:
                    opaque_pixels.append((px, py))
                    
        if not opaque_pixels:
            continue
            
        bottom_y = max(py for px, py in opaque_pixels)
        top_y = min(py for px, py in opaque_pixels)
        
        height = bottom_y - top_y
        bottom_threshold = bottom_y - int(height * 0.15)
        
        bottom_xs = [px for px, py in opaque_pixels if py >= bottom_threshold]
        if bottom_xs:
            center_x = sum(bottom_xs) / len(bottom_xs)
        else:
            center_x = sum(px for px, py in opaque_pixels) / len(opaque_pixels)
            
        new_pivot = [int(center_x), int(bottom_y)]
        
        # To avoid erratic jumping, maybe we can just use the center of the bounding box of the whole sprite for X, 
        # but feet is better.
        
        frame_data['pivot'] = new_pivot
        
    with open(atlas_json, 'w') as f:
        json.dump(atlas, f, indent=2)
        
    print(f"Fixed pivots for {char_id}")

char_dir = "/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters"
for char_id in os.listdir(char_dir):
    if os.path.isdir(os.path.join(char_dir, char_id)):
        fix_pivots(char_id)
