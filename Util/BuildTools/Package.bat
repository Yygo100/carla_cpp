@echo off
setlocal enabledelayedexpansion

rem 以下两行空行不要删除（可能有特定用途，具体需看相关要求或约定）
set LF=^


rem 这个批处理脚本用于编译和导出Carla项目（carla.org）
rem 需要在启用了x64 Visual C++工具集的命令提示符（cmd）中运行。
rem 参考链接：https://wiki.unrealengine.com/How_to_package_your_game_with_commands

set LOCAL_PATH=%~dp0
set FILE_N=-[%~n0]:

rem 打印批处理参数（用于调试目的）
echo %FILE_N% [Batch params]: %*

rem ==============================================================================
rem -- Parse arguments -----------------------------------------------------------
rem ==============================================================================

rem 设置帮助文档字符串，描述脚本的功能
set DOC_STRING="Makes a packaged version of CARLA for distribution."
rem 设置用法说明字符串，提示脚本正确的使用方式
set USAGE_STRING="Usage: %FILE_N% [-h|--help] [--config={Debug,Development,Shipping}] [--no-packaging] [--no-zip] [--clean] [--clean-intermediate] [--target-archive]"

rem 初始化一些变量，用于控制后续流程中不同操作是否执行，默认值如下
set DO_PACKAGE=true
set DO_COPY_FILES=true
set DO_TARBALL=true
set DO_CLEAN=false
set PACKAGES=Carla
set PACKAGE_CONFIG=Shipping
set USE_CARSIM=false
set SINGLE_PACKAGE=false

:arg-parse
rem 判断第一个参数是否为空，如果不为空则进入参数解析分支
if not "%1"=="" (
    rem 如果参数是--clean，设置相应的操作控制变量，表示要进行清理操作，不进行打包、压缩等
    if "%1"=="--clean" (
        set DO_CLEAN=true
        set DO_TARBALL=false
        set DO_PACKAGE=false
        set DO_COPY_FILES=false
    )
    rem 如果参数是--config，设置打包配置变量，并将参数列表向左移动一位（处理下一个参数）
    if "%1"=="--config" (
        set PACKAGE_CONFIG=%2
        shift
    )
    rem 如果参数是--clean-intermediate，设置清理相关变量
    if "%1"=="--clean-intermediate" (
        set DO_CLEAN=true
    )
    rem 如果参数是--no-zip，设置不进行压缩操作的变量
    if "%1"=="--no-zip" (
        set DO_TARBALL=false
    )
    rem 如果参数是--no-packaging，设置不进行打包操作的变量
    if "%1"=="--no-packaging" (
        set DO_PACKAGE=false
    )
    rem 如果参数是--packages，设置相关操作控制变量，并获取后面跟着的所有参数作为包名相关内容，然后移动参数列表
    if "%1"=="--packages" (
        set DO_PACKAGE=false
        set DO_COPY_FILES=false
        set PACKAGES=%*
        shift
    )
    rem 如果参数是--target-archive，设置单包相关变量以及目标归档文件名变量，并移动参数列表
    if "%1"=="--target-archive" (
        set SINGLE_PACKAGE=true
        set TARGET_ARCHIVE=%2
        shift
    )
    rem 如果参数是--carsim，设置使用CarSim相关变量
    if "%1"=="--carsim" (
        set USE_CARSIM=true
    )
    rem 如果参数是-h或者--help，打印帮助文档字符串和用法说明字符串，然后跳转到脚本结尾（结束执行）
    if "%1"=="-h" (
        echo %DOC_STRING%
        echo %USAGE_STRING%
        GOTO :eof
    )
    if "%1"=="--help" (
        echo %DOC_STRING%
        echo %USAGE_STRING%
        GOTO :eof
    )
    rem 移动参数列表，继续循环解析下一个参数
    shift
    goto :arg-parse
)

