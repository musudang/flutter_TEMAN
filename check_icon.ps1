[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing') | Out-Null
$sizes = @('mipmap-mdpi','mipmap-hdpi','mipmap-xhdpi','mipmap-xxhdpi','mipmap-xxxhdpi')
foreach ($s in $sizes) {
    $path = "android\app\src\main\res\$s\launcher_icon.png"
    if (Test-Path $path) {
        $img = [System.Drawing.Image]::FromFile((Resolve-Path $path))
        Write-Host "$s : $($img.Width) x $($img.Height)"
        $img.Dispose()
    } else {
        Write-Host "$s : NOT FOUND"
    }
}
