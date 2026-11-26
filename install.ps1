<#
.SYNOPSIS
  Instala o Vice City Home numa Android TV / Google TV pela rede (ADB).

.DESCRIPTION
  Por padrao instala o launcher como um APP COMUM e aplica o tema. A tela inicial da TV nao muda.
  Com -SetAsHome ele vira a tela inicial. Essa etapa desativa (nao desinstala) a tela inicial do Google,
  pede confirmacao e deixa um desfazer automatico rodando dentro da TV.

.EXAMPLE
  .\install.ps1 -TvIp 192.168.1.50
.EXAMPLE
  .\install.ps1 -TvIp 192.168.1.50 -Name "Alex" -SetAsHome
#>
param(
    [Parameter(Mandatory = $true)][string]$TvIp,
    [string]$Name = '',
    [string]$Apk = '',
    [switch]$SetAsHome
)

# 'Continue': no PowerShell 5.1, avisos do adb no stderr nao podem abortar o script; os erros sao conferidos um a um.
$ErrorActionPreference = 'Continue'
$Package = 'com.vicecity.home'
$Activity = "$Package/com.gathin.tvhome.MainActivity"
$ReleaseUrl = 'https://github.com/VictorGazarini/vice-city-tv-launcher/releases/latest/download/vice-city-home.apk'
$KnownStock = @('com.google.android.apps.tv.launcherx', 'com.google.android.tvlauncher')
$Wraith = 'com.google.android.tungsten.setupwraith'

function Step($text) { Write-Host "`n==> $text" -ForegroundColor Magenta }
function Fail($text) { Write-Host "`nERRO: $text" -ForegroundColor Red; exit 1 }

$NamePattern = '^[\p{L}\p{N} .\-]{1,30}$'
$NameRules = 'use apenas letras, numeros, espaco, ponto ou hifen (ate 30).'
if ($Name -and $Name -notmatch $NamePattern) { Fail "Em -Name $NameRules" }
# Sem -Name e num terminal interativo: pergunta. Com entrada redirecionada nao pergunta, para nao consumir outra resposta.
if (-not $PSBoundParameters.ContainsKey('Name') -and -not [Console]::IsInputRedirected) {
    do {
        $Name = "$(Read-Host 'Qual nome deve aparecer na saudacao da TV? (Enter para nenhum)')".Trim()
        $valid = (-not $Name) -or ($Name -match $NamePattern)
        if (-not $valid) { Write-Host "Nome invalido: $NameRules" -ForegroundColor Yellow }
    } until ($valid)
}

$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) { Fail 'ADB nao encontrado. Instale com:  winget install Google.PlatformTools  e abra um novo terminal.' }

$serial = if ($TvIp -match ':\d+$') { $TvIp } else { "${TvIp}:5555" }
function Adb { & $adb -s $serial @args }
function Sh([string]$command) { (& $adb -s $serial shell $command) -join "`n" }
function CurrentHome {
    ((Sh 'cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME') -split "`n")[-1].Trim()
}

Step "Conectando em $serial (aceite o aviso de depuracao na TV, se aparecer)"
& $adb connect $serial | Out-Host
Start-Sleep -Seconds 2
if ((& $adb -s $serial get-state 2>$null) -ne 'device') { Fail 'A TV nao autorizou a conexao. Confira o IP e a Depuracao de rede.' }

$sdk = [int](Sh 'getprop ro.build.version.sdk').Trim()
if ($sdk -lt 26) { Fail "Este launcher exige Android 8 ou superior (a TV informa API $sdk)." }
Write-Host "TV: $((Sh 'getprop ro.product.model').Trim()) / Android $((Sh 'getprop ro.build.version.release').Trim())"

if (-not $Apk) {
    Step 'Baixando o APK da ultima release'
    $Apk = Join-Path $env:TEMP 'vice-city-home.apk'
    try { Invoke-WebRequest $ReleaseUrl -OutFile $Apk -UseBasicParsing -ErrorAction Stop }
    catch { Fail 'Nao consegui baixar o APK. Baixe-o na pagina de Releases e use -Apk caminho\vice-city-home.apk' }
}
if (-not (Test-Path $Apk)) { Fail "APK nao encontrado: $Apk" }

Step 'Instalando o launcher'
Adb install -r $Apk | Out-Host
if ($LASTEXITCODE -ne 0) { Fail 'A instalacao falhou.' }

Step 'Aplicando o tema'
Adb shell "am start -n $Activity >/dev/null" | Out-Null
Start-Sleep -Seconds 3
$config = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'theme\config.json'))
$config = $config.Replace('"greeting_name":""', '"greeting_name":"' + $Name + '"')
$tmp = Join-Path $env:TEMP 'vice-city-config.json'
[IO.File]::WriteAllText($tmp, $config, (New-Object Text.UTF8Encoding $false))
# O provedor do launcher espera o nome wallpaper.jpg (o conteudo PNG e reconhecido normalmente).
foreach ($pair in @(@($tmp, 'config.json'), @((Join-Path $PSScriptRoot 'theme\wallpaper.png'), 'wallpaper.jpg'))) {
    Adb push $pair[0] "/data/local/tmp/vc-$($pair[1])" | Out-Null
    Adb shell "content write --uri content://$Package.theme/$($pair[1]) < /data/local/tmp/vc-$($pair[1]); rm -f /data/local/tmp/vc-$($pair[1])"
}
Adb shell "am force-stop $Package; sleep 2; am start -n $Activity >/dev/null"

