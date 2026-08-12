# RustDesk 无调云定制版 - Windows 一键编译脚本
# 使用方式：在 Windows PowerShell 中以管理员身份运行
# .\build-windows.ps1

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RustDesk 无调云定制版 - Windows 编译" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查当前目录
if (-not (Test-Path "build.py")) {
    Write-Host "[ERROR] 请在 rustdesk 源码根目录运行此脚本" -ForegroundColor Red
    exit 1
}

# 检查工具链
Write-Host "[1/5] 检查编译环境..." -ForegroundColor Yellow

$tools = @{
    "rustc"   = "rust"
    "flutter" = "flutter"
    "cargo"   = "cargo"
}

foreach ($cmd in $tools.Keys) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "  [OK] $($tools[$cmd]): $($found.Source)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $($tools[$cmd]) 未安装" -ForegroundColor Red
        Write-Host "  请参考 编译说明-Windows.md 安装所需环境" -ForegroundColor Red
        exit 1
    }
}

# 检查 VCPKG_ROOT
if (-not $env:VCPKG_ROOT) {
    Write-Host "  [WARN] VCPKG_ROOT 未设置，尝试默认路径 C:\vcpkg" -ForegroundColor Yellow
    $env:VCPKG_ROOT = "C:\vcpkg"
}
Write-Host "  VCPKG_ROOT = $env:VCPKG_ROOT" -ForegroundColor Green

Write-Host ""
Write-Host "[2/5] 拉取 Flutter 依赖..." -ForegroundColor Yellow
Push-Location flutter
flutter pub get
Pop-Location

Write-Host ""
Write-Host "[3/5] 编译 Rust 核心 (cargo build)..." -ForegroundColor Yellow
cargo build --locked --features flutter,hwcodec --lib --release

if (-not (Test-Path "target/release/librustdesk.dll")) {
    Write-Host "[ERROR] cargo build 失败，librustdesk.dll 不存在" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] librustdesk.dll 编译完成" -ForegroundColor Green

Write-Host ""
Write-Host "[4/5] 编译 Flutter Windows..." -ForegroundColor Yellow
Push-Location flutter
flutter build windows --release
Pop-Location

# 复制 dylib_virtual_display.dll
Copy-Item "target/release/deps/dylib_virtual_display.dll" "build/windows/x64/runner/Release/" -Force
Write-Host "  [OK] Flutter Windows 编译完成" -ForegroundColor Green

Write-Host ""
Write-Host "[5/5] 打包安装包..." -ForegroundColor Yellow
Push-Location libs/portable
pip install -r requirements.txt
python ./generate.py -f ../../build/windows/x64/runner/Release -o . -e ../../build/windows/x64/runner/Release/rustdesk.exe
Pop-Location

# 重命名输出文件
$version = (Select-String -Path "Cargo.toml" -Pattern '^version' | Select-Object -First 1).Line -replace 'version.*=.*"(.*)".*', '$1'
if (Test-Path "./rustdesk_portable.exe") {
    Move-Item "./target/release/rustdesk-portable-packer.exe" "./rustdesk_portable.exe" -Force
}

$outputName = "rustdesk-$version-install.exe"
if (Test-Path "./rustdesk_portable.exe") {
    Move-Item "./rustdesk_portable.exe" "./$outputName" -Force
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  编译完成!" -ForegroundColor Green
Write-Host "  输出文件: $((Resolve-Path ./$outputName).Path)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "将此文件上传到服务器:" -ForegroundColor Cyan
Write-Host "  /www/wwwroot/rustdesk.sdwan.atonal.cn/html/download/windows.exe" -ForegroundColor Cyan
