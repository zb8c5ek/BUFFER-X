# BUFFER-X Installation on Windows (Micromamba `sfm3r` Environment)

Tested on **Windows 10**, **Python 3.11**, **PyTorch 2.8.0+cu126**, **CUDA 12.6**, **MSVC 14.50 (VS 18 Community)**.

---

## Prerequisites

- **Micromamba** with an existing `sfm3r` environment containing **PyTorch 2.8 + CUDA 12.6**
- **NVIDIA CUDA Toolkit 12.6** installed at `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6`
- **Visual Studio 18 Community** (or Build Tools) with "Desktop development with C++" workload
- **Git**

---

## 3rd-Party Repos (clone once into `3rdParty/`)

```powershell
mkdir 3rdParty
git clone https://github.com/LucasColas/Pointnet2_PyTorch.git 3rdParty\Pointnet2_PyTorch
git clone https://github.com/KinglittleQ/torch-batch-svd.git   3rdParty\torch-batch-svd
```

Install Eigen3 and TBB into the micromamba environment:

```powershell
micromamba install -n sfm3r eigen tbb-devel -c conda-forge -y
```

---

## Source File Patches Required

The original code targets Linux/GCC and numpy 1.x. The following patches are needed for Windows + numpy 2.x.

### 1. `3rdParty\Pointnet2_PyTorch\pointnet2_ops_lib\setup.py`

Add `-allow-unsupported-compiler` to nvcc flags (CUDA 12.6 + newer MSVC compatibility):

```python
# In the CUDAExtension block, change nvcc args:
"nvcc": ["-O3", "-Xfatbin", "-compress-all", "-allow-unsupported-compiler"],
```

### 2. `3rdParty\torch-batch-svd\setup.py`

Replace GCC flags with MSVC flags:

```python
# Change this line:
extra_compile_args={"cxx": ["-O2", "-Wno-unknown-pragmas"], "nvcc": ["-O2"]},
# To:
extra_compile_args={"cxx": ["/O2"], "nvcc": ["-O2", "-allow-unsupported-compiler"]},
```

### 3. `cpp_wrappers\cpp_subsampling\setup.py` and `cpp_wrappers\cpp_neighbors\setup.py`

Replace hardcoded Linux paths and GCC flags with Windows/MSVC equivalents. Both files follow the same pattern:

```python
import os

# Replace the hardcoded Linux paths with:
conda_prefix = os.environ.get('CONDA_PREFIX', r'D:\MICROMAMBA\envs\sfm3r')
lib_prefix = os.path.join(conda_prefix, 'Library')
eigen_include_dir = os.path.join(lib_prefix, 'include', 'eigen3')
tbb_include_dir = os.path.join(lib_prefix, 'include')
tbb_library_dir = os.path.join(lib_prefix, 'lib')

# In the Extension() call, use MSVC flags:
extra_compile_args=["/O2", "/std:c++17"],
library_dirs=[tbb_library_dir],
libraries=["tbb12"],
```

### 4. `cpp_wrappers\cpp_subsampling\wrapper.cpp` and `cpp_wrappers\cpp_neighbors\wrapper.cpp`

Add numpy 2.x compatibility macros after the `#include` block:

```cpp
// Numpy 2.x compatibility
#ifndef NPY_IN_ARRAY
#define NPY_IN_ARRAY NPY_ARRAY_IN_ARRAY
#endif

// Helper macros for numpy 2.x (requires PyArrayObject* instead of PyObject*)
#define PYARRAY_DATA(o)      PyArray_DATA((PyArrayObject*)(o))
#define PYARRAY_NDIM(o)      PyArray_NDIM((PyArrayObject*)(o))
#define PYARRAY_DIM(o, i)    PyArray_DIM((PyArrayObject*)(o), (i))
```

Then replace all `PyArray_DATA(` with `PYARRAY_DATA(`, `PyArray_NDIM(` with `PYARRAY_NDIM(`, and `PyArray_DIM(` with `PYARRAY_DIM(` throughout both files.

---

## Installation Steps (PowerShell)

### Step 1: Set up build environment

```powershell
# Load Visual Studio build tools into the current session
$vcvarsPath = "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvars64.bat"
cmd /c "`"$vcvarsPath`" && set" | ForEach-Object {
    if ($_ -match "^(.*?)=(.*)$") {
        Set-Item -Force -Path "env:\$($matches[1])" -Value $matches[2]
    }
}

