#!/usr/bin/env python3
"""Serveur MJPEG pour caméra Raspberry Pi - Projet CERBÈRE"""
import io
import subprocess
import threading
import time
from http import server
from urllib.parse import urlparse

BOUNDARY = b'--frameboundary'

class StreamOutput:
    def __init__(self):
        self.frame = None
        self.condition = threading.Condition()

    def write(self, frame):
        with self.condition:
            self.frame = frame
            self.condition.notify_all()

output = StreamOutput()

def capture_frames():
    cmd = [
        'ffmpeg',
        '-f', 'v4l2',
        '-input_format', 'mjpeg',
        '-video_size', '1280x720',
        '-framerate', '25',
        '-i', '/dev/video0',
        '-vf', 'scale=1280:720',
        '-vcodec', 'mjpeg',
        '-q:v', '5',
        '-f', 'mjpeg',
        'pipe:1'
    ]
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
    buf = b''
    while True:
        chunk = proc.stdout.read(65536)
        if not chunk:
            break
        buf += chunk
        while True:
            start = buf.find(b'\xff\xd8')
            end = buf.find(b'\xff\xd9', start + 2) if start != -1 else -1
            if start != -1 and end != -1:
                frame = buf[start:end + 2]
                output.write(frame)
                buf = buf[end + 2:]
            else:
                break

class StreamHandler(server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass  # Silence les logs

    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/snapshot':
            with output.condition:
                output.condition.wait(timeout=5)
                frame = output.frame
            if frame:
                self.send_response(200)
                self.send_header('Content-Type', 'image/jpeg')
                self.send_header('Content-Length', str(len(frame)))
                self.send_header('Cache-Control', 'no-cache')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(frame)
            else:
                self.send_response(503)
                self.end_headers()
        elif path == '/stream':
            self.send_response(200)
            self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frameboundary')
            self.send_header('Cache-Control', 'no-cache')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            try:
                while True:
                    with output.condition:
                        output.condition.wait(timeout=5)
                        frame = output.frame
                    if frame:
                        self.wfile.write(b'--frameboundary\r\n')
                        self.wfile.write(b'Content-Type: image/jpeg\r\n')
                        self.wfile.write(f'Content-Length: {len(frame)}\r\n\r\n'.encode())
                        self.wfile.write(frame)
                        self.wfile.write(b'\r\n')
                        self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass
        elif path == '/' or path == '/index.html':
            html = b"""<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>CERB\xc3\x88RE - Flux Cam\xc3\xa9ra</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { background:#0d1117; color:#e6edf3; font-family:Arial,sans-serif; display:flex; flex-direction:column; align-items:center; min-height:100vh; }
  header { width:100%; background:#161b22; padding:16px 24px; border-bottom:1px solid #30363d; display:flex; align-items:center; gap:12px; }
  header h1 { font-size:1.2rem; letter-spacing:2px; }
  .badge { background:#238636; color:#fff; padding:3px 10px; border-radius:12px; font-size:.75rem; }
  .badge.offline { background:#da3633; }
  .container { padding:24px; width:100%; max-width:1300px; }
  .camera-box { background:#161b22; border:1px solid #30363d; border-radius:10px; overflow:hidden; }
  .camera-header { padding:12px 20px; background:#1c2128; border-bottom:1px solid #30363d; display:flex; justify-content:space-between; align-items:center; }
  .dot { width:10px; height:10px; border-radius:50%; background:#3fb950; display:inline-block; margin-right:8px; animation:blink 1.5s infinite; }
  @keyframes blink { 0%,100%{opacity:1} 50%{opacity:.3} }
  img#feed { width:100%; display:block; background:#000; min-height:400px; }
  .info { padding:12px 20px; background:#1c2128; border-top:1px solid #30363d; font-size:.8rem; color:#8b949e; display:flex; justify-content:space-between; }
  a.btn { display:inline-block; margin-top:16px; padding:8px 20px; background:#1f6feb; border-radius:6px; color:#fff; text-decoration:none; font-size:.85rem; }
</style>
</head>
<body>
<header>
  <h1>&#128274; CERB\xc3\x88RE</h1>
  <span class="badge" id="status">LIVE</span>
</header>
<div class="container">
  <div class="camera-box">
    <div class="camera-header">
      <div><span class="dot"></span>Cam\xc3\xa9ra CSI - Raspberry Pi</div>
      <div style="font-size:.8rem;color:#8b949e;" id="time"></div>
    </div>
    <img id="feed" src="/stream" alt="Flux cam\xc3\xa9ra" onerror="this.style.opacity='.3'" />
    <div class="info">
      <span>1280x720 &bull; 25 fps &bull; MJPEG</span>
      <span>192.168.1.199:8090</span>
    </div>
  </div>
  <a class="btn" href="http://192.168.1.199/admin_cerbere.html">&#8592; Retour au panneau admin</a>
</div>
<script>
  function tick(){ document.getElementById('time').textContent = new Date().toLocaleTimeString('fr-FR'); }
  setInterval(tick, 1000); tick();
  document.getElementById('feed').addEventListener('error', function(){
    document.getElementById('status').textContent='HORS LIGNE';
    document.getElementById('status').className='badge offline';
  });
</script>
</body>
</html>"""
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(html))
            self.end_headers()
            self.wfile.write(html)
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    t = threading.Thread(target=capture_frames, daemon=True)
    t.start()
    time.sleep(1)
    httpd = server.HTTPServer(('0.0.0.0', 8090), StreamHandler)
    print('Stream disponible sur http://192.168.1.199:8090')
    httpd.serve_forever()