rem 获取Unreal Engine根路径，如果未定义UE4_ROOT变量则尝试从注册表中查找
if not defined UE4_ROOT (
    set KEY_NAME="HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine"
    set VALUE_NAME=InstalledDirectory
    for /f "usebackq tokens=1,2,*" %%A in (`reg query!KEY_NAME! /s /reg:64`) do (
        if "%%A" == "!VALUE_NAME!" (
            set UE4_ROOT=%%C
        )
    )
    rem 如果未找到Unreal Engine路径，则跳转到错误处理分支（error_unreal_no_found）
    if not defined UE4_ROOT goto error_unreal_no_found
)

rem 设置打包相关的路径变量
rem
for /f %%i in ('git describe --tags --dirty --always') do set CARLA_VERSION=%%i
rem 如果Carla版本号未定义，则跳转到错误处理分支（error_carla_version）
if not defined CARLA_VERSION goto error_carla_version

set BUILD_FOLDER=%INSTALLATION_DIR%UE4Carla/%CARLA_VERSION%/

set DESTINATION_ZIP=%INSTALLATION_DIR%UE4Carla/CARLA_%CARLA_VERSION%.zip
set SOURCE=!BUILD_FOLDER!WindowsNoEditor/

rem ============================================================================
rem -- Create Carla package ----------------------------------------------------
rem ============================================================================

rem 如果需要进行打包操作（DO_PACKAGE为true）
if %DO_PACKAGE%==true (
    rem 如果启用了CarSim，执行相关Python脚本进行配置，并写入配置文件表示CarSim开启
    if %USE_CARSIM% == true (
        python %ROOT_PATH%Util/BuildTools/enable_carsim_to_uproject.py -f="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject" -e
        echo CarSim ON > "%ROOT_PATH%Unreal/CarlaUE4/Config/CarSimConfig.ini"
    ) else (
        rem 否则执行Python脚本进行配置，并写入配置文件表示CarSim关闭
        python %ROOT_PATH%Util/BuildTools/enable_carsim_to_uproject.py -f="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
        echo CarSim OFF > "%ROOT_PATH%Unreal/CarlaUE4/Config/CarSimConfig.ini"
    )
    rem 如果构建文件夹不存在，则创建该文件夹
    if not exist "!BUILD_FOLDER!" mkdir "!BUILD_FOLDER!"
    rem 调用Unreal Engine的构建批处理脚本构建CarlaUE4Editor，若返回错误则跳转到相应错误处理分支（error_build_editor）
    call "%UE4_ROOT%\Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4Editor^
        Win64^
        Development^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    if errorlevel 1 goto error_build_editor
    rem 输出要执行的构建命令（可能用于调试或记录），然后调用构建批处理脚本构建CarlaUE4，若返回错误则跳转到相应错误处理分支（error_build）
    echo "%UE4_ROOT%\Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4^
        Win64^
        %PACKAGE_CONFIG%^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    call "%UE4_ROOT%\Engine\Build\BatchFiles\Build.bat"^
        CarlaUE4^
        Win64^
        %PACKAGE_CONFIG%^
        -WaitMutex^
        -FromMsBuild^
        "%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"
    if errorlevel 1 goto error_build
    rem 输出要执行的运行UAT命令（可能用于调试或记录），然后调用运行UAT批处理脚本进行构建、烹饪、打包等一系列操作，若返回错误则跳转到相应错误处理分支（error_runUAT）
    echo "%UE4_ROOT%\Engine\Build\BatchFiles\RunUAT.bat"^
        BuildCookRun^
        -nocompileeditor^
        -TargetPlatform=Win64^
        -Platform=Win64^
        -installed^
        -nop4^
        -project="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"^
        -cook^
        -stage^
        -build^
        -archive^
        -archivedirectory="!BUILD_FOLDER!"^
        -package^
        -clientconfig=%PACKAGE_CONFIG%
    call "%UE4_ROOT%\Engine\Build\BatchFiles\RunUAT.bat"^
        BuildCookRun^
        -nocompileeditor^
        -TargetPlatform=Win64^
        -Platform=Win64^
        -installed^
        -nop4^
        -project="%ROOT_PATH%Unreal/CarlaUE4/CarlaUE4.uproject"^
        -cook^
        -stage^
        -build^
        -archive^
        -archivedirectory="!BUILD_FOLDER!"^
        -package^
        -clientconfig=%PACKAGE_CONFIG%
    if errorlevel 1 goto error_runUAT
)