# Required for PyTorch C++ extension compilation on Windows
$env:DISTUTILS_USE_SDK = "1"
$env:MSSdk = "1"

# Set CUDA home
$env:CUDA_HOME = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.6"

# Set conda prefix for cpp_wrapper setup.py to find Eigen/TBB
$env:CONDA_PREFIX = "D:\MICROMAMBA\envs\sfm3r"
```

### Step 2: Install Python packages

```powershell
micromamba activate sfm3r

# Core dependencies (let pip choose compatible versions)
pip install open3d numpy setuptools wheel

# pointnet2_ops (needs torch at build time)
cd 3rdParty\Pointnet2_PyTorch
pip install pointnet2_ops_lib/. --verbose --no-build-isolation
cd ..\..

# KNN_CUDA
pip install --upgrade https://github.com/unlimblue/KNN_CUDA/releases/download/0.2/KNN_CUDA-0.2-py3-none-any.whl

# Other Python dependencies
pip install ninja kornia einops easydict tensorboard tensorboardX tabulate nibabel
```

### Step 3: Compile C++ wrappers

```powershell
cd cpp_wrappers\cpp_subsampling
python setup.py build_ext --inplace
cd ..\cpp_neighbors
python setup.py build_ext --inplace
cd ..\..
```

### Step 4: Install torch-batch-svd

```powershell
cd 3rdParty\torch-batch-svd
pip install . --no-build-isolation
cd ..\..
```

---

## Automated Script

All the above steps (after applying patches) can be run via:

```powershell
.\install_windows_sfm3r.ps1
```

---

## KNN_CUDA: Pre-compile to Avoid JIT

KNN_CUDA normally compiles its CUDA kernels at import time (JIT), which fails on Windows with newer MSVC. The fix is to **pre-compile it once** during installation.

### 5. Pre-compile KNN_CUDA

The source files `knn.cpp` and `knn.cu` share the same base name, causing object file collisions. Fix:

1. Copy `knn.cpp` to `knn_bind.cpp` to avoid name collision:

```powershell
$knnDir = "D:\MICROMAMBA\envs\sfm3r\Lib\site-packages\knn_cuda"
Copy-Item "$knnDir\csrc\cuda\knn.cpp" "$knnDir\csrc\cuda\knn_bind.cpp"
```

2. Fix `knn_bind.cpp` for Windows (`long` is 32-bit on Windows, but `at::kLong` is 64-bit):

```cpp
// Change: long * ind_dev = ind.data<long>();
// To:
long * ind_dev = reinterpret_cast<long*>(ind.data_ptr<int64_t>());

// Also change all .data<T>() calls to .data_ptr<T>()
```

3. Create `setup_precompile.py` in the knn_cuda package directory and build:

```powershell
# (with VS build environment loaded)
cd $knnDir
python setup_precompile.py build_ext --inplace
# Copy the built .pyd to the package directory
Copy-Item "build\lib.win-amd64-cpython-311\knn_cuda\_knn_ext.cp311-win_amd64.pyd" ".\_knn_ext.cp311-win_amd64.pyd"
```

4. Replace the JIT loading in `__init__.py` with a direct import:

```python
# Replace: _knn = load_cpp_ext("knn")
# With:
from knn_cuda import _knn_ext as _knn
```

After this, KNN_CUDA loads instantly without needing VS build tools at runtime.

---

## Verification

```powershell
micromamba activate sfm3r
python -c "import torch; import open3d; import numpy; import kornia; import einops; print('Core packages OK')"
python -c "import pointnet2_ops; print('pointnet2_ops OK')"
python -c "import torch_batch_svd; print('torch_batch_svd OK')"
```

---

## Final Installed Versions

| Package          | Version       |
|------------------|---------------|
| Python           | 3.11.14       |
| PyTorch          | 2.8.0+cu126   |
| CUDA             | 12.6          |
| Open3D           | 0.19.0        |
| NumPy            | 2.3.5         |
| pointnet2_ops    | Compiled      |
| torch_batch_svd  | 1.1.0         |
| grid_subsampling | Compiled (.pyd) |
| radius_neighbors | Compiled (.pyd) |
