# Xposter upload keystore generator
# Parollarni mashinada yaratadi, key.properties va KEYSTORE-INFO.txt yozadi.
$ErrorActionPreference = "Continue"
$root     = "D:\poster\buxoro_pos"
$keystore = Join-Path $root "android\app\upload-keystore.jks"
$keyprops = Join-Path $root "android\key.properties"
$info     = "D:\poster\KEYSTORE-INFO.txt"
$log      = "D:\poster\_play_build_log.txt"

function Log($m){ Add-Content -Path $log -Value ("[ks] " + $m) }

if (Test-Path $keystore) { Log "Keystore allaqachon mavjud: $keystore (qayta yaratilmadi)"; exit 0 }

# keytool ni topish
$kt = $null
$cands = @(
 "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe",
 "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe",
 "$env:ProgramFiles\Android\Android Studio\jre\bin\keytool.exe",
 "${env:ProgramFiles(x86)}\Android\Android Studio\jbr\bin\keytool.exe"
)
foreach($c in $cands){ if(Test-Path $c){ $kt=$c; break } }
if(-not $kt){ $cmd = Get-Command keytool -ErrorAction SilentlyContinue; if($cmd){ $kt=$cmd.Source } }
if(-not $kt){ Log "KEYTOOL-NOT-FOUND"; exit 2 }
Log "keytool: $kt"

# Tasodifiy parol (28 belgi, alfanumerik)
$chars = (48..57)+(65..90)+(97..122)
$rnd = New-Object System.Random
$storePass = -join (1..28 | ForEach-Object { [char]($chars[$rnd.Next(0,$chars.Length)]) })
$keyPass   = $storePass
$alias     = "upload"
$dname     = "CN=Xposter, OU=Mobile, O=Xposter, L=Bukhara, ST=Bukhara, C=UZ"

& $kt -genkeypair -v -keystore $keystore -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias $alias -dname $dname -storepass $storePass -keypass $keyPass 2>&1 | ForEach-Object { Log $_ }

if(-not (Test-Path $keystore)){ Log "KEYSTORE-CREATE-FAILED"; exit 3 }

$storeFileForGradle = $keystore -replace '\\','/'
$kp = "storePassword=$storePass`r`nkeyPassword=$keyPass`r`nkeyAlias=$alias`r`nstoreFile=$storeFileForGradle`r`n"
Set-Content -Path $keyprops -Value $kp -Encoding ASCII -NoNewline

$now = Get-Date
$infoText = @"
XPOSTER - UPLOAD KEYSTORE MA'LUMOTLARI
======================================
!!! MUHIM: Bu faylni xavfsiz joyda saqlang va ZAXIRA nusxa oling. !!!
Bu keystore yo'qolsa yoki parol unutilsa, ilovaga yangilanish
chiqara olmaysiz (yangi keystore = yangi ilova bo'lib qoladi).

Keystore fayli : $keystore
Alias          : $alias
Store parol    : $storePass
Key parol      : $keyPass
DName          : $dname
Algoritm       : RSA 2048, validity 10000 kun
Yaratilgan     : $now
key.properties : $keyprops
"@
Set-Content -Path $info -Value $infoText -Encoding UTF8

Log "KEYSTORE-OK"
exit 0
