@echo off
echo 🚀 开始构建和打包AI聊天应用...

cd /d "%~dp0"

echo 📦 构建MSIX安装包...
flutter pub run msix:create

if %errorlevel% neq 0 (
    echo ❌ 构建失败
    pause
    exit /b 1
)

echo ✅ 构建成功！

echo 📋 复制用户配置指南...
if exist "build\windows\x64\runner\Release" (
    copy "USER_SETUP_GUIDE.md" "build\windows\x64\runner\Release\"
    echo 📄 配置指南已添加到发布包
)

echo 🎉 发布包准备完成！
echo.
echo 📂 安装包位置: build\windows\x64\runner\Release\
echo 📖 配置指南: USER_SETUP_GUIDE.md (已包含在发布包中)
echo.
echo 💡 重要提醒:
echo   - 将安装包发送给用户前，请确保他们了解需要配置OpenAI API密钥
echo   - 配置指南已包含在发布包中，用户可以直接查看
echo.
pause