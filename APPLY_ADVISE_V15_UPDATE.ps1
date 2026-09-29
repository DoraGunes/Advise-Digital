$ErrorActionPreference='Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = 'C:\Users\ANL\Desktop\meta'
if(-not (Test-Path $target)){ throw "Hedef klasör bulunamadı: $target" }
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$backup=Join-Path $target ("backup-before-v15-"+$stamp)
New-Item -ItemType Directory -Force -Path $backup | Out-Null
foreach($rel in @('backend\src','mobile\lib','backend\package.json','backend\package-lock.json','mobile\pubspec.yaml','mobile\pubspec.lock')){
  $src=Join-Path $target $rel
  if(Test-Path $src){ $dst=Join-Path $backup $rel; $dir=Split-Path $dst -Parent; New-Item -ItemType Directory -Force -Path $dir | Out-Null; if((Get-Item $src).PSIsContainer){Copy-Item $src $dst -Recurse -Force}else{Copy-Item $src $dst -Force} }
}
Copy-Item (Join-Path $root 'backend\src\*') (Join-Path $target 'backend\src') -Force
Copy-Item (Join-Path $root 'mobile\lib\*') (Join-Path $target 'mobile\lib') -Force
Copy-Item (Join-Path $root 'backend\package.json') (Join-Path $target 'backend\package.json') -Force
Copy-Item (Join-Path $root 'backend\package-lock.json') (Join-Path $target 'backend\package-lock.json') -Force
Copy-Item (Join-Path $root 'mobile\pubspec.yaml') (Join-Path $target 'mobile\pubspec.yaml') -Force
Copy-Item (Join-Path $root 'mobile\pubspec.lock') (Join-Path $target 'mobile\pubspec.lock') -Force
Write-Host "V15 güncellemesi uygulandı. Yedek: $backup" -ForegroundColor Green
