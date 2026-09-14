param(
    [string]$RouterHost = "192.168.100.1",
    [string]$User = "root"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$archive = Join-Path $env:TEMP "luci-app-campus-auth.tar"
$askpass = Join-Path $env:TEMP "luci-app-campus-auth-askpass.cmd"
$batch = Join-Path $env:TEMP "luci-app-campus-auth-deploy.cmd"
$locationPushed = $false

try {
    $plain = $env:CAMPUS_AUTH_SSH_PASSWORD
    if (-not $plain) {
        $password = Read-Host "SSH password" -AsSecureString
        $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        try {
            $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }
    }

    Push-Location $root
    $locationPushed = $true
    tar -cf $archive usr/bin/campus-auth usr/lib/lua/luci/controller/campus_auth.lua usr/lib/lua/luci/view/campus_auth/main.htm usr/share/rpcd/acl.d/luci-app-campus-auth.json
    if ($LASTEXITCODE -ne 0) { throw "tar failed" }

    Set-Content -LiteralPath $askpass -Value "@echo %CAMPUS_AUTH_SSH_PASSWORD%" -Encoding ASCII
    $env:CAMPUS_AUTH_SSH_PASSWORD = $plain
    $env:SSH_ASKPASS = $askpass
    $env:SSH_ASKPASS_REQUIRE = "force"
    $env:DISPLAY = "1"

    $remoteCommand = 'cat > /tmp/luci-app-campus-auth.tar && tar -xf /tmp/luci-app-campus-auth.tar -C / && chmod 0755 /usr/bin/campus-auth /etc/init.d/campus_auth && rm -f /tmp/luci-app-campus-auth.tar /tmp/luci-modulecache/* 2>/dev/null && /etc/init.d/uhttpd restart'
    $sshCommand = "ssh.exe -T -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o PubkeyAuthentication=no $User@$RouterHost `"$remoteCommand`" < `"$archive`""
    Set-Content -LiteralPath $batch -Value "@echo off`r`n$sshCommand`r`nexit /b %ERRORLEVEL%" -Encoding ASCII

    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = "/d /c `"$batch`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($psi)
    $errorOutput = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "ssh deploy failed: $errorOutput" }
} finally {
    if ($locationPushed) { Pop-Location }
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $askpass -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $batch -Force -ErrorAction SilentlyContinue
    Remove-Item Env:CAMPUS_AUTH_SSH_PASSWORD,Env:SSH_ASKPASS,Env:SSH_ASKPASS_REQUIRE,Env:DISPLAY -ErrorAction SilentlyContinue
    $plain = $null
}