rem ==============================================================================
rem -- Adding extra files to package ---------------------------------------------
rem ==============================================================================

rem 如果需要复制额外文件到包中（DO_COPY_FILES为true）
if %DO_COPY_FILES%==true (
    rem 打印提示信息，表示开始添加额外文件到包中
    echo "%FILE_N% Adding extra files to package..."
    rem 设置xcopy命令的源路径和目标路径变量，替换路径中的斜杠为反斜杠（适用于Windows系统命令格式）
    set XCOPY_FROM=%ROOT_PATH:/=\%
    set XCOPY_TO=%SOURCE:/=\%
    rem 使用xcopy命令复制各种文件和文件夹到目标路径，如许可证文件、变更日志文件、文档文件、Python相关文件、地图文件等
    echo f | xcopy /y "!XCOPY_FROM!LICENSE"                                         "!XCOPY_TO!LICENSE"
    echo f | xcopy /y "!XCOPY_FROM!CHANGELOG.md"                                    "!XCOPY_TO!CHANGELOG"
    echo f | xcopy /y "!XCOPY_FROM!Docs\release_readme.md"                          "!XCOPY_TO!README"
    echo f | xcopy /y "!XCOPY_FROM!Util\Docker\Release.Dockerfile"                  "!XCOPY_TO!Dockerfile"
    echo f | xcopy /y "!XCOPY_FROM!PythonAPI\carla\dist\*.egg"                      "!XCOPY_TO!PythonAPI\carla\dist\"
    echo f | xcopy /y "!XCOPY_FROM!PythonAPI\carla\dist\*.whl"                      "!XCOPY_TO!PythonAPI\carla\dist\"
    echo d | xcopy /y /s "!XCOPY_FROM!Co-Simulation"                                "!XCOPY_TO!Co-Simulation"
    echo d | xcopy /y /s "!XCOPY_FROM!PythonAPI\carla\agents"                       "!XCOPY_TO!PythonAPI\carla\agents"
    echo f | xcopy /y "!XCOPY_FROM!PythonAPI\carla\scene_layout.py"                 "!XCOPY_TO!PythonAPI\carla\"
    echo f | xcopy /y "!XCOPY_FROM!PythonAPI\carla\requirements.txt"                "!XCOPY_TO!PythonAPI\carla\"
    echo f | xcopy /y "!XCOPY_FROM!PythonAPI\examples\*.py"                         "!XCOPY_TO!PythonAPI\examples\"
    echo f | xcopy /y "!XCOPY_FROM!PythonAPI\examples\requirements.txt"             "!XCOPY_TO!PythonAPI\examples\"
    echo f | xcopy /y "!XCOPY_FROM!PythonAPI\util\*.py"                             "!XCOPY_TO!PythonAPI\util\"
    echo d | xcopy /y /s "!XCOPY_FROM!PythonAPI\util\opendrive"                     "!XCOPY_TO!PythonAPI\util\opendrive"
    echo f | xcopy /y "!XCOPY_FROM!PythonAPI\util\requirements.txt"                 "!XCOPY_TO!PythonAPI\util\"
    echo f | xcopy /y "!XCOPY_FROM!Unreal\CarlaUE4\Content\Carla\HDMaps\*.pcd"      "!XCOPY_TO!HDMaps\"
    echo f | xcopy /y "!XCOPY_FROM!Unreal\CarlaUE4\Content\Carla\HDMaps\Readme.md"  "!XCOPY_TO!HDMaps\README"
    if exist "!XCOPY_FROM!Plugins" (
        echo d | xcopy /y /s "!XCOPY_FROM!Plugins"                                  "!XCOPY_TO!Plugins"
    )
)

rem ==============================================================================
rem -- Zip the project -----------------------------------------------------------
rem ==============================================================================

