Add-Type -AssemblyName System.Drawing

$inputFile = "C:\Users\patri\.gemini\antigravity\brain\5153d230-8fd6-4eac-a6fe-ade500afba13\logo_emini_black_transparent_1775225872996.png"
$outputFile = "d:\Nouveau dossier\assets\images\logo_emini.png"

try {
    $img = [System.Drawing.Image]::FromFile($inputFile)
    $bmp = New-Object System.Drawing.Bitmap($img.Width, $img.Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.DrawImage($img, 0, 0, $img.Width, $img.Height)
    
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
