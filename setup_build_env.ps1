# Setup Visual Studio and CUDA environment for building BUFFER-X
# Source this script in your PowerShell session before running installation commands

Write-Host "Setting up build environment..." -ForegroundColor Cyan

# Set up Visual Studio build environment
$vsPath = "C:\Program Files\Microsoft Visual Studio\18\Community"
$vcvarsPath = "$vsPath\VC\Auxiliary\Build\vcvars64.bat"

if (Test-Path $vcvarsPath) {
    Write-Host "Loading Visual Studio environment..." -ForegroundColor Yellow
    cmd /c "`"$vcvarsPath`" && set" | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            Set-Item -Force -Path "env:\$($matches[1])" -Value $matches[2]
        }
    }
    # Set DISTUTILS_USE_SDK for PyTorch extensions
    $env:DISTUTILS_USE_SDK = "1"
    $env:MSSdk = "1"
    Write-Host "✓ Visual Studio environment loaded" -ForegroundColor Green
    Write-Host "✓ DISTUTILS_USE_SDK set to: $env:DISTUTILS_USE_SDK" -ForegroundColor Green
} else {
    Write-Host "ERROR: Visual Studio not found!" -ForegroundColor Red
    exit 1
}

# Set CUDA_HOME
$env:CUDA_HOME = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
Write-Host "✓ CUDA_HOME set to: $env:CUDA_HOME" -ForegroundColor Green

# Verify compiler is accessible
$clPath = (Get-Command cl.exe -ErrorAction SilentlyContinue).Source
if ($clPath) {
    Write-Host "✓ MSVC compiler found: $clPath" -ForegroundColor Green
} else {
    Write-Host "WARNING: cl.exe not found in PATH" -ForegroundColor Yellow
}

$nvccPath = (Get-Command nvcc.exe -ErrorAction SilentlyContinue).Source
if ($nvccPath) {
    Write-Host "✓ NVCC found: $nvccPath" -ForegroundColor Green
} else {
    Write-Host "WARNING: nvcc.exe not found in PATH" -ForegroundColor Yellow
}

Write-Host "`nBuild environment ready!" -ForegroundColor Cyan
Write-Host "You can now run installation commands in the sfm3r environment." -ForegroundColor White