if (-not $SetAsHome) {
    Write-Host "`nPronto! O launcher foi instalado como app comum e esta aberto na TV." -ForegroundColor Green
    Write-Host 'Teste com o controle. Para torna-lo a tela inicial, rode de novo com -SetAsHome.'
    exit 0
}

Step 'Verificacoes de seguranca antes de trocar a tela inicial'
$before = CurrentHome
if ($before -like "$Package/*") { Write-Host 'Ele ja e a tela inicial.' -ForegroundColor Green; exit 0 }
$stock = $before.Split('/')[0]
if ($KnownStock -notcontains $stock) { Fail "Tela inicial atual nao suportada pelo instalador: '$before'. Nada foi alterado na tela inicial." }

# Em Google TVs, desativar o setupwraith pode APAGAR redes Wi-Fi criadas por ele.
$dump = (Adb shell dumpsys wifi) -join "`n"
$block = [regex]::Match($dump, '(?s)Configured networks Begin(.*?)Configured networks End').Groups[1].Value
if (-not $block) { Fail 'Nao consegui verificar quem criou a rede Wi-Fi. Por seguranca, a tela inicial nao foi alterada.' }
$networks = [regex]::Split($block, '(?m)(?=^\s*\*?\s*ID: \d+ SSID:)') | Where-Object { $_ -match 'ID: \d+ SSID:' }
$active = @($networks | Where-Object { $_ -match 'Currently Connected: true' })
if ((Sh "pm list packages $Wraith") -match [regex]::Escape($Wraith)) {
    if ($active.Count -ne 1) { Fail 'Nao identifiquei a rede Wi-Fi em uso (TV no cabo ou formato diferente). Veja a instalacao manual no README.' }
    if ($active[0] -match 'cname=com\.google\.android\.tungsten\.setupwraith') {
        Fail 'A rede em uso foi criada pelo assistente inicial. Na TV, ESQUECA a rede, conecte de novo por Configuracoes > Rede e rode o instalador outra vez.'
    }
}

Write-Host @"

ATENCAO
 - A tela inicial do Google sera DESATIVADA (nao desinstalada) e, se preciso, tambem a de recuperacao.
 - Redes Wi-Fi antigas criadas pelo assistente inicial podem ser apagadas.
 - Alguns botoes de atalho do controle (ex.: YouTube) podem parar de funcionar.
 - No pior caso, se a TV nao voltar a aceitar o ADB, pode ser necessario restaurar de fabrica.
 - Mantenha a depuracao ligada ate confirmar que tudo funciona.
"@ -ForegroundColor Yellow
if ((Read-Host 'Digite SIM para continuar') -cne 'SIM') { Write-Host 'Cancelado. A tela inicial nao foi alterada.'; exit 0 }

Step 'Trocando a tela inicial (com desfazer automatico em 150 segundos)'
$restore = "pm enable --user 0 $stock`n"
if ((Sh "pm list packages -e $Wraith") -match [regex]::Escape($Wraith)) { $restore += "pm enable --user 0 $Wraith`n" }
$restore += "cmd package set-home-activity --user 0 $before`ninput keyevent KEYCODE_HOME`n"
$swap = @"
NEW=$Activity
res() { cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1; }
rm -f /data/local/tmp/vc_ok
nohup sh -c 'sleep 150; [ -f /data/local/tmp/vc_ok ] || sh /data/local/tmp/vc_restore.sh' >/dev/null 2>&1 &
pm disable-user --user 0 $stock
sleep 3
cmd package set-home-activity --user 0 `$NEW
sleep 3
case "`$(res)" in
  *setupwraith*) pm disable-user --user 0 $Wraith; sleep 3; cmd package set-home-activity --user 0 `$NEW; sleep 3 ;;
esac
input keyevent KEYCODE_HOME
sleep 6
echo "home=`$(res)"
"@
$utf8 = New-Object Text.UTF8Encoding $false
foreach ($file in @(@('vc_restore.sh', $restore), @('vc_swap.sh', $swap))) {
    $local = Join-Path $env:TEMP $file[0]
    [IO.File]::WriteAllText($local, ($file[1] -replace "`r", '') + "`n", $utf8)
    Adb push $local "/data/local/tmp/$($file[0])" | Out-Null
}
Adb shell sh /data/local/tmp/vc_swap.sh | Out-Host

& $adb disconnect $serial | Out-Null
& $adb connect $serial | Out-Null
Start-Sleep -Seconds 3
$after = ''
try { $after = CurrentHome } catch {}
if ($after -like "$Package/*") {
    Adb shell touch /data/local/tmp/vc_ok
    Write-Host "`nPronto! O Vice City Home e a nova tela inicial." -ForegroundColor Green
    Write-Host 'Teste o botao Home, reinicie a TV e confira. Para voltar atras:  .\restore.ps1 -TvIp <ip>'
    Write-Host 'Quando terminar, DESLIGUE a depuracao na TV.'
}
else {
    Adb shell "sh /data/local/tmp/vc_restore.sh; touch /data/local/tmp/vc_ok" | Out-Null
    Fail "A troca nao foi confirmada (Home: '$after'). A tela original foi restaurada. Se a TV estiver sem conexao, o desfazer automatico roda sozinho."
}
