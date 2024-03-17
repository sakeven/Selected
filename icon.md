# icon 尺寸 

1024*1024 px 大小，背景透明，png 格式

内容为 824*824 px

# 生成办法
创建一个名为 icons.iconset 的文件夹：

``` bash
mkdir icons.iconset 
```

生成各种尺寸的 png 图片
通过 终端 来快速创建各种不同尺寸要求的图片文件。

```bash
sips -z 16 16 icon.png -o icons.iconset/icon_16x16.png 
sips -z 32 32 icon.png -o icons.iconset/icon_16x16@2x.png 
sips -z 32 32 icon.png -o icons.iconset/icon_32x32.png 
sips -z 64 64 icon.png -o icons.iconset/icon_32x32@2x.png 
sips -z 128 128 icon.png -o icons.iconset/icon_128x128.png 
sips -z 256 256 icon.png -o icons.iconset/icon_128x128@2x.png 
sips -z 256 256 icon.png -o icons.iconset/icon_256x256.png 
sips -z 512 512 icon.png -o icons.iconset/icon_256x256@2x.png 
sips -z 512 512 icon.png -o icons.iconset/icon_512x512.png 
sips -z 1024 1024 icon.png -o icons.iconset/icon_512x512@2x.png 
```

# 导入
导入到 Assets 里的 AppIcon 里。