rem 如果需要进行打包并且需要压缩（DO_PACKAGE和DO_TARBALL都为true）
if %DO_PACKAGE%==true if %DO_TARBALL%==true (
    rem 设置源路径变量，替换路径中的斜杠为反斜杠
    set SRC_PATH=%SOURCE:/=\%
    rem 打印提示信息，表示开始构建包
    echo %FILE_N% Building package...
    rem 如果存在一些特定的清单文件则删除它们，以及删除一些保存相关的文件夹（可能是清理旧的或不必要的文件）
    if exist "!SRC_PATH!Manifest_NonUFSFiles_Win64.txt" del /Q "!SRC_PATH!Manifest_NonUFSFiles_Win64.txt"
    if exist "!SRC_PATH!Manifest_DebugFiles_Win64.txt" del /Q "!SRC_PATH!Manifest_DebugFiles_Win64.txt"
    if exist "!SRC_PATH!Manifest_UFSFiles_Win64.txt" del /Q "!SRC_PATH!Manifest_UFSFiles_Win64.txt"
    if exist "!SRC_PATH!CarlaUE4/Saved" rmdir /S /Q "!SRC_PATH!CarlaUE4/Saved"
    if exist "!SRC_PATH!Engine/Saved" rmdir /S /Q "!SRC_PATH!Engine/Saved"
    rem 设置目标压缩文件路径变量，替换路径中的斜杠为反斜杠
    set DST_ZIP=%DESTINATION_ZIP:/=\%
    rem 如果存在7-Zip的可执行文件，则使用7-Zip进行压缩，否则使用PowerShell的压缩命令进行压缩
    if exist "%ProgramW6432%/7-Zip/7z.exe" (
        "%ProgramW6432%/7-Zip/7z.exe" a "!DST_ZIP!" "!SRC_PATH!" -tzip -mmt -mx5
    ) else (
        pushd "!SRC_PATH!"
            rem https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.archive/compress-archive?view=powershell-6
            powershell -command "& { Compress-Archive -Path * -CompressionLevel Fastest -DestinationPath '!DST_ZIP!' }"
        popd
    )
)

rem ==============================================================================
rem -- Remove intermediate files -------------------------------------------------
rem ==============================================================================

rem 如果需要进行清理操作（DO_CLEAN为true）
if %DO_CLEAN%==true (
    rem 打印提示信息，表示正在移除中间构建文件，然后删除构建文件夹及其内容
    echo %FILE_N% Removing intermediate build.
    rmdir /S /Q "!BUILD_FOLDER!"
)

rem ==============================================================================
rem -- Cook other packages -------------------------------------------------------
rem ==============================================================================

rem 设置一些文件位置相关的变量，用于后续查找和操作相关文件
set CARLAUE4_ROOT_FOLDER=%ROOT_PATH%Unreal/CarlaUE4
set PACKAGE_PATH_FILE=%CARLAUE4_ROOT_FOLDER%/Content/PackagePath.txt
set MAP_LIST_FILE=%CARLAUE4_ROOT_FOLDER%/Content/MapPaths.txt

