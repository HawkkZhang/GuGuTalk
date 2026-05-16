# 应用图标

`app-icon.svg` 是当前的占位图标设计（基于品牌色 Aqua）。

## 生成 ICO

需要在 Windows 上将 SVG 转为多尺寸 ICO（建议包含 16/32/48/64/128/256）：

### 用 ImageMagick

```powershell
magick app-icon.svg -define icon:auto-resize=256,128,64,48,32,16 app-icon.ico
```

### 或在线工具

如 https://convertio.co/svg-ico/ 上传 SVG 后下载 ICO，重命名为 `app-icon.ico`。

将生成的 `app-icon.ico` 放到本目录，重新构建后会自动应用：

- 可执行文件图标
- 任务栏 / Alt+Tab 图标
- 安装包图标

托盘图标可以单独提供 `tray-icon.ico`（小尺寸，建议 16/32），通过 TrayIconManager 加载。
