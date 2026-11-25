[CmdletBinding()]
param([string]$MySqlBin, [switch]$Detener, [switch]$Recompilar)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$backend = Join-Path $root 'Proyecto_Springboot_Microservicios\proyecto'
$frontend = Join-Path $root 'Nexus_React'
$state = Join-Path $root '.nexus-local'
$log = Join-Path $state 'logs'
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.Directory]::CreateDirectory($log) | Out-Null
$servicePorts = [ordered]@{'eureka-server'=8761;'ms-usuarios'=8081;'ms-auth'=8083;'ms-productos'=8082;
    'ms-pedidos'=8084;'ms-pagos'=8085;'ms-envios'=8086;'ms-inventario'=8087;'ms-notificaciones'=8088;
    'ms-resenas'=8089;'ms-cupones'=8090;'api-gateway'=8080}
function Get-OwnedProcess($name) {
    $file = Join-Path $state "$name.pid.json"
    if (!(Test-Path -LiteralPath $file)) { return }
    $record = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json
    $proc = Get-Process -Id $record.id -ErrorAction SilentlyContinue
    if ($proc -and $proc.StartTime.ToUniversalTime().Ticks.ToString() -eq $record.started) { return $proc }
}
function Test-Port($port) {
    $tcp = New-Object Net.Sockets.TcpClient
    try { return $tcp.ConnectAsync('127.0.0.1', $port).Wait(250) -and $tcp.Connected }
    catch { return $false } finally { $tcp.Dispose() }
}
function Start-Owned($name, $exe, $arguments, $dir, $port) {
    $proc = Get-OwnedProcess $name
    if (!$proc) {
        if (Test-Port $port) { throw "Puerto $port ocupado por otro programa ($name)." }
        $proc = Start-Process -FilePath $exe -ArgumentList $arguments -WorkingDirectory $dir -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $log "$name.out") -RedirectStandardError (Join-Path $log "$name.err")
        $record = @{id=$proc.Id; started=$proc.StartTime.ToUniversalTime().Ticks.ToString()}
        [IO.File]::WriteAllText((Join-Path $state "$name.pid.json"), ($record | ConvertTo-Json), $utf8)
    }
    for ($i=0; $i -lt 100; $i++) {
        if ($proc.HasExited) { throw "No pudo iniciar $name. Revisa $log\$name.err y $name.out." }
        if (Test-Port $port) { return }
        Start-Sleep -Milliseconds 700
    }
    throw "Tiempo de espera agotado para $name. Revisa $log."
}
if ($Detener) {
    $names = @('frontend') + @($servicePorts.Keys) + @('mysql')
    foreach ($name in $names) {
        $proc = Get-OwnedProcess $name
        if ($proc) {
            if ($name -eq 'mysql') {
                $cfg = Get-Content -LiteralPath (Join-Path $state 'config.json') -Raw | ConvertFrom-Json
                $env:MYSQL_PWD = $cfg.dbPassword
                try { & (Join-Path (Split-Path $proc.Path) 'mysqladmin.exe') --no-defaults --protocol=TCP "--host=127.0.0.1" "--port=33307" "--user=root" shutdown }
                finally { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue }
            } else { Stop-Process -InputObject $proc }
            if (!$proc.WaitForExit(30000)) { throw "El proceso $name aun se esta deteniendo." }
        }
    }
    Write-Host 'Nexus detenido. Los datos quedan en .nexus-local.'
    return
}
if ($Recompilar) { & $PSCommandPath -Detener }
if (!(Test-Path (Join-Path $backend 'pom.xml')) -or !(Test-Path (Join-Path $frontend 'package.json'))) {
    throw 'Inicializa los submodulos con git submodule update --init --recursive.'
}
if (!$env:JAVA_HOME -or !(Test-Path "$env:JAVA_HOME\release") -or !(Select-String -Quiet -Path "$env:JAVA_HOME\release" -Pattern 'JAVA_VERSION="25[."]')) {
    $candidate = Get-ChildItem "$env:ProgramFiles\Eclipse Adoptium\jdk-25*" -Directory -ErrorAction SilentlyContinue | Select-Object -Last 1
    if (!$candidate) { throw 'Configura JAVA_HOME con un JDK 25.' }
    $env:JAVA_HOME = $candidate.FullName
}
$java = Join-Path $env:JAVA_HOME 'bin\java.exe'
$node = (Get-Command node.exe -ErrorAction Stop).Source
$configFile = Join-Path $state 'config.json'
function New-Secret {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return [BitConverter]::ToString($bytes).Replace('-','').ToLowerInvariant()
}
if (!(Test-Path $configFile)) {
    $cfg = @{dbPassword=(New-Secret); jwt=(New-Secret); adminEmail='admin@nexus.local'; adminPassword=(New-Secret)}
    [IO.File]::WriteAllText($configFile, ($cfg | ConvertTo-Json), $utf8)
}
$cfg = Get-Content -Raw -LiteralPath $configFile | ConvertFrom-Json
$previousBin = Join-Path $state 'mysql-bin.txt'
if (!$MySqlBin -and (Test-Path -LiteralPath $previousBin)) {
    $savedBin = (Get-Content -LiteralPath $previousBin -Raw).Trim()
    if (Test-Path -LiteralPath (Join-Path $savedBin 'mysqld.exe')) { $MySqlBin = $savedBin }
}
if (!$MySqlBin) {
    $MySqlBin = "$env:ProgramFiles\MySQL\MySQL Server 8.4\bin"
    if (!(Test-Path "$MySqlBin\mysqld.exe")) {
        $MySqlBin = Join-Path $state 'mysql-8.4.7-winx64\bin'
        if (!(Test-Path "$MySqlBin\mysqld.exe")) {
            $zip = Join-Path $state 'mysql-8.4.7-winx64.zip'
            $uri = 'https://cdn.mysql.com/archives/mysql-8.4/mysql-8.4.7-winx64.zip'
            & curl.exe --fail --location --silent --show-error --output $zip $uri
            if ($LASTEXITCODE -ne 0 -or (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne 'FD9BDBD4B5A878D31C8E4067078BD60665B1B3C4677FA1F099416D194B458AFF') { throw 'Descarga de MySQL incompleta o incorrecta.' }
            Expand-Archive -LiteralPath $zip -DestinationPath $state -Force
        }
    }
}
$mysqld = (Get-Item -LiteralPath "$MySqlBin\mysqld.exe").FullName
$MySqlBin = Split-Path $mysqld -Parent
[IO.File]::WriteAllText($previousBin,$MySqlBin,$utf8)
$mysqlBase = Split-Path $MySqlBin -Parent
$data = Join-Path $state 'mysql-data'
if (!(Test-Path -LiteralPath (Join-Path $data 'mysql'))) {
    [IO.Directory]::CreateDirectory($data) | Out-Null
    & $mysqld --no-defaults --initialize-insecure "--basedir=$mysqlBase" "--datadir=$data" --console
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo inicializar la instancia local de MySQL.' }
}
$bootstrap = Join-Path $state 'mysql-init.sql'
$sql = "ALTER USER 'root'@'localhost' IDENTIFIED BY '$($cfg.dbPassword)';" + [Environment]::NewLine + (Get-Content -Raw -Encoding UTF8 (Join-Path $backend 'docker\mysql\init.sql'))
[IO.File]::WriteAllText($bootstrap,$sql,$utf8)
Start-Owned 'mysql' $mysqld @('--no-defaults', "--basedir=`"$mysqlBase`"", "--datadir=`"$data`"", "--init-file=`"$bootstrap`"", '--port=33307','--bind-address=127.0.0.1','--mysqlx=OFF','--innodb-buffer-pool-size=96M','--console') $root 33307
$env:MYSQL_PWD = $cfg.dbPassword
try {
    & (Join-Path $MySqlBin 'mysql.exe') --no-defaults --protocol=TCP "--host=127.0.0.1" "--port=33307" "--user=root" -N -e 'SELECT 1' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'MySQL aun no acepta la cuenta del proyecto.' }
} finally { Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue }
Remove-Item -LiteralPath $bootstrap -ErrorAction SilentlyContinue
$jars = @{}
foreach ($m in $servicePorts.Keys) {
    $jars[$m] = Join-Path $backend "$m\target\$m-0.0.1-SNAPSHOT.jar"
}
if ($Recompilar -or @($jars.Values | Where-Object { !(Test-Path $_) }).Count) {
    $maven = Get-Command mvn.cmd -ErrorAction SilentlyContinue
    if (!$maven) { $maven = Get-ChildItem "$env:USERPROFILE\.maven\apache-maven-*\bin\mvn.cmd" -ErrorAction SilentlyContinue | Select-Object -Last 1 }
    if (!$maven) { throw 'Instala Maven 3.9 o agrega mvn.cmd a PATH.' }
    $mvnPath = if ($maven.Source) { $maven.Source } else { $maven.FullName }
    Push-Location $backend
    try { & $mvnPath -B -ntp package '-Dmaven.test.skip=true'; if ($LASTEXITCODE -ne 0) { throw 'Fallo el build Maven.' } }
    finally { Pop-Location }
}
$env:VITE_API_BASE_URL='/'
Push-Location $frontend
try {
    if (!(Test-Path 'node_modules\vite\bin\vite.js')) { & npm.cmd ci; if ($LASTEXITCODE -ne 0) { throw 'Fallo npm ci.' } }
    if ($Recompilar -or !(Test-Path 'dist\index.html')) { & npm.cmd run build; if ($LASTEXITCODE -ne 0) { throw 'Fallo el build React.' } }
} finally { Pop-Location }
$env:JWT_SECRET=$cfg.jwt
$env:SPRING_PROFILES_ACTIVE='dev'
$env:EUREKA_DEFAULT_ZONE='http://127.0.0.1:8761/eureka/'
$env:EUREKA_INSTANCE_IP_ADDRESS='127.0.0.1'
$env:EUREKA_INSTANCE_PREFER_IP_ADDRESS='true'
$env:SERVER_ADDRESS='127.0.0.1'
$env:SPRING_DATASOURCE_USERNAME='root'
$env:SPRING_DATASOURCE_PASSWORD=$cfg.dbPassword
foreach ($m in $servicePorts.Keys) {
    $port = $servicePorts[$m]
    if ($m -like 'ms-*') {
        $schema = if ($m -eq 'ms-auth') { 'db_usuario' } else { 'db_' + $m.Substring(3) }
        $env:SPRING_DATASOURCE_URL="jdbc:mysql://127.0.0.1:33307/$schema"
    }
    if ($m -eq 'ms-auth') { $env:NEXUS_ADMIN_EMAIL=$cfg.adminEmail; $env:NEXUS_ADMIN_PASSWORD=$cfg.adminPassword }
    if ($m -eq 'ms-productos') { $env:NEXUS_CATALOGO_INICIAL='true' }
    Write-Host "Iniciando $m ($port)"
    Start-Owned $m $java @('-Xms32m','-Xmx192m','-XX:ActiveProcessorCount=2','-jar', ('"' + $jars[$m] + '"')) $backend $port
    Remove-Item Env:NEXUS_ADMIN_EMAIL,Env:NEXUS_ADMIN_PASSWORD,Env:NEXUS_CATALOGO_INICIAL -ErrorAction SilentlyContinue
}
Start-Owned 'frontend' $node @('node_modules/vite/bin/vite.js','preview','--host','127.0.0.1','--port','5173','--strictPort') $frontend 5173
for ($i=0; $i -lt 90; $i++) {
    try { $null=Invoke-RestMethod 'http://127.0.0.1:5173/api/v1/productos' -TimeoutSec 3; Write-Host 'Nexus disponible en http://127.0.0.1:5173'; return }
    catch { Start-Sleep -Seconds 2 }
}
throw "El Gateway aun no alcanza el catalogo. Revisa $log."
