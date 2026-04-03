Add-Type -AssemblyName System.Drawing

# We use the original high quality logo you liked
$inputFile = "C:\Users\patri\.gemini\antigravity\brain\5153d230-8fd6-4eac-a6fe-ade500afba13\emini_connect_pro_logo_1775207662690.png"
$outputFile = "d:\Nouveau dossier\assets\images\logo_emini.png"

try {
    $img = [System.Drawing.Image]::FromFile($inputFile)
    $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.DrawImage($img, 0, 0, $img.Width, $img.Height)
    
    # Fill the bottom right corner with black to remove the small watermark star
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
    $x = $img.Width - 100
    $y = $img.Height - 100
    $rect = New-Object System.Drawing.Rectangle($x, $y, 100, 100)
    $graphics.FillRectangle($brush, $rect)
    
    $graphics.Dispose()
    
    if (Test-Path $outputFile) {
        Remove-Item $outputFile -Force
    }
    $bmp.Save($outputFile, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $bmp.Dispose()
    $img.Dispose()
    Write-Host "Success: Watermark removed and saved to $outputFile"
} catch {
    Write-Host "Error: $_"
}
