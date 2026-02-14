# BUFFER-X Installation Script for Windows + Micromamba sfm3r environment
# This script sets up Visual Studio build tools and installs all dependencies

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "BUFFER-X Installation for sfm3r env" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Set up Visual Studio build environment
Write-Host "[1/8] Setting up Visual Studio build environment..." -ForegroundColor Yellow
$vsPath = "C:\Program Files\Microsoft Visual Studio\18\Community"
$vcvarsPath = "$vsPath\VC\Auxiliary\Build\vcvars64.bat"

if (Test-Path $vcvarsPath) {
    Write-Host "Found Visual Studio at: $vsPath" -ForegroundColor Green
    # Import VS environment variables
    cmd /c "`"$vcvarsPath`" && set" | ForEach-Object {
        if ($_ -match "^(.*?)=(.*)$") {
            Set-Item -Force -Path "env:\$($matches[1])" -Value $matches[2]
        }
    }
    # Set DISTUTILS_USE_SDK for PyTorch extensions
    $env:DISTUTILS_USE_SDK = "1"
    $env:MSSdk = "1"
    Write-Host "Visual Studio environment loaded successfully!" -ForegroundColor Green
    Write-Host "DISTUTILS_USE_SDK set to: $env:DISTUTILS_USE_SDK" -ForegroundColor Green
} else {
    Write-Host "ERROR: Visual Studio not found at expected location!" -ForegroundColor Red
    Write-Host "Please run this from Developer PowerShell for VS 2022" -ForegroundColor Red
    exit 1
}

# Step 2: Set CUDA_HOME
Write-Host "`n[2/8] Setting CUDA_HOME environment variable..." -ForegroundColor Yellow
$nvccPath = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6\bin\nvcc.exe"
if (Test-Path $nvccPath) {
    $env:CUDA_HOME = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"
    Write-Host "CUDA_HOME set to: $env:CUDA_HOME" -ForegroundColor Green
} else {
    Write-Host "ERROR: nvcc not found at expected location!" -ForegroundColor Red
    exit 1
}

# Step 3: Install Open3D, numpy, and build tools (let pip choose versions)
Write-Host "`n[3/8] Installing Open3D, numpy, and build tools..." -ForegroundColor Yellow
micromamba run -n sfm3r pip install open3d numpy setuptools wheel
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install Open3D/numpy/setuptools" -ForegroundColor Red
    exit 1
}

# Step 4: Install pointnet2_ops
Write-Host "`n[4/8] Installing pointnet2_ops..." -ForegroundColor Yellow
$pointnet2Path = "3rdParty\Pointnet2_PyTorch"
if (-not (Test-Path $pointnet2Path)) {
    Write-Host "ERROR: Pointnet2_PyTorch not found at $pointnet2Path" -ForegroundColor Red
    Write-Host "Please download it to: D:\BUFFER-X\3rdParty\Pointnet2_PyTorch" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "  Found Pointnet2_PyTorch at $pointnet2Path" -ForegroundColor Green
}
Set-Location $pointnet2Path
# Use --no-build-isolation to allow access to torch during build
micromamba run -n sfm3r pip install pointnet2_ops_lib/. --verbose --no-build-isolation
$installResult = $LASTEXITCODE
Set-Location ..\..
if ($installResult -ne 0) {
    Write-Host "ERROR: Failed to install pointnet2_ops" -ForegroundColor Red
    exit 1
}

# Step 5: Install KNN_CUDA
Write-Host "`n[5/8] Installing KNN_CUDA..." -ForegroundColor Yellow
micromamba run -n sfm3r pip install --upgrade https://github.com/unlimblue/KNN_CUDA/releases/download/0.2/KNN_CUDA-0.2-py3-none-any.whl
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: KNN_CUDA installation failed, continuing..." -ForegroundColor Yellow
}

# Step 6: Install other Python dependencies
Write-Host "`n[6/8] Installing other Python dependencies..." -ForegroundColor Yellow
micromamba run -n sfm3r pip install ninja kornia einops easydict tensorboard tensorboardX tabulate nibabel
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install Python dependencies" -ForegroundColor Red
    exit 1
}

# Step 7: Compile C++ wrappers
Write-Host "`n[7/8] Compiling C++ wrappers..." -ForegroundColor Yellow
Write-Host "  Compiling cpp_subsampling..." -ForegroundColor Cyan
Set-Location cpp_wrappers\cpp_subsampling
micromamba run -n sfm3r python setup.py build_ext --inplace
$subsamplingResult = $LASTEXITCODE
Set-Location ..\..

if ($subsamplingResult -ne 0) {
    Write-Host "ERROR: Failed to compile cpp_subsampling" -ForegroundColor Red
    exit 1
}

Write-Host "  Compiling cpp_neighbors..." -ForegroundColor Cyan
Set-Location cpp_wrappers\cpp_neighbors
micromamba run -n sfm3r python setup.py build_ext --inplace
$neighborsResult = $LASTEXITCODE
Set-Location ..\..

if ($neighborsResult -ne 0) {
    Write-Host "ERROR: Failed to compile cpp_neighbors" -ForegroundColor Red
    exit 1
}

# Step 8: Install torch-batch-svd
Write-Host "`n[8/8] Installing torch-batch-svd..." -ForegroundColor Yellow
$svdPath = "3rdParty\torch-batch-svd"
if (-not (Test-Path $svdPath)) {
    Write-Host "  Cloning torch-batch-svd repository to 3rdParty..." -ForegroundColor Cyan
    if (-not (Test-Path "3rdParty")) {
        New-Item -ItemType Directory -Path "3rdParty" | Out-Null
    }
    git clone https://github.com/KinglittleQ/torch-batch-svd.git $svdPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to clone torch-batch-svd" -ForegroundColor Red
        Write-Host "Please manually download to: D:\BUFFER-X\3rdParty\torch-batch-svd" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "  Found torch-batch-svd at $svdPath" -ForegroundColor Green
}
Set-Location $svdPath
# Use pip with --no-build-isolation instead of setup.py directly
micromamba run -n sfm3r pip install . --no-build-isolation
$svdResult = $LASTEXITCODE
Set-Location ..\..
if ($svdResult -ne 0) {
    Write-Host "ERROR: Failed to install torch-batch-svd" -ForegroundColor Red
    exit 1
}

# Final verification
Write-Host "`n=====================================" -ForegroundColor Cyan
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Verifying installation..." -ForegroundColor Yellow
micromamba run -n sfm3r python -c "import torch; import open3d; import numpy; print('✓ Core packages imported successfully')"
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✓ All packages installed successfully!" -ForegroundColor Green
    Write-Host "`nYou can now run BUFFER-X:" -ForegroundColor Cyan
    Write-Host "  micromamba activate sfm3r" -ForegroundColor White
    Write-Host "  python test.py --dataset 3DMatch --experiment_id threedmatch --verbose" -ForegroundColor White
} else {
    Write-Host "`n⚠ Installation completed but verification failed" -ForegroundColor Yellow
    Write-Host "Please check the errors above" -ForegroundColor Yellow
}
