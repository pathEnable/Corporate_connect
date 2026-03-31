import markdown
import sys

def convert_md_to_html(md_file, html_file):
    with open(md_file, 'r', encoding='utf-8') as f:
        text = f.read()
    
    # HTML template avec du CSS pour que le PDF soit beau à l'impression
    html_template = """
    <!DOCTYPE html>
    <html lang="fr">
    <head>
        <meta charset="UTF-8">
        <title>Rapport Exécutif - Corporate Connect</title>
        <style>
            body {{
                font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 800px;
                margin: 0 auto;
                padding: 40px;
            }}
            h1, h2, h3 {{ color: #004D40; }}
            h1 {{ border-bottom: 2px solid #004D40; padding-bottom: 10px; }}
            h2 {{ margin-top: 30px; border-bottom: 1px solid #ddd; padding-bottom: 5px; }}
            table {{ border-collapse: collapse; width: 100%; margin-top: 20px; }}
            th, td {{ border: 1px solid #ddd; padding: 12px; text-align: left; }}
            th {{ background-color: #f2f2f2; color: #004D40; font-weight: bold; }}
            blockquote {{
                background: #f9f9f9;
                border-left: 5px solid #004D40;
                margin: 1.5em 10px;
                padding: 1em 10px;
                font-style: italic;
            }}
            hr {{ border: 0; border-top: 1px solid #eee; margin: 40px 0; }}
            @media print {{
                body {{ padding: 0; }}
                table {{ page-break-inside: avoid; }}
                h2, h3 {{ page-break-after: avoid; }}
            }}
        </style>
    </head>
    <body>
        {content}
        
        <script>
            // Lancer l'impression automatiquement à l'ouverture du fichier
            window.onload = function() {{ window.print(); }}
        </script>
    </body>
    </html>
    """
    
    html_content = markdown.markdown(text, extensions=['tables'])
    final_output = html_template.format(content=html_content)
    
    with open(html_file, 'w', encoding='utf-8') as f:
        f.write(final_output)

if __name__ == "__main__":
    convert_md_to_html("rapport_complet.md", "rapport_complet.html")
