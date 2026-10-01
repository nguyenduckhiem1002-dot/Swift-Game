import json
import os
from PIL import Image

def slice_padded(char_id, atlas_dir):
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
    
    canvas_size = 512
    pivot_x_canvas = 256
    pivot_y_canvas = 400
    
    for frame_name, frame_data in atlas['frames'].items():
        img_name = frame_data['image']
        if img_name not in images:
            continue
            
        rect = frame_data['rect']
        pivot = frame_data['pivot']
        x, y, w, h = int(rect['x']), int(rect['y']), int(rect['w']), int(rect['h'])
        px, py = int(pivot[0]), int(pivot[1])
        
        img = images[img_name]
        cropped = img.crop((x, y, x + w, y + h))
        
        padded = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        
        paste_x = pivot_x_canvas - px
        paste_y = pivot_y_canvas - py
        
        padded.paste(cropped, (paste_x, paste_y))
        
        out_path = os.path.join(out_dir, f"{frame_name}.png")
        padded.save(out_path)
        
    print(f"Sliced and padded {len(atlas['frames'])} frames for {char_id}")

char_dir = "/Users/duck/Dev/Game/SwordDuel/Resources/Assets/Characters"
for char_id in os.listdir(char_dir):
    if os.path.isdir(os.path.join(char_dir, char_id)):
        slice_padded(char_id, os.path.join(char_dir, char_id))
