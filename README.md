# pura-bmp

A pure Ruby BMP decoder/encoder without additional image-processing libraries.

Part of the **pura-*** series — pure Ruby image codec gems.

## Features

- BMP decoding and encoding (24-bit RGB)
- Image resizing (bilinear / nearest-neighbor / fit / fill)
- No image-specific native extension or FFI dependency
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

These historical measurements include ffmpeg process startup. They do not compare against an in-process C codec or establish Rails pipeline throughput.

400×400 image, Ruby 4.0.2 + YJIT.

### Decode

| Decoder | Time |
|---------|------|
| **pura-bmp** | **39 ms** |
| ffmpeg (C) | 59 ms |


### Encode

| Encoder | Time | vs ffmpeg |
|---------|------|-----------|
| **pura-bmp** | **35 ms** | **0.6× — faster than ffmpeg!** |
| ffmpeg (C) | 58 ms | — |

## Why pure Ruby?

- **`gem install` and go** — no `brew install`, no `apt install`, no C compiler needed
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

## Pixel model and limitations

Images contain 8-bit RGB pixels. Decoded pixels are RGB; any alpha channel is discarded. Encoding writes 24-bit RGB BMP.

`crop(x, y, width, height)` requires integer coordinates, positive dimensions, and a region entirely inside the image; invalid regions raise `ArgumentError`.

## License

MIT
