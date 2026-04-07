import os
import re

lib_dir = r"d:\Nouveau dossier\lib"

files_to_modify = [
    r"widgets\home\status_list_section.dart",
    r"widgets\home\room_tile.dart",
    r"widgets\chat\message_bubble.dart",
    r"screens\image_viewer_screen.dart",
    r"screens\profile_screen.dart",
    r"screens\room_details_screen.dart",
    r"screens\search_screen.dart",
    r"screens\status_tab_screen.dart",
    r"screens\story_view_screen.dart",
    r"screens\contacts_screen.dart",
    r"screens\admin_dashboard_screen.dart"
]

for rel_path in files_to_modify:
    path = os.path.join(lib_dir, rel_path)
    if not os.path.exists(path):
        continue
    
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Check if we need to add the import
    # Determine depth relative to lib/
    depth = rel_path.count('\\')
    import_path = '../' * depth + 'widgets/authenticated_image.dart'
    import_stmt = f"import '{import_path}';"
    
    # If not imported, add to top (after the first import)
    if import_stmt not in content and 'AuthenticatedImage' not in content:
        content = re.sub(r"^(import .*;\n)", r"\1" + import_stmt + "\n", content, count=1)
    
    # Replace NetworkImage(...)
    content = re.sub(r"\bNetworkImage\(", "AuthenticatedImageProvider(", content)
    # Replace CachedNetworkImageProvider(...)
    content = re.sub(r"\bCachedNetworkImageProvider\(", "AuthenticatedImageProvider(", content)
    # Replace CachedNetworkImage(imageUrl: ...)
    content = re.sub(r"\bCachedNetworkImage\(", "AuthenticatedNetworkImage(", content)
    
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Updated {rel_path}")
