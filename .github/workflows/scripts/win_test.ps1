param (
    [string]$libsDir = "."
)

$ErrorActionPreference = "Stop"

. $PSScriptRoot\common-utils.ps1

Setup-VS

$env:PYTHONUNBUFFERED = 1
$env:TI_CI = 1
$env:TI_OFFLINE_CACHE_FILE_PATH = Join-Path -Path $pwd -ChildPath ".cache\taichi"

Setup-Python $libsDir

$whl = & Get-ChildItem -Filter '*.whl' -Path dist | Select-Object -First 1
echo $whl
Invoke python -m pip install $whl.FullName
Invoke python -c "import taichi"
Invoke ti diagnose
# Invoke ti changelog
echo wanted arch: $env:TI_WANTED_ARCHS
Invoke pip install -r requirements_test.txt
# TODO relax this when torch supports 3.10
if ("$env:TI_WANTED_ARCHS".Contains("cuda")) {
    Invoke pip install "torch==1.10.1+cu113; python_version < '3.10'" -f https://download.pytorch.org/whl/cu113/torch_stable.html
} else {
    Invoke pip install "torch; python_version < '3.10'"
    Invoke pip install "paddlepaddle==2.3.0; python_version < '3.10'"
}


if ("$env:TI_RUN_RELEASE_TESTS" -eq "1" -and -not "$env:TI_LITE_TEST") {
    echo "Running release tests"
    # release tests
    Invoke pip install PyYAML
    Invoke git clone https://github.com/taichi-dev/taichi-release-tests
    mkdir -p repos/taichi/python/taichi
    $EXAMPLES = & python -c 'import taichi.examples as e; print(e.__path__._path[0])' | Select-Object -Last 1
    New-Item -Target $EXAMPLES -Path repos/taichi/python/taichi/examples -ItemType Junction
    New-Item -Target taichi-release-tests/truths -Path truths -ItemType Junction
    Invoke python taichi-release-tests/run.py --log=DEBUG --runners 1 taichi-release-tests/timelines
}

# Run C++ tests
Invoke python tests/run_tests.py --cpp

# Fail fast, give priority to the error-prone tests
Invoke python tests/run_tests.py -vr2 -t1 -k "paddle" -a cpu

# Disable paddle for the remaining test
$env:TI_ENABLE_PADDLE = "0"

if ("$env:TI_WANTED_ARCHS".Contains("cuda")) {
  Invoke python tests/run_tests.py -vr2 -t4 -k "not torch and not paddle" -a cuda
}
if ("$env:TI_WANTED_ARCHS".Contains("cpu")) {
  Invoke python tests/run_tests.py -vr2 -t6 -k "not torch and not paddle" -a cpu
}
if ("$env:TI_WANTED_ARCHS".Contains("opengl")) {
  Invoke python tests/run_tests.py -vr2 -t4 -k "not torch and not paddle" -a opengl
}
Invoke python tests/run_tests.py -vr2 -t1 -k "torch" -a "$env:TI_WANTED_ARCHS"
