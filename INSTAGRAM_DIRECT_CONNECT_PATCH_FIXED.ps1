$ErrorActionPreference = 'Stop'

$root = 'C:\Users\ANL\Desktop\meta'
$server = Join-Path $root 'backend\src\server.js'
$api = Join-Path $root 'mobile\lib\api.dart'
$pages = Join-Path $root 'mobile\lib\v78_pages.dart'

foreach ($p in @($server,$api,$pages)) {
    if (-not (Test-Path $p)) { throw "Dosya bulunamadı: $p" }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $root ("backup-instagram-direct-" + $stamp)
New-Item -ItemType Directory -Force -Path $backup | Out-Null

Copy-Item $server (Join-Path $backup 'server.js') -Force
Copy-Item $api    (Join-Path $backup 'api.dart') -Force
Copy-Item $pages  (Join-Path $backup 'v78_pages.dart') -Force

$utf8 = New-Object System.Text.UTF8Encoding($false)

# 1) Backend: replace the old Facebook OAuth start endpoint with a
#    server-side bootstrap using the already verified Instagram token in .env.
$text = [System.IO.File]::ReadAllText($server)
$start = $text.IndexOf("app.get('/api/meta/connect/start'")
$end   = $text.IndexOf("app.get('/api/meta/oauth/callback'", $start)

if ($start -lt 0 -or $end -lt 0) {
    throw "server.js içindeki Meta connect start/callback sınırları bulunamadı."
}

$newRoute = @"
app.get('/api/meta/connect/start', allowRoles('ADMIN'), async (req, res) => {
  try {
    const igToken = String(process.env.INSTAGRAM_ACCESS_TOKEN || '').trim();
    const configuredIgId = String(process.env.INSTAGRAM_USER_ID || '').trim();
    const pageId = String(process.env.META_PAGE_ID || config.metaPageId || '').trim();
    const businessId = String(process.env.META_BUSINESS_ID || config.metaBusinessId || '').trim();
    const rawAdAccount = String(process.env.META_AD_ACCOUNT_ID || config.adAccountId || '').trim();
    const adAccountId = rawAdAccount.replace(/^act_/, '');

    if (!igToken || !configuredIgId) {
      return res.status(503).json({
        error: 'Instagram bağlantısı için INSTAGRAM_ACCESS_TOKEN ve INSTAGRAM_USER_ID .env içinde bulunmalı.'
      });
    }

    const igUrl = new URL('https://graph.instagram.com/me');
    igUrl.searchParams.set('fields', 'id,username');
    igUrl.searchParams.set('access_token', igToken);

    const igResp = await fetch(igUrl);
    const igData = JSON.parse(await igResp.text());

    if (!igResp.ok || igData.error) {
      return res.status(401).json({
        error: igData.error?.message || 'Instagram access token doğrulanamadı.'
      });
    }

    const instagramUserId = String(igData.id || configuredIgId);
    const instagramUsername = String(igData.username || '');

    const metaPatch = {
      connected: true,
      source: 'INSTAGRAM_ENV',
      accessToken: igToken,
      adAccountId,
      pageId,
      instagramUserId,
      instagramUsername,
      businessId,
      connectedAt: new Date().toISOString()
    };

    await updateTenant(req.user.tenantId, { meta: metaPatch });

    await addLog(req.user.tenantId, {
      type: 'META_CONNECTED',
      source: 'INSTAGRAM_ENV',
      adAccountId,
      instagramUserId
    });

    res.json({
      connected: true,
      source: metaPatch.source,
      adAccountId,
      pageId,
      instagramUserId,
      instagramUsername,
      businessId,
      connectedAt: metaPatch.connectedAt
    });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});

"@

$text = $text.Substring(0, $start) + $newRoute + $text.Substring($end)
[System.IO.File]::WriteAllText($server, $text, $utf8)

# 2) Flutter API: same public method name, but now it asks the backend
#    to perform the verified Instagram bootstrap instead of opening Facebook OAuth.
$text = [System.IO.File]::ReadAllText($api)
$start = $text.IndexOf("static Future<String> metaConnectStart() async {")
$end   = $text.IndexOf("static Future<void> metaDisconnect()", $start)

if ($start -lt 0 -or $end -lt 0) {
    throw "api.dart içindeki metaConnectStart/metaDisconnect sınırları bulunamadı."
}

$newMethod = @"
static Future<Map<String, dynamic>> metaConnectStart() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/meta/connect/start'));

"@

$text = $text.Substring(0, $start) + $newMethod + $text.Substring($end)
[System.IO.File]::WriteAllText($api, $text, $utf8)

# 3) Flutter UI: no browser/Facebook launch. It calls the backend and refreshes status.
$text = [System.IO.File]::ReadAllText($pages)
$start = $text.IndexOf("Future<void> _connect() async {")
$end   = $text.IndexOf("Future<void> _disconnect() async {", $start)

if ($start -lt 0 -or $end -lt 0) {
    throw "v78_pages.dart içindeki _connect/_disconnect sınırları bulunamadı."
}

$newConnect = @"
Future<void> _connect() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await Api.metaConnectStart();
      await _load();
      if (mounted) {
        final username = _text(result['instagramUsername'], result['instagramUserId'] ?? 'Instagram');
        _snack(result['connected'] == true
            ? 'Instagram bağlandı: $username'
            : 'Instagram bağlantısı kurulamadı.');
      }
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

"@

$text = $text.Substring(0, $start) + $newConnect + $text.Substring($end)
[System.IO.File]::WriteAllText($pages, $text, $utf8)

Write-Host ''
Write-Host 'INSTAGRAM DIRECT CONNECT PATCH TAMAMLANDI.' -ForegroundColor Green
Write-Host "Yedek: $backup" -ForegroundColor DarkGray
Write-Host ''
Write-Host 'SIMDI:' -ForegroundColor Cyan
Write-Host '1) Backend CMD: Ctrl+C, sonra npm.cmd start'
Write-Host '2) Flutter klasorunde: flutter pub get'
Write-Host '3) Uygulamayi yeniden calistir / APK yeniden derle'
Write-Host '4) Meta & Instagram > INSTAGRAM bagla > yenile'
Write-Host ''
Write-Host 'NOT: Bu gecici bootstrap ADMIN icindir ve .env icindeki zaten dogrulanmis Instagram tokenini kullanir. Musteri OAuthu daha sonra ayrica kurulabilir.' -ForegroundColor Yellow
