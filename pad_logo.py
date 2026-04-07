from PIL import Image

try:
    img = Image.open('d:/Nouveau dossier/assets/images/logo_emini.png').convert('RGBA')
    # Generate a padded logo: the original is placed in an extended, transparent or background-colored canvas
    size = img.size
    # Shrink apparent size by embedding it in a larger canvas (Android 12 adds circular mask and zooms)
    new_size = (int(size[0] * 3.0), int(size[1] * 3.0))
    # Fill with transparent or same background color #040301 (RGB: 4, 3, 1)
    new_img = Image.new('RGBA', new_size, (4, 3, 1, 255))
    offset = ((new_size[0] - size[0]) // 2, (new_size[1] - size[1]) // 2)
    new_img.paste(img, offset, img)
    new_img.save('d:/Nouveau dossier/assets/images/logo_emini_splash_12.png')
    print('SUCCESS')
except Exception as e:
    print('Error:', e)
