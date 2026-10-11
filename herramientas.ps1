# Herramientas para mantener la lista de mods (formato packwiz) sin instalar packwiz.
# Uso (desde la carpeta "pack"):
#   . .\herramientas.ps1
#   Agregar-Mod jei            # agrega/actualiza un mod de Modrinth (por slug)
#   Quitar-Mod jei             # lo saca de la lista
#   Reconstruir-Pack           # recalcula index.toml y pack.toml (lo hacen solos los comandos de arriba)

$ErrorActionPreference = 'Stop'
$script:Raiz = $PSScriptRoot
$script:McVersion = '1.20.1'
$script:ForgeVersion = '47.4.10'
$script:Loader = 'forge'
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)

function Escribir-Archivo($ruta, $texto) {
    $dir = Split-Path $ruta
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    [IO.File]::WriteAllText($ruta, ($texto -replace "`r`n", "`n"), $script:Utf8)
}

function Sha256-Archivo($ruta) { (Get-FileHash $ruta -Algorithm SHA256).Hash.ToLower() }

function Reconstruir-Pack {
    $archivos = Get-ChildItem (Join-Path $script:Raiz 'mods') -Filter *.pw.toml -File -ErrorAction SilentlyContinue | Sort-Object Name
    $idx = "hash-format = `"sha256`"`n"
    foreach ($a in $archivos) {
        $rel = "mods/$($a.Name)"
        $idx += "`n[[files]]`nfile = `"$rel`"`nhash = `"$(Sha256-Archivo $a.FullName)`"`nmetafile = true`n"
    }
    $idxRuta = Join-Path $script:Raiz 'index.toml'
    Escribir-Archivo $idxRuta $idx
    $pack = @"
name = "Servidor de Minecraft"
pack-format = "packwiz:1.1.0"

[index]
file = "index.toml"
hash-format = "sha256"
hash = "$(Sha256-Archivo $idxRuta)"

[versions]
$($script:Loader) = "$($script:ForgeVersion)"
minecraft = "$($script:McVersion)"
"@
    Escribir-Archivo (Join-Path $script:Raiz 'pack.toml') $pack
    "Lista reconstruida: $($archivos.Count) mod(s)."
}

function Agregar-Mod([string]$slug) {
    $h = @{ 'User-Agent' = 'minecraft-server-pack' }
    $loaders = [uri]::EscapeDataString('["' + $script:Loader + '"]')
    $vers = [uri]::EscapeDataString('["' + $script:McVersion + '"]')
    $proj = Invoke-RestMethod "https://api.modrinth.com/v2/project/$slug" -Headers $h
    $lista = Invoke-RestMethod "https://api.modrinth.com/v2/project/$slug/version?loaders=$loaders&game_versions=$vers" -Headers $h
    $v = $lista | Where-Object { $_.version_type -eq 'release' } | Select-Object -First 1
    if (-not $v) { $v = $lista | Select-Object -First 1 }
    if (-not $v) { throw "No hay versiones de '$slug' para $($script:Loader) $($script:McVersion)." }
    $f = $v.files | Where-Object { $_.primary } | Select-Object -First 1
    if (-not $f) { $f = $v.files[0] }
    $side = 'both'
    if ($proj.client_side -eq 'required' -and $proj.server_side -eq 'unsupported') { $side = 'client' }
    elseif ($proj.client_side -eq 'unsupported' -and $proj.server_side -eq 'required') { $side = 'server' }
    $nombre = ($proj.title -replace '[^\x20-\x7E]', '').Trim() -replace '"', "'"
    $toml = @"
name = "$nombre"
filename = "$($f.filename)"
side = "$side"

[download]
url = "$($f.url)"
hash-format = "sha512"
hash = "$($f.hashes.sha512)"

[update]
[update.modrinth]
mod-id = "$($proj.id)"
version = "$($v.id)"
"@
    Escribir-Archivo (Join-Path $script:Raiz "mods/$($proj.slug).pw.toml") $toml
    "$nombre -> $($f.filename) [$side]"
    Reconstruir-Pack | Out-Null
}

function Quitar-Mod([string]$slug) {
    $r = Join-Path $script:Raiz "mods/$slug.pw.toml"
    if (Test-Path $r) { Remove-Item $r; "Quitado: $slug" } else { "No existe: $slug" }
    Reconstruir-Pack | Out-Null
}

