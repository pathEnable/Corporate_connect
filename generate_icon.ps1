Add-Type -AssemblyName System.Drawing

$width = 1024
$height = 1024
$outputFile = "d:\Nouveau dossier\assets\images\logo_emini.png"

try {
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $bgColor = [System.Drawing.ColorTranslator]::FromHtml("#4AD4BA")
    $fgColor = [System.Drawing.ColorTranslator]::FromHtml("#0D0D0D")

    # Background
    $bgBrush = New-Object System.Drawing.SolidBrush($bgColor)
    # We round the background using graphics path for perfect corners just like the SVG
    $bgPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $radius = 200
    $d = $radius * 2
    $bgPath.AddArc(0, 0, $d, $d, 180, 90)
    $bgPath.AddArc($width - $d, 0, $d, $d, 270, 90)
    $bgPath.AddArc($width - $d, $height - $d, $d, $d, 0, 90)
    $bgPath.AddArc(0, $height - $d, $d, $d, 90, 90)
    $bgPath.CloseFigure()
    
    $gfx.FillPath($bgBrush, $bgPath)

    $fgBrush = New-Object System.Drawing.SolidBrush($fgColor)

    function DrawPoly($points) {
        $pts = [System.Collections.ArrayList]::new()
        foreach ($p in $points) {
            $pts.Add((New-Object System.Drawing.Point($p[0], $p[1]))) | Out-Null
        }
        $ptArray = $pts.ToArray([System.Drawing.Point])
        $gfx.FillPolygon($fgBrush, $ptArray)
    }

    # Left Branches
    DrawPoly @((70, 100), (480, 330), (480, 490), (70, 260))
    DrawPoly @((70, 320), (480, 550), (480, 710), (70, 480))
    DrawPoly @((70, 540), (480, 770), (480, 930), (70, 700))

    # Right Branches
    DrawPoly @((954, 100), (544, 330), (544, 490), (954, 260))
    DrawPoly @((954, 320), (544, 550), (544, 710), (954, 480))
    DrawPoly @((954, 540), (544, 770), (544, 930), (954, 700))

    # Dot
    $gfx.FillEllipse($fgBrush, 512 - 25, 280 - 25, 50, 50)

    # Arcs
    $pen = New-Object System.Drawing.Pen($fgColor, 35)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $gfx.DrawArc($pen, 512 - 70, 280 - 70, 140, 140, 225, 90)
    $gfx.DrawArc($pen, 512 - 130, 280 - 130, 260, 260, 225, 90)
    $gfx.DrawArc($pen, 512 - 190, 280 - 190, 380, 380, 225, 90)

    if (Test-Path $outputFile) {
        Remove-Item $outputFile -Force
    }
    # To support transparency around the rounded corners, we need to ensure the background clear is transparent
    # The default bitmap background is transparent.
    $bmp.Save($outputFile, [System.Drawing.Imaging.ImageFormat]::Png)

    $gfx.Dispose()
    $bmp.Dispose()
    Write-Host "Success: High-res clean PNG saved without watermark"
} catch {
    Write-Host "Error: $_"
}
