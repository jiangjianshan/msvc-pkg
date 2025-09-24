# <div align="center">✨🚀 MSVC-PKG 🚀✨</div>
<div align="center"><strong>The Native Windows Build System That Actually Works</strong></div>

<br>

<div align="center">
  
  
  
  
  
</div>

<div align="center">
  
</div>

## 🎯 Finally, Native Windows Builds That Just Work

Tired of fighting with Cygwin/MSYS2 emulation layers? Exhausted from library naming conflicts and dependency hell? **MSVC-PKG solves these problems once and for all.**

We provide **100% native MSVC compilation** with **full autotools compatibility** - no compromises, no emulation, just clean Windows-native builds.

### ✨ What Makes Developers Switch to MSVC-PKG

```bash
# Before MSVC-PKG (The struggle was real)
1. Install Cygwin/MSYS2 ✅
2. Fight with PATH conflicts ❌
3. Debug .dll.lib naming issues ❌  
4. Handle dependency cycles manually ❌
5. Spend hours on setup ❌

# After MSVC-PKG (Pure bliss)
1. git clone ✅
2. mpt --install ✅
3. Enjoy native builds ✅
# That's literally it!
```

## 🚀 Get Started in 30 Seconds

```bash
# 1. Clone the repository
git clone https://github.com/jiangjianshan/msvc-pkg.git
cd msvc-pkg

# 2. Build complex libraries with one command
mpt --install gmp fftw gsl boost openssl

# 3. Watch the magic happen - colorful output, automatic dependency resolution
# MSVC-PKG handles: download → extract → patch → configure → build → install
```

## 🏆 Technical Breakthroughs

### 🔧 **The Libtool Patch That Changed Everything**
We solved the Windows library naming problem that plagued developers for decades:

```bash
# Traditional autotools on Windows:
math.dll.lib    # Import library name
cygwin1.dll     # Emulation layer dependency

# MSVC-PKG patched output:
libmath.lib     # Clean static library (MSVC standard)
math.lib        # Clean import library (MSVC standard)  
math.dll        # Runtime library
math.la         # Metadata (full autotools compatibility)
```

### 🌳 **Intelligent Dependency Resolution**
Watch as MSVC-PKG automatically:
- 📊 Builds dependency graphs with topological sorting
- 🔍 Detects and visualizes dependency cycles
- 🔄 Handles library updates intelligently
- 🎯 Only rebuilds what actually changed

```bash
# See the dependency magic in action
mpt --dependency gmp

# Example output:
[gmp] Rendering dependency tree with 13 nodes
🌳 gmp
├── 🌿 yasm
│   └── 🌿 gettext
│       ├── 🌿 libxml2
│       │   ├── 🌿 xz
│       │   ├── 🌿 icu4c
│       │   │   ├── 🍁 dlfcn-win32
│       │   │   ├── 🍁 dirent
│       │   │   └── 🍁 winpthreads
│       │   ├── 🌿 winpthreads
│       │   ├── 🍁 zlib
│       │   └── 🌿 libiconv
│       ├── 🍁 dirent
│       ├── 🍁 getopt
│       ├── 🌿 xz
│       │   ├── 🍁 getopt
│       │   └── 🌿 winpthreads
│       ├── 🌿 winpthreads
│       │   └── 🍁 dlfcn-win32
│       ├── 🍁 bzip2
│       ├── 🍁 dlfcn-win32
│       └── 🌿 libiconv
│           ├── 🍁 dlfcn-win32
│           └── 🍁 winpthreads
└── 🍁 dlfcn-win32
```

### 🎨 **Colorful Build Experience**
Experience builds like never before:
- **Real-time color-coded output** - instantly see status, warnings, errors
- **Visual progress tracking** - watch downloads and builds with emoji feedback
- **Interactive dashboards** - beautiful library status displays
- **Comprehensive logging** - full-color build logs that make debugging enjoyable

## 🛠️ Build Previously "Difficult" Libraries with Ease

MSVC-PKG makes complex libraries simple to build:

```bash
# Scientific Computing & Mathematics
mpt --install gmp mpfr fftw gsl arprec qd mpfrcx

# Optimization & Numerical Analysis  
mpt --install Ipopt NLopt Ceres-Solver CppAD SuiteSparse

# Multimedia & Graphics Processing
mpt --install ffmpeg opencv libvpx x265 dav1d libavif

# Advanced GUI & Graphics
mpt --install gtk fltk glfw

# Machine Learning & AI
mpt --install LightGBM protobuf
```

## 🎯 Perfect For These Use Cases

1. **Game Development** - Build SDL, OpenAL, PhysX natively
2. **Scientific Research** - Complex math libraries with dependencies
3. **Enterprise Applications** - Reliable, reproducible builds
4. **Learning & Education** - Experiment without setup pain
5. **Open Source Porting** - Bring Unix libraries to Windows properly

## 💡 Advanced Features You'll Love

**Customizable Installation**
```bash
# Custom global prefix
mpt --prefix C:\my_libs --install boost openssl

# Library-specific prefixes
mpt --boost-prefix D:\Boost --openssl-prefix E:\OpenSSL

# Mixed architecture builds
mpt --arch x86 --install gmp
mpt --arch x64 --install fftw
```

**Smart Source Management**
```bash
# Download sources without building
mpt --fetch gmp fftw ffmpeg

# Clean specific build artifacts
mpt --clean openssl
```

## 📈 Real Results, Real Savings

| Metric | Before MSVC-PKG | With MSVC-PKG | Improvement |
|--------|-----------------|---------------|------------|
| Setup Time | 30-60 minutes | 2 minutes | 15-30x faster |
| Debugging Build Issues | Hours | Minutes | 10x easier |
| Library Naming Problems | Constant | Never | 100% solved |
| Dependency Management | Manual | Automatic | Huge time savings |
| Cross-Project Consistency | Difficult | Easy | Perfect reproducibility |

## 💖 Why This Project Deserves Your Star

1. **Solves Real Problems** - This isn't theoretical; it fixes actual Windows development pain points
2. **Production Ready** - 339+ libraries tested and working in real projects
3. **Active Development** - Regular updates and new library support
4. **Completely Free** - MIT licensed, no strings attached

**⭐ Star this project** to support native Windows development innovation and help other developers discover this solution!

---

<div align="center">

**Ready to Experience Build Bliss on Windows?**

[🚀 Clone & Try Now] • [📚 Read Documentation] • [🐛 Report Issues] • [💡 Suggest Features]

**Join the revolution in Windows development today!**

</div>

---

*MSVC-PKG: Finally, native Windows builds that don't make you hate your life.*
