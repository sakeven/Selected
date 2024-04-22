macOS App 如何配置自定义字体。具体参考 https://stackoverflow.com/a/57412354

1. Create a folder named Fonts.

![enter image description here](https://i.stack.imgur.com/vVCFC.png)

2. Add fonts to the `Fonts` folder. Uncheck `Add to targets` and check `Copy items if needed`.

![enter image description here](https://i.stack.imgur.com/6unon.png)

3. Add `Application fonts resource path` to Info.plist and enter `Fonts`.

![enter image description here](https://i.stack.imgur.com/Mwji4.png)

4. Go to `Build Phases` and create a `New Copy Files Phase`.

![enter image description here](https://i.stack.imgur.com/8k0Jl.png)

5. Set the `Destinations` to `Resources` and `Subpath` to `Fonts`. Then add your font files to the list.

![enter image description here](https://i.stack.imgur.com/ptkFy.png)

6. 获取字体名称

   ```swift
   for family: String in NSFontManager.shared.availableFontFamilies {
       print("\(family)")
       for name in NSFontManager.shared.availableMembers(ofFontFamily: family)! {
           print("== \(name[0])")
       }
   }
   ```

   