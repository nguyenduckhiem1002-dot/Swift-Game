import json
import os
from PIL import Image

def get_alpha(img, rect):
    x, y, w, h = int(rect['x']), int(rect['y']), int(rect['w']), int(rect['h'])
    cropped = img.crop((x, y, x + w, y + h))
    pixels = cropped.load()
    alpha = set()
    for py in range(0, h, 2):
        for px in range(0, w, 2):
            if pixels[px, py][3] > 128:
                alpha.add((px, py))
    return alpha, w, h

def best_shift(ref_alpha, target_alpha, max_shift=15):
    best_score = -1
    best_dx = 0
    best_dy = 0
    for dx in range(-max_shift, max_shift+1, 4):
        for dy in range(-max_shift, max_shift+1, 4):
            shifted = {(x + dx, y + dy) for (x, y) in target_alpha}
            score = len(ref_alpha.intersection(shifted))
            if score > best_score:
                best_score = score
                best_dx = dx
                best_dy = dy
    
    refined_score = best_score
    ref_dx, ref_dy = best_dx, best_dy
    for dx in range(best_dx-3, best_dx+4, 1):
        for dy in range(best_dy-3, best_dy+4, 1):
            shifted = {(x + dx, y + dy) for (x, y) in target_alpha}
            score = len(ref_alpha.intersection(shifted))
            if score > refined_score:
                refined_score = score
                ref_dx = dx
                ref_dy = dy
    
    return ref_dx, ref_dy

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
            
    idle_names = atlas.get('animations', {}).get('idle', [])
    if not idle_names:
        idle_names = list(atlas['frames'].keys())
        
    ref_name = idle_names[0]
    ref_data = atlas['frames'][ref_name]
    ref_img = images[ref_data['image']]
    ref_alpha, ref_w, ref_h = get_alpha(ref_img, ref_data['rect'])
    
    if not ref_alpha:
        return
        
    min_x = min(x for x, y in ref_alpha)
    max_x = max(x for x, y in ref_alpha)
    max_y = max(y for x, y in ref_alpha)
    
    base_pivot_x = (min_x + max_x) // 2
    base_pivot_y = max_y
    
    atlas['frames'][ref_name]['pivot'] = [base_pivot_x, base_pivot_y]
    
    print(f"[{char_id}] ref={ref_name} base_pivot={base_pivot_x},{base_pivot_y}")
    
    for anim_name, frames in atlas.get('animations', {}).items():
        for frame_name in frames:
            if frame_name == ref_name: continue
            if frame_name not in atlas['frames']: continue
            
            frame_data = atlas['frames'][frame_name]
            img = images[frame_data['image']]
            target_alpha, target_w, target_h = get_alpha(img, frame_data['rect'])
            
            if not target_alpha: continue
            
            dx, dy = best_shift(ref_alpha, target_alpha)
            
            new_pivot_x = base_pivot_x - dx
            new_pivot_y = base_pivot_y - dy
            
            frame_data['pivot'] = [new_pivot_x, new_pivot_y]
            
    with open(atlas_json, 'w') as f:
        json.dump(atlas, f, indent=2)

char_dir = "/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters"
for char_id in os.listdir(char_dir):
    if os.path.isdir(os.path.join(char_dir, char_id)):
        fix_pivots(char_id)

