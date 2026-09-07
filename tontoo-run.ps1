param([switch]$Rebuild)

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path $ScriptDir -Parent
$IsoDir      = Join-Path $ScriptDir "out"
$VmDir       = Join-Path $ScriptDir "vm"
$DiskFile    = Join-Path $VmDir "disk.qcow2"
$DiskSize    = "32G"
$Mem         = 8192
$Cpus        = 6
$VmName      = "TontooOS"
$WslDistro   = "archlinux"

# ---- WSL-Pfad-Konverter (Windows -> /mnt/c/...) ----
function ConvertTo-WslPath {
    param([string]$Path)
    $p = $Path -replace '\\', '/'
    if ($p -match '^([A-Za-z]):') {
        $p = "/mnt/$([char]::ToLower($Matches[1]))$($p.Substring(2))"
    }
    return $p
}

$IsoDirWsl   = ConvertTo-WslPath $IsoDir
$VmDirWsl    = ConvertTo-WslPath $VmDir
$DiskFileWsl = ConvertTo-WslPath $DiskFile

# ---- WSL + KVM pruefen ----
$WslCheck = & wsl.exe -d $WslDistro -- bash -c "test -e /dev/kvm && echo KVM-OK || echo KVM-FEHLT; command -v qemu-system-x86_64 >/dev/null && echo QEMU-OK || echo QEMU-FEHLT"
if ($LASTEXITCODE -ne 0 -or ($WslCheck -join ' ') -match 'KVM-FEHLT|QEMU-FEHLT') {
    Write-Host "Fehler: WSL2 (Distro '$WslDistro') mit /dev/kvm und QEMU benoetigt." -ForegroundColor Red
    Write-Host "Installiere in der Distro: pacman -S qemu-desktop virglrenderer gtk3" -ForegroundColor Yellow
    pause; exit 1
}

# ---- ISO finden / bauen ----
$Iso = Get-ChildItem "$IsoDir\*.iso" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($Rebuild) { $Iso = $null }

if (-not $Iso) {
    if (-not $Rebuild) {
        Write-Host "Keine ISO in $IsoDir" -ForegroundColor Yellow
        $choice = Read-Host "ISO via WSL bauen? (j/N)"
        if ($choice -ne "j" -and $choice -ne "J") { exit 0 }
    }
    Write-Host "Baue ISO via WSL (Arch Linux)..."
    & wsl.exe -d $WslDistro --cd $ProjectRoot bash -c "./BaseOS/scripts/build-iso.sh" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ISO-Build fehlgeschlagen." -ForegroundColor Red
        pause; exit 1
    }
    $Iso = Get-ChildItem "$IsoDir\*.iso" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $Iso) { Write-Host "Keine ISO nach Build" -ForegroundColor Red; pause; exit 1 }
    Write-Host "Neue ISO: $($Iso.FullName)" -ForegroundColor Green
}
$IsoFileWsl = ConvertTo-WslPath $Iso.FullName

# ---- VM-Disk ----
if (-not (Test-Path $VmDir)) { New-Item -ItemType Directory -Path $VmDir -Force | Out-Null }
if (-not (Test-Path $DiskFile)) {
    Write-Host "Erstelle VM-Disk ($DiskSize)..."
    & wsl.exe -d $WslDistro -- qemu-img create -f qcow2 $DiskFileWsl $DiskSize
}

# ---- QEMU in WSL2 + KVM starten ----
Write-Host "`n=========================================="
Write-Host " Starte $VmName (WSL2 + KVM)"
Write-Host " RAM: ${Mem}MB | CPU: $Cpus | Disk: $DiskSize"
Write-Host " ISO: $($Iso.FullName)"
Write-Host "==========================================`n"

# virgl (3D) via virtio-gpu aktivieren - Gast nutzt dann nicht mehr llvmpipe.
# DISPLAY=:0 = WSLg (Windows 11) fuer das GTK-Fenster.
& wsl.exe -d $WslDistro -- bash -lc "
    export DISPLAY=:0
    export LIBGL_ALWAYS_SOFTWARE=0
    exec qemu-system-x86_64 \
        -machine q35,accel=kvm,usb=on \
        -m $Mem \
        -smp $Cpus \
        -device virtio-vga-gl,xres=1280,yres=720 \
        -display gtk,gl=on \
        -drive file=$DiskFileWsl,format=qcow2,if=virtio \
        -cdrom $IsoFileWsl \
        -boot menu=on,order=d \
        -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
        -device usb-tablet \
        -serial stdio \
        -name $VmName
" 2>&1