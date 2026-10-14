param(
    [int]$Port = 3000
)

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try {
    $listener.Start()
} catch {
    Write-Host "Failed to start listener on port $Port : $_"
    exit 1
}

Write-Host "HTTP Server listening on http://localhost:$Port/"

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".mp3"  = "audio/mpeg"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".json" = "application/json"
}

$baseDir = $PSScriptRoot
if (-not $baseDir) { $baseDir = (Get-Location).Path }

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        [System.Threading.ThreadPool]::QueueUserWorkItem({
            param($state)
            $tcp = $state.client
            $base = $state.dir
            $types = $state.mimes

            try {
                $stream = $tcp.GetStream()
                $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)
                
                $requestLine = $reader.ReadLine()
                if (-not $requestLine) {
                    $tcp.Close()
                    return
                }

                $parts = $requestLine -split ' '
                if ($parts.Length -lt 2) {
                    $tcp.Close()
                    return
                }

                $method = $parts[0]
                $rawUrl = $parts[1]

                while ($true) {
                    $headerLine = $reader.ReadLine()
                    if ([string]::IsNullOrWhiteSpace($headerLine)) { break }
                }

                if ($method -ne "GET" -and $method -ne "HEAD") {
                    $msg = [System.Text.Encoding]::UTF8.GetBytes("HTTP/1.1 405 Method Not Allowed`r`nContent-Length: 0`r`nConnection: close`r`n`r`n")
                    $stream.Write($msg, 0, $msg.Length)
                    $stream.Flush()
                    $tcp.Close()
                    return
                }

                $urlPath = [System.Uri]::UnescapeDataString(($rawUrl -split '\?')[0])
                if ($urlPath -eq "/" -or $urlPath -eq "") {
                    $urlPath = "/index.html"
                }

                $relPath = $urlPath.TrimStart('/').Replace('/', '\')
                $fullPath = [System.IO.Path]::GetFullPath((Join-Path $base $relPath))

                if ($fullPath.StartsWith($base) -and (Test-Path $fullPath -PathType Leaf)) {
                    $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
                    $contentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
                    $bytes = [System.IO.File]::ReadAllBytes($fullPath)
                    $contentLength = $bytes.Length

                    $header = "HTTP/1.1 200 OK`r`n" +
                              "Content-Type: $contentType`r`n" +
                              "Content-Length: $contentLength`r`n" +
                              "Accept-Ranges: bytes`r`n" +
                              "Access-Control-Allow-Origin: *`r`n" +
                              "Connection: close`r`n`r`n"

                    $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($header)
                    $stream.Write($headerBytes, 0, $headerBytes.Length)
                    if ($method -eq "GET") {
                        $stream.Write($bytes, 0, $bytes.Length)
                    }
                    $stream.Flush()
                } else {
                    $body = "404 Not Found: $urlPath"
                    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                    $header = "HTTP/1.1 404 Not Found`r`n" +
                              "Content-Type: text/plain; charset=utf-8`r`n" +
                              "Content-Length: $($bodyBytes.Length)`r`n" +
                              "Connection: close`r`n`r`n"
                    $headerBytes = [System.Text.Encoding]::UTF8.GetBytes($header)
                    $stream.Write($headerBytes, 0, $headerBytes.Length)
                    $stream.Write($bodyBytes, 0, $bodyBytes.Length)
                    $stream.Flush()
                }
            } catch {
            } finally {
                try { $tcp.Close() } catch {}
            }
        }, @{ client = $client; dir = $baseDir; mimes = $mimeTypes })
    }
} finally {
    $listener.Stop()
}
