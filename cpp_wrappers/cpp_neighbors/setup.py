from setuptools import setup, Extension
import numpy
import os

SOURCES = ["../cpp_utils/cloud/cloud.cpp", "neighbors/neighbors.cpp", "wrapper.cpp"]

# Windows paths for micromamba environment
conda_prefix = os.environ.get('CONDA_PREFIX', r'D:\MICROMAMBA\envs\sfm3r')
lib_prefix = os.path.join(conda_prefix, 'Library')
eigen_include_dir = os.path.join(lib_prefix, 'include', 'eigen3')
tbb_include_dir = os.path.join(lib_prefix, 'include')
tbb_library_dir = os.path.join(lib_prefix, 'lib')
kiss_matcher_include_dir = "../cpp_utils/kiss_matcher"

module = Extension(
    name="radius_neighbors",
    sources=SOURCES,
    include_dirs=[
        eigen_include_dir,
        tbb_include_dir,
        kiss_matcher_include_dir,
        numpy.get_include(),
    ],
    extra_compile_args=["/O2", "/std:c++17"],  # Windows MSVC flags
    library_dirs=[tbb_library_dir],
    libraries=["tbb12"],
)

setup(
    ext_modules=[module],
)
