from PIL import Image
import sys

def process_image(input_path, output_path):
    img = Image.open(input_path).convert("RGBA")
    datas = img.getdata()

    newName = []
    # In the clean image, the background and cutouts are white. The logo is turquoise.
    # We want: 
    # - white -> transparent
    # - turquoise -> black
    # To handle anti-aliasing smoothly, we can interpret the brightness/color.
    # Turquoise is roughly (26, 188, 156). White is (255, 255, 255).
    # Since the image is just turquoise and white, we can look at the red channel or relative difference.
    
    for item in datas:
        r, g, b, a = item
        # Calculate how "white" vs "turquoise" the pixel is.
        # Turquoise has high green/blue, low red. White has high red, green, blue.
        # Red channel is a good indicator: turquoise r is ~30, white r is 255.
        # Let's say: blending from red=30 (which maps to alpha=255, black) to red=255 (alpha=0).
        
        # We want the shape to be purely black (0,0,0) and the transparency to be based on the red channel value!
        # If r is close to 255, alpha -> 0. If r is close to 0-30, alpha -> 255.
        # Using linear interpolation based on red channel:
        alpha = max(0, min(255, 255 - r))
        
        # But wait, turquoise in the image might have r slightly higher in edges. 
        # Actually, let's just make the whole image black and use the inverted red channel as alpha.
        # R=255 -> alpha=0. R=30 -> alpha=225 (maybe scale so 30 is 255).
        # Let's find min and max red in the image just to be safe.
        
        # A simpler way:
        # If r > 200, assume it's background -> transparent
        # Make the color black. To preserve antialiasing, we can make the color black, and alpha = 255 - r.
        # Since white is (255,255,255) -> 255 - 255 = 0 alpha.
        # Turquoise is (maybe) (30, 180, 150) -> 255 - 30 = 225 alpha.
        # Let's scale alpha so the min red value becomes 255 alpha.
        pass

    # Let's actually compute min_r
    min_r = 255
    for item in datas:
        if item[3] > 0:
            if item[0] < min_r:
                min_r = item[0]
                
    # Scale alpha based on min_r and 255
    for item in datas:
        r, g, b, a = item
        if a == 0:
            newName.append((0, 0, 0, 0))
            continue
            
        # alpha from red channel:
        if r == 255:
            new_a = 0
        elif r <= min_r:
            new_a = 255
        else:
            # map min_r..255 to 255..0
            new_a = int(255 * (1 - (r - min_r) / (255 - min_r)))
            
        newName.append((0, 0, 0, new_a))

    img.putdata(newName)
    
    # Save the processed image
    img.save(output_path, "PNG")
    print(f"Saved to {output_path}")

if __name__ == "__main__":
    input_file = r"C:\Users\patri\.gemini\antigravity\brain\5153d230-8fd6-4eac-a6fe-ade500afba13\emini_icon_clean_1775223805370.png"
    output_file = r"d:\Nouveau dossier\assets\images\logo_emini.png"
    process_image(input_file, output_file)
