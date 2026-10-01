# Implementation

[README](../README.md) · English / [한국어](IMPLEMENTATION_KO.md)

## Lid-angle input

`Sources/Mactamatone/LidSensor.swift` reads feature report 1 from Apple's `las` HID lid-angle device on a separate queue, keeping HID calls off the UI thread. This sensor is not exposed through a public Core Motion API, so availability can vary by Mac model or macOS version. The access pattern and report format were informed by [macTilt's LidSensor.swift](https://github.com/lqSky7/iphone-duo-macos-animation/blob/main/Sources/LidSensor.swift).

If the sensor cannot be used, the model switches to manual input.

## Pitch and mouth positions

`InstrumentModel.pitchAngleRange` defines 25°–130°. Pitch is clamped to that interval, mapped continuously to MIDI notes 48–84 (C3–C6), and converted to frequency. Lid-angle playback is muted below 25° or when the sensor is disconnected. Manual input uses the same pitch interval.

Five mouth positions follow the normalized pitch with two degrees of hysteresis at the boundaries, preventing small sensor fluctuations from rapidly switching images. The mouth-timbre slider changes the synthesized sound independently of the visual mouth position.

## Audio and playback halo

`OtamatoneSynth` generates audio with `AVAudioEngine`. The source callback publishes the rendered RMS level and a sequence counter through atomic C controls. The UI samples them at 30 Hz to detect actual sound and stale callbacks without doing UI work on the audio thread.

The widget and settings observe the shared `AudioActivity` state only in their glow layers. Playback uses a fixed-strength, theme-colored halo with smooth entry and exit; sound volume does not control its brightness. A two-second cycle changes its size by ±12% without rotation. Reduce Motion keeps its size fixed.

## Artwork layers

The five original Classic stage images are `Sources/Mactamatone/Resources/OtamatoneLevel0.png` through `OtamatoneLevel4.png`. Transparent cutouts are named `OtamatoneWidgetLevel0.png` through `OtamatoneWidgetLevel4.png`. The initial reference is `design/Reference.png`.

Additional transparent themes use `OtamatonePinkLevel0.png` through `OtamatoneShibaLevel4.png`, with their sources and prompts in [design/Themes](../design/Themes/README.md). Rebuild them with:

```sh
swift scripts/prepare-theme-art.swift
```

Decorated scenes are separate background layers. The settings stage places the halo above the background and below transparent instrument artwork. Classic retains its original background and floor shadow underneath that composition.

## Language and native windows

English is the default language. English and Korean strings are packaged in localized resources; stable theme and language identifiers are stored in `UserDefaults`.

Settings use a light palette with matching native control appearance, including when macOS uses Dark Mode. The titlebar is transparent while retaining native traffic-light controls. The floating widget follows the system appearance and uses Liquid Glass on macOS 26 and later.

## App icon

The supplied illustration is retained in `design/AppIcon/Otamatone-source.png`. The icon pipeline fits it into a rounded tile with a transparent margin and generates standard and Retina sizes from 16 to 1024px. The main app resource supports Finder; startup also applies the bundled icon to Dock. See the [icon guide](../design/AppIcon/README.md).
