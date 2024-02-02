:: build onnxruntime for windows by benjaminwan
@ECHO OFF
chcp 65001
cls
SETLOCAL EnableDelayedExpansion

call :cmakeParams "x64" mt
call :cmakeParams "Win32" mt
call :cmakeParams "x64" md
call :cmakeParams "Win32" md
GOTO:EOF

:getFileName
call set "libs=%%libs%% %~n1"
GOTO:EOF

:getLibsList
set "InFile=onnxruntime.dir\Release\onnxruntime.tlog\link.read.1.tlog"
set "OutFile=libs_list.txt"
set "LikeLine=RELEASE\*.LIB"
powershell -Command "$data = foreach($line in gc %InFile%){ $line.split(" ")} $data | Out-File %OutFile%"
powershell -Command "$data = foreach($line in gc %OutFile%){ if($line -like '*%LikeLine%*') {$line}} $data | Out-File -Encoding ascii %OutFile%"
GOTO:EOF

:collectLibs
cmake --build . --config Release --target install
del /s/q install\*test*.exe
copy install\include\onnxruntime\core\session\* install\include
rd /S /Q install\include\onnxruntime
echo set(OnnxRuntime_INCLUDE_DIRS "${CMAKE_CURRENT_LIST_DIR}/include") > install/OnnxRuntimeConfig.cmake
echo include_directories(${OnnxRuntime_INCLUDE_DIRS}) >> install/OnnxRuntimeConfig.cmake
echo link_directories(${CMAKE_CURRENT_LIST_DIR}/lib) >> install/OnnxRuntimeConfig.cmake
echo set(OnnxRuntime_LIBS onnxruntime) >> install/OnnxRuntimeConfig.cmake

mkdir install-static\lib
xcopy install\include install-static\include /s /y /i
call :getLibsList

set libs=
for /f "Delims=" %%a in (libs_list.txt) do (
copy %%a install-static\lib
call :getFileName %%a
)

echo set(OnnxRuntime_INCLUDE_DIRS "${CMAKE_CURRENT_LIST_DIR}/include") > install-static\OnnxRuntimeConfig.cmake
echo include_directories(${OnnxRuntime_INCLUDE_DIRS}) >> install-static\OnnxRuntimeConfig.cmake
echo link_directories(${CMAKE_CURRENT_LIST_DIR}/lib) >> install-static\OnnxRuntimeConfig.cmake
echo set(OnnxRuntime_LIBS %libs%) >> install-static\OnnxRuntimeConfig.cmake
GOTO:EOF

:cmakeParams
if "%~1" == "Win32" (
    set MACHINE_FLAG="--x86"
)^
else (
    set MACHINE_FLAG=
)
if "%~2" == "mt" (
    set STATIC_CRT_FLAG="--enable_msvc_static_runtime"
)^
else (
    set STATIC_CRT_FLAG=
)
python %~dp0\tools\ci_build\build.py --build_dir %~dp0\build-%~1-%~2 ^
    --config Release ^
	--update ^
	--parallel ^
	--skip_tests ^
	--build_shared_lib ^
	%STATIC_CRT_FLAG% ^
	%MACHINE_FLAG% ^
	--cmake_extra_defines CMAKE_INSTALL_PREFIX=./install onnxruntime_BUILD_UNIT_TESTS=OFF onnxruntime_RUN_ONNX_TESTS=OFF onnxruntime_BUILD_WINML_TESTS=OFF onnxruntime_USE_OPENMP=OFF onnxruntime_DEV_MODE=OFF
pushd "build-%~1-%~2"\Release
call :collectLibs
popd
GOTO:EOF