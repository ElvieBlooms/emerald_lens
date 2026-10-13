# Serves the tools folder to this computer only, for the sprite tools page.
# Windows PowerShell 5.1 (built into Windows 10 and 11); nothing to install.
# Started by "Start sprite tools (Windows).bat". -Elvie
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path.TrimEnd('\', '/')
$sep = [IO.Path]::DirectorySeparatorChar
$types = @{
  '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'
  '.js' = 'text/javascript'; '.mjs' = 'text/javascript'; '.json' = 'application/json'
  '.png' = 'image/png'; '.gif' = 'image/gif'; '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.webp' = 'image/webp'
  '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon'; '.wasm' = 'application/wasm'; '.zip' = 'application/zip'
  '.whl' = 'application/zip'; '.py' = 'text/plain; charset=utf-8'; '.md' = 'text/plain; charset=utf-8'
  '.txt' = 'text/plain; charset=utf-8'; '.ttf' = 'font/ttf'; '.woff2' = 'font/woff2'
}

$listener = $null
foreach ($p in 8765..8790) {
  $l = New-Object System.Net.HttpListener
  $l.Prefixes.Add("http://localhost:$p/")
  try { $l.Start(); $listener = $l; $port = $p; break } catch { $l.Close() }
}
if (-not $listener) {
  Write-Host "Couldn't find a free port between 8765 and 8790. Close other copies of this window and try again."
  exit 1
}

$url = "http://localhost:$port/web/"
Write-Host ''
Write-Host '  Emerald Lens sprite tools'
Write-Host "  Open $url in your browser (it should open by itself)."
Write-Host '  Leave this window open while you use the tools; close it to stop.'
Write-Host ''
try { Start-Process $url } catch { }

function Send($res, $code, $type, [byte[]]$bytes, $head) {
  $res.StatusCode = $code
  $res.ContentType = $type
  $res.Headers.Add('Cache-Control', 'no-cache')
  $res.ContentLength64 = $bytes.Length
  if (-not $head) { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
}

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    try {
      $head = $req.HttpMethod -eq 'HEAD'
      $notFound = [Text.Encoding]::UTF8.GetBytes('Not found')
      $path = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
      $parts = @($path.Split('/') | Where-Object { $_ -ne '' })
      if (@($parts | Where-Object { $_ -eq '..' -or $_.StartsWith('.') -or $_ -match '[\\:]' }).Count -gt 0) {
        Send $res 404 'text/plain' $notFound $head
        continue
      }
      $full = $root
      foreach ($part in $parts) { $full = $full + $sep + $part }
      if (Test-Path -LiteralPath $full -PathType Container) {
        if (-not $path.EndsWith('/')) {
          $res.StatusCode = 301
          $res.RedirectLocation = "$path/"
          continue
        }
        $full = $full + $sep + 'index.html'
      }
      if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Send $res 404 'text/plain' $notFound $head
        continue
      }
      $ext = [IO.Path]::GetExtension($full).ToLower()
      $type = 'application/octet-stream'
      if ($types.ContainsKey($ext)) { $type = $types[$ext] }
      Send $res 200 $type ([IO.File]::ReadAllBytes($full)) $head
    } catch {
      try { $res.StatusCode = 500 } catch { }
    } finally {
      $res.Close()
    }
  }
} finally {
  $listener.Stop()
}
