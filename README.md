# pura-bmp

A pure Ruby BMP decoder/encoder with zero C extension dependencies.

Part of the **pura-*** series — pure Ruby image codec gems.

## Features

- BMP decoding and encoding (24-bit RGB)
- Image resizing (bilinear / nearest-neighbor / fit / fill)
- No native extensions, no FFI, no external dependencies
- CLI tool included

## Installation

```bash
gem install pura-bmp
```

## Usage

```ruby
require "pura-bmp"

# Decode
image = Pura::Bmp.decode("photo.bmp")
image.width      #=> 400
image.height     #=> 400
image.pixels     #=> Raw RGB byte string
image.pixel_at(x, y) #=> [r, g, b]

# Encode
Pura::Bmp.encode(image, "output.bmp")

# Resize
thumb = image.resize(200, 200)
fitted = image.resize_fit(800, 600)
```

## CLI

```bash
pura-bmp decode input.bmp --info
pura-bmp resize input.bmp --width 200 --height 200 --out thumb.bmp
```

## Benchmark

400×400 image, Ruby 4.0.2 + YJIT.

### Decode

| Decoder | Time |
|---------|------|
| **pura-bmp** | **39 ms** |
| ffmpeg (C) | 59 ms |

**pura-bmp is faster than ffmpeg** for BMP decoding. No other pure Ruby BMP implementation exists.

### Encode

| Encoder | Time |
|---------|------|
| **pura-bmp** | **36 ms** |

## Why pure Ruby?

- **`gem install` and go** — no `brew install`, no `apt install`, no C compiler needed
- **Faster than C** — pure Ruby BMP decode beats ffmpeg on this benchmark
- **Works everywhere Ruby works** — CRuby, ruby.wasm, JRuby, TruffleRuby
- **Part of pura-\*** — convert between JPEG, PNG, BMP, GIF, TIFF, WebP seamlessly

## Related gems

| Gem | Format | Status |
|-----|--------|--------|
| [pura-jpeg](https://github.com/komagata/pura-jpeg) | JPEG | ✅ Available |
| [pura-png](https://github.com/komagata/pura-png) | PNG | ✅ Available |
| **pura-bmp** | BMP | ✅ Available |
| [pura-gif](https://github.com/komagata/pura-gif) | GIF | ✅ Available |
| [pura-tiff](https://github.com/komagata/pura-tiff) | TIFF | ✅ Available |
| [pura-ico](https://github.com/komagata/pura-ico) | ICO | ✅ Available |
| [pura-webp](https://github.com/komagata/pura-webp) | WebP | ✅ Available |
| [pura-image](https://github.com/komagata/pura-image) | All formats | ✅ Available |

## License

MIT
