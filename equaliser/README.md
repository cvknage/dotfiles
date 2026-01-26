# Equaliser Presets

This folder contains EQ presets derived from headphone measurements and tuned targets.  
Presets are stored in native formats:  
- macOS: `.aupreset` (AUNBandEQ)
- Linux: EasyEffects preset formats

These are loaded into the respective applications.

## Reference tools

- **AutoEQ** — https://autoeq.app/  
  Used to generate baseline EQs that match a selected target curve most commonly [Harman](https://headphones.com/pages/measurements-and-frequency-response).  
  AutoEQ does this by algorithmically matching headphone measurements (e.g. [Oratory1990](https://www.reddit.com/r/oratory1990/), [Crinacle](https://crinacle.com/), others) to the chosen target curve.  
  [Oratory1990](https://www.reddit.com/r/oratory1990/) also publishes [hand-tuned Harman presets](https://www.reddit.com/r/oratory1990/wiki/index/list_of_presets/) based on his own measurements. These are often perceived as slightly more natural than fully algorithm-generated AutoEQ results, though they are generally close.

- **Squig.link** — https://squig.link/  
  Used to compare measurements and fine-tune EQs by ear.  
  SquigLink also generates baseline EQs that match a selected target curve, but its a lot more powerful when it comes to fine tuning.

## Target curves (context)

- **Harman** — Elevated bass, smooth treble; modern “pleasing” reference.
- **Diffuse Field (DF)** — Leaner and brighter; closer to a studio reference.
- **Neutral / Custom** — Adjusted by ear from measurements.

While Harman is a good baseline for most listeners, preferences vary, and some headphones do not respond well to 
aggressive EQ (e.g. distortion or odd tonal artifacts).

## Naming convention

``` txt
<Headphone>_<Target|Custom>[_Genre][_<Source>][_EqType]
```

- `_Genre` is optional and mainly used for custom tunings.
- `_Source` is optional and only used for non custom tunings.
- `_EqType` is optional used to denote the EQ type used.

Examples:
- `DT900ProX_Harman_AutoEQ_AUNBandEQ`
- `DT900ProX_Custom_MelodicMetal_AUGraphicEQ`

## Notes

**Applications**:  

Linux:  
* [EasyEffects](https://wwmm.github.io/easyeffects/)

macOS:  
* [AU Lab](https://www.apple.com/apple-music/apple-digital-masters/)
* [Hosting AU](https://ju-x.com/hostingau.html)
* [Vizzdom Analyzer with EQ](https://www.krisdigital.com/en/blog/2018/08/23/vizzdom-mac-system-audio-spectrum-level-analyzer/)
* [SoundMax](https://snap-sites.github.io/SoundMax/)

