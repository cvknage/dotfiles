# AU Lab

> [!NOTE]
> **Use [Hosting AU](https://ju-x.com/hostingau.html) instead of AU Lab.**  
> * Hosting AU uses the same `.aupreset` files.  
> * Hosting AU installs without issues.  
> * Hosting AU is more stable for longer sessions.  
> * AU Lab accumulates buffer drift over time and you start hearing static, cracks and pops after about 20 minutes.

## Presets for Apple AU Lab

1. Place `.aupreset` files in `~/Library/Audio/Presets/Apple/AUGraphicEQ`
2. Load `.trak` files in AU Lab

> [!TIP]
> Download **"Additional Tools for Xcode"** from [https://developer.apple.com/download](https://developer.apple.com/download)  
> AU Labs is not configured correctly to request **Microphone permissions** under: **Settings > Privacy and Security > Microphone**
> 
> Remove all Microphone permissions (if needed):
> ``` sh
> tccutil reset Microphone
> ```
> 
> Add the `NSMicrophoneUsageDescription` key to the application's Info.plist.  
> Open AU Lab by right-click AU Lab -> Show Package Contents -> Contents -> Info.plist:
> ``` xml
> <key>NSMicrophoneUsageDescription</key>
> <string>Need microphone access for uploading audio</string>
> ```
> 
> Update the code signarure:
> ``` sh
> sudo codesign --force --deep --sign - "/Applications/AU Lab.app"
> ```
>
> Restart CoreAudio:
> ``` sh
> sudo killall coreaudiod
> ```