rem 打印提示信息，表示开始解析要烹饪的包
echo Parsing packages...
rem 如果包名不是默认的Carla
if not "%PACKAGES%" == "Carla" (
    rem 将参数中的--替换为换行符（通过之前定义的LF变量），用于后续按行处理参数
    set ARGUMENTS=%PACKAGES:--=!LF!%
    for /f "tokens=*" %%i in ("!ARGUMENTS!") do (
        set a=%%i
        rem 判断是否是以packages=开头的参数行，提取后面的内容作为结果（包名相关内容）
        if "!a:~0,9!" == "packages=" (
            set RESULT=!a:~9!
        ) else (
            rem 判断是否是以packages 开头的参数行（注意有空格区别），提取后面的内容作为结果
            if "!a:~0,9!" == "packages " (
                set RESULT=!a:~9!
            )
        )
    )
) else (
    rem 如果是默认的Carla，则直接使用默认的包名作为结果
    set RESULT=%PACKAGES%
)
rem 将结果中的逗号替换为换行符，用于按包名分别处理
set PACKAGES=%RESULT:,=!LF!%
for /f "tokens=* delims=" %%i in ("!PACKAGES!") do (
    rem 设置当前处理的包名变量
    set PACKAGE_NAME=%%i
    rem 如果当前包名不是Carla，则进行以下一系列针对该包的操作
    if not!PACKAGE_NAME! == Carla (
        rem 打印提示信息，表明正在为该包准备烹饪环境
        echo Preparing environment for cooking '!PACKAGE_NAME!'.

        rem 设置该包的构建文件夹路径变量
        set BUILD_FOLDER=%INSTALLATION_DIR%UE4Carla/!PACKAGE_NAME!_%CARLA_VERSION%\
        rem 设置该包的路径变量
        set PACKAGE_PATH=%CARLAUE4_ROOT_FOLDER%/Content/!PACKAGE_NAME!

        rem 如果构建文件夹不存在，则创建该文件夹
        if not exist "!BUILD_FOLDER!" mkdir "!BUILD_FOLDER!"

        rem 打印提示信息，表明开始烹饪该包
        echo Cooking package '!PACKAGE_NAME!'...

        rem 进入CarlaUE4根文件夹（改变当前目录）
        pushd "%CARLAUE4_ROOT_FOLDER%"

        rem 打印准备步骤提示信息
        echo   - prepare
        REM # 准备烹饪该包，调用UE4Editor.exe进行相关准备操作，设置包名等参数
        echo Prepare cooking of package:!PACKAGE_NAME!
        call "%UE4_ROOT%/Engine/Binaries/Win64/UE4Editor.exe "^
        "%CARLAUE4_ROOT_FOLDER%/CarlaUE4.uproject"^
        -run=PrepareAssetsForCooking^
        -PackageName=!PACKAGE_NAME!^
        -OnlyPrepareMaps=false

        rem 从文件中读取包配置文件路径并赋值给变量
        set /p PACKAGE_FILE=<%PACKAGE_PATH_FILE%
        rem 从文件中读取要烹饪的地图列表并赋值给变量
        set /p MAPS_TO_COOK=<%MAP_LIST_FILE%

        rem 打印烹饪步骤提示信息
        echo   - cook
        rem 遍历要烹饪的地图列表，对每个地图调用UE4Editor.exe进行烹饪操作，设置相关参数如地图名、输出目录等
        for /f "tokens=*" %%a in (%MAP_LIST_FILE%) do (
            REM # 烹饪地图，输出正在烹饪的地图名
            echo Cooking: %%a
            call "%UE4_ROOT%/Engine/Binaries/Win64/UE4Editor.exe "^
            "%CARLAUE4_ROOT_FOLDER%/CarlaUE4.uproject"^
            -run=cook^
            -map="%%a"^
            -targetplatform="WindowsNoEditor"^
            -OutputDir="!BUILD_FOLDER!"^
            -iterate^
            -cooksinglepackage^
        )

        rem 如果存在特定的地图文件夹（PropsMap），则删除它及其内容
        set PROPS_MAP_FOLDER="%PACKAGE_PATH%/Maps/PropsMap"
        if exist "%PROPS_MAP_FOLDER%" (
        rmdir /S /Q "%PROPS_MAP_FOLDER%"
        )

        rem 回到上一级目录（恢复之前的目录）
        popd

        rem 打印提示信息，表明开始复制文件到该包
        echo Copying files to '!PACKAGE_NAME!'...

        rem 进入该包的构建文件夹（改变当前目录）
        pushd "!BUILD_FOLDER!"

        rem 设置一个替代路径变量，用于后续操作方便（可能是简化路径表示等）
        set SUBST_PATH=!BUILD_FOLDER!CarlaUE4

        rem 复制包配置文件到该包内指定的文件夹，先创建目标文件夹（如果不存在），再进行复制
        set TARGET="!SUBST_PATH!\Content\Carla\Config\"
        mkdir!TARGET:/=\!
        copy "!PACKAGE_FILE:/=\!"!TARGET:/=\!

        rem 对于要烹饪的每个地图，进行以下一系列文件复制操作
        REM MAPS_TO_COOK是读取的地图列表字符串，将其中的'+'替换为换行符，便于后续按行处理（以空格为分隔解析每个地图相关信息）
        REM 注意这里需要保留下面的空行，不要删除它
        set MAPS_TO_COOK=!MAPS_TO_COOK:+=^

       !
        set BASE_CONTENT=%INSTALLATION_DIR:/=\%..\Unreal\CarlaUE4\Content
        for /f "tokens=1 delims=+" %%a in ("!MAPS_TO_COOK!") do (

            REM 获取地图的文件夹路径和地图名
            for /f %%i in ("%%a") do (
                set MAP_FOLDER=%%~pi
                set MAP_NAME=%%~ni
                REM 移除地图文件夹路径中开头的'/Game'字符串
                set MAP_FOLDER=!MAP_FOLDER:~5!
            )

            REM # 复制OpenDrive文件，如果源文件存在，则创建目标文件夹并进行复制
            set SRC=!BASE_CONTENT!!MAP_FOLDER!\OpenDrive\!MAP_NAME!.xodr
            set TRG=!BUILD_FOLDER!\CarlaUE4\Content\!MAP_FOLDER!\OpenDrive\
            if exist "!SRC!" (
                mkdir "!TRG!"
                copy "!SRC!" "!TRG!"
            )

            REM # 复制导航文件，如果源文件存在，则创建目标文件夹并进行复制
            set SRC=!BASE_CONTENT!!MAP_FOLDER!\Nav\!MAP_NAME!.bin
            set TRG=!BUILD_FOLDER!\CarlaUE4\Content\!MAP_FOLDER!\Nav\
            if exist "!SRC!" (
                mkdir "!TRG!"
                copy "!SRC!" "!TRG!"
            )

            REM # 复制交通管理器地图文件，如果源文件存在，则创建目标文件夹并进行复制
            set SRC=!BASE_CONTENT!!MAP_FOLDER!\TM\!MAP_NAME!.bin
            set TRG=!BUILD_FOLDER!\CarlaUE4\Content\!MAP_FOLDER!\TM\
            if exist "!SRC!" (
                mkdir "!TRG!"
                copy "!SRC!" "!TRG!"
            )
        )

        rem 删除该包内一些特定的文件夹和文件（可能是清理不必要的文件）
        rmdir /S /Q "!BUILD_FOLDER!\CarlaUE4\Metadata"
        rmdir /S /Q "!BUILD_FOLDER!\CarlaUE4\Plugins"
        REM del "!BUILD_FOLDER!\CarlaUE4\Content\!PACKAGE_NAME!/Maps/!PROPS_MAP_NAME!"
        del "!BUILD_FOLDER!\CarlaUE4\AssetRegistry.bin"

        rem 如果需要进行压缩操作（DO_TARBALL为true）
        if %DO_TARBALL%==true (

            rem 如果是单包模式（SINGLE_PACKAGE为true），设置目标压缩文件路径变量为特定的单包文件名格式
            if %SINGLE_PACKAGE%==true (
                echo Packaging '%TARGET_ARCHIVE%'...
                set DESTINATION_ZIP=%INSTALLATION_DIR%UE4Carla/%TARGET_ARCHIVE%_%CARLA_VERSION%.zip
            ) else (
                rem 否则设置目标压缩文件路径变量为当前包对应的文件名格式
                echo Packaging '!PACKAGE_NAME!'...
                set DESTINATION_ZIP=%INSTALLATION_DIR%UE4Carla/!PACKAGE_NAME!_%CARLA_VERSION%.zip
            )

            rem 设置源文件路径和目标压缩文件路径变量，替换路径中的斜杠为反斜杠
            set SOURCE=!BUILD_FOLDER:/=\!\
            set DST_ZIP=!DESTINATION_ZIP:/=\!

            rem 进入源文件所在目录（改变当前目录）
            pushd "!SOURCE!"

            rem 如果存在7-Zip可执行文件，则使用7-Zip进行压缩，设置相关压缩参数
            if exist "%ProgramW6432%/7-Zip/7z.exe" (
                "%ProgramW6432%/7-Zip/7z.exe" a "!DST_ZIP!". -tzip -mmt -mx5
            ) else (
                rem 否则使用PowerShell的压缩命令进行更新压缩（注意这里是更新压缩，参数不同）
                rem https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.archive/compress-archive?view=powershell-6
                powershell -command "& { Compress-Archive -Update -Path * -CompressionLevel Fastest -DestinationPath '!DST_ZIP!' }"
            )

            rem 回到上一级目录（恢复之前的目录）
            popd

            rem 如果压缩过程返回错误，则跳转到错误处理分支（bad_exit）
            if errorlevel 1 goto bad_exit
            rem 打印提示信息，表明压缩文件已创建并显示压缩文件路径
            echo ZIP created at!DST_ZIP!
        )

        rem 回到上一级目录（恢复之前的目录）
        popd

        rem 如果需要进行清理操作（DO_CLEAN为true），打印提示信息并删除该包的构建文件夹及其内容
        if %DO_CLEAN%==true (
            echo %FILE_N% Removing intermediate build.
            rmdir /S /Q "!BUILD_FOLDER!"
        )
    )
)

rem ============================================================================

goto success

rem ============================================================================
rem -- Messages and Errors -----------------------------------------------------
rem ============================================================================

:success
    rem 打印空行（可能是为了格式美观）
    echo.
    rem 如果进行了打包操作，打印提示信息，显示Carla项目成功导出到的构建文件夹路径（替换路径中的斜杠为反斜杠）
    if %DO_PACKAGE%==true echo %FILE_N% Carla project successful exported to "%BUILD_FOLDER:/=\%"!
    rem 如果进行了压缩操作，打印提示信息，显示Carla项目压缩文件的路径
    if %DO_TARBALL%==true echo %FILE_N% Compress carla project exported to "%DESTINATION_ZIP%"!
    goto good_exit

:error_carla_version
    rem 打印空行（可能是为了格式美观）
    echo.
    rem 如果Carla版本未设置，打印错误提示信息
    echo %FILE_N% [ERROR] Carla Version is not set
    goto bad_exit

:error_unreal_no_found
    rem 打印空行（可能是为了格式美观）
    echo.
    rem 如果未检测到Unreal Engine，打印错误提示信息
    echo %FILE_N% [ERROR] Unreal Engine not detected
    goto bad_exit

:error_build_editor
    rem 打印空行（可能是为了格式美观）
    echo.
    rem 如果构建CarlaUE4Editor出现问题，打印错误提示信息并提示查看屏幕日志获取更多信息
    echo %FILE_N% [ERROR] There was a problem while building the CarlaUE4Editor.
    echo           [ERROR] Please read the screen log for more information.
    goto bad_exit

:error_build
    rem 打印空行（可能是为了格式美观）
    echo.
    rem 如果构建CarlaUE4出现问题，打印错误提示信息并提示查看屏幕日志获取更多信息
    echo %FILE_N% [ERROR] There was a problem while building the CarlaUE4.
    echo           [ERROR] Please read the screen log for more information.
    goto bad_exit

:error_runUAT
    rem 打印空行（可能是为了格式美观）
    echo.
    rem 如果打包Unreal项目出现问题，打印错误提示信息并提示查看屏幕日志获取更多信息
    echo %FILE_N% [ERROR] There was a problem while packaging Unreal project.
    echo           [ERROR] Please read the screen log for more information.
    goto bad_exit

:good_exit
    rem 结束本地化设置，恢复之前的环境设置
    endlocal
    rem 以成功状态（返回码0）退出脚本
    exit /b 0

:bad_exit
    rem 结束本地化设置，恢复之前的环境设置
    endlocal
    rem 以失败状态（返回码1）退出脚本
    exit /b 1
