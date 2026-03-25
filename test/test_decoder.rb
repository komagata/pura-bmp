# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/pura-bmp"

class TestDecoder < Minitest::Test
  FIXTURE_DIR = File.join(__dir__, "fixtures")

  FIXTURE_FILES = %w[
    rgb_24bit.bmp rgba_32bit.bmp indexed_8bit.bmp indexed_4bit.bmp
    mono_1bit.bmp rle8.bmp topdown_24bit.bmp
  ].freeze

  def setup
    generate_fixtures unless FIXTURE_FILES.all? { |f| File.exist?(File.join(FIXTURE_DIR, f)) }
  end

  def test_decode_24bit
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "rgb_24bit.bmp"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    assert_equal 4 * 4 * 3, image.pixels.bytesize
    # Top-left pixel should be red
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_32bit
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "rgba_32bit.bmp"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    assert_equal 4 * 4 * 3, image.pixels.bytesize
    # Alpha is stripped, RGB preserved
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_8bit_indexed
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "indexed_8bit.bmp"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    # First pixel should be red (palette index 0 = red)
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_4bit_indexed
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "indexed_4bit.bmp"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_1bit
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "mono_1bit.bmp"))
    assert_equal 8, image.width
    assert_equal 2, image.height
    # First pixel is black (index 0)
    r, g, b = image.pixel_at(0, 0)
    assert_equal 0, r
    assert_equal 0, g
    assert_equal 0, b
    # Second pixel is white (index 1)
    r, g, b = image.pixel_at(1, 0)
    assert_equal 255, r
    assert_equal 255, g
    assert_equal 255, b
  end

  def test_decode_rle8
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "rle8.bmp"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    # First row should be all red
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_top_down
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "topdown_24bit.bmp"))
    assert_equal 4, image.width
    assert_equal 4, image.height
    # Top-left should be red (first row in file)
    r, g, b = image.pixel_at(0, 0)
    assert_equal 255, r
    assert_equal 0, g
    assert_equal 0, b
  end

  def test_decode_from_binary_data
    data = File.binread(File.join(FIXTURE_DIR, "rgb_24bit.bmp"))
    image = Pura::Bmp.decode(data)
    assert_equal 4, image.width
    assert_equal 4, image.height
  end

  def test_decode_pixel_at
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "rgb_24bit.bmp"))
    # Row 1 should be green
    r, g, b = image.pixel_at(0, 1)
    assert_equal 0, r
    assert_equal 255, g
    assert_equal 0, b
    # Row 2 should be blue
    r, g, b = image.pixel_at(0, 2)
    assert_equal 0, r
    assert_equal 0, g
    assert_equal 255, b
  end

  def test_decode_to_ppm
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "rgb_24bit.bmp"))
    ppm = image.to_ppm
    assert ppm.start_with?("P6\n4 4\n255\n".b)
    assert_equal "P6\n4 4\n255\n".bytesize + (4 * 4 * 3), ppm.bytesize
  end

  def test_decode_to_rgb_array
    image = Pura::Bmp.decode(File.join(FIXTURE_DIR, "rgb_24bit.bmp"))
    arr = image.to_rgb_array
    assert_equal 16, arr.size
    assert_equal [255, 0, 0], arr[0]
  end

  def test_decode_invalid_signature
    assert_raises(Pura::Bmp::DecodeError) do
      Pura::Bmp.decode("XX\x00\x00".b * 20)
    end
  end

  private

  def generate_fixtures
    FileUtils.mkdir_p(FIXTURE_DIR)

    generate_24bit
    generate_32bit
    generate_8bit_indexed
    generate_4bit_indexed
    generate_1bit
    generate_rle8
    generate_topdown_24bit
  end

  def generate_24bit
    width = 4
    height = 4
    # Rows: red, green, blue, white (in display order, top to bottom)
    rows = [
      [[255, 0, 0]] * 4,   # Row 0: red
      [[0, 255, 0]] * 4,   # Row 1: green
      [[0, 0, 255]] * 4,   # Row 2: blue
      [[255, 255, 255]] * 4 # Row 3: white
    ]
    write_24bit_bmp(File.join(FIXTURE_DIR, "rgb_24bit.bmp"), width, height, rows)
  end

  def generate_32bit
    width = 4
    height = 4
    rows = [
      [[255, 0, 0]] * 4,
      [[0, 255, 0]] * 4,
      [[0, 0, 255]] * 4,
      [[255, 255, 255]] * 4
    ]
    write_32bit_bmp(File.join(FIXTURE_DIR, "rgba_32bit.bmp"), width, height, rows)
  end

  def generate_8bit_indexed
    width = 4
    height = 4
    palette = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255]]
    indices = [
      [0] * 4, # red
      [1] * 4, # green
      [2] * 4, # blue
      [3] * 4  # white
    ]
    write_indexed_bmp(File.join(FIXTURE_DIR, "indexed_8bit.bmp"), width, height, 8, palette, indices)
  end

  def generate_4bit_indexed
    width = 4
    height = 4
    palette = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255]]
    # Pad palette to 16 entries
    12.times { palette << [0, 0, 0] }
    indices = [
      [0] * 4, # red
      [1] * 4, # green
      [2] * 4, # blue
      [3] * 4  # white
    ]
    write_indexed_bmp(File.join(FIXTURE_DIR, "indexed_4bit.bmp"), width, height, 4, palette, indices)
  end

  def generate_1bit
    width = 8
    height = 2
    palette = [[0, 0, 0], [255, 255, 255]]
    indices = [
      [0, 1, 0, 1, 0, 1, 0, 1], # alternating
      [1, 0, 1, 0, 1, 0, 1, 0]
    ]
    write_indexed_bmp(File.join(FIXTURE_DIR, "mono_1bit.bmp"), width, height, 1, palette, indices)
  end

  def generate_rle8
    width = 4
    height = 4
    palette = [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255]]
    # Pad palette to 256 entries
    252.times { palette << [0, 0, 0] }

    # Build RLE8 data
    rle = String.new(encoding: Encoding::BINARY)
    # Rows stored bottom-to-top: row 3 first (white), then 2 (blue), 1 (green), 0 (red)
    # Row 3: 4x index 3 (white), end of line
    rle << [4, 3].pack("CC")  # Run: 4 pixels of color 3
    rle << [0, 0].pack("CC")  # End of line
    # Row 2: 4x index 2 (blue), end of line
    rle << [4, 2].pack("CC")
    rle << [0, 0].pack("CC")
    # Row 1: 4x index 1 (green), end of line
    rle << [4, 1].pack("CC")
    rle << [0, 0].pack("CC")
    # Row 0: 4x index 0 (red), end of bitmap
    rle << [4, 0].pack("CC")
    rle << [0, 1].pack("CC") # End of bitmap

    write_rle8_bmp(File.join(FIXTURE_DIR, "rle8.bmp"), width, height, palette, rle)
  end

  def generate_topdown_24bit
    width = 4
    height = 4
    rows = [
      [[255, 0, 0]] * 4,
      [[0, 255, 0]] * 4,
      [[0, 0, 255]] * 4,
      [[255, 255, 255]] * 4
    ]
    write_24bit_bmp(File.join(FIXTURE_DIR, "topdown_24bit.bmp"), width, height, rows, top_down: true)
  end

  # BMP file writers for generating test fixtures

  def write_24bit_bmp(path, width, height, rows, top_down: false)
    stride = ((width * 3) + 3) & ~3
    padding = stride - (width * 3)
    pixel_data_size = stride * height
    file_size = 14 + 40 + pixel_data_size

    out = String.new(encoding: Encoding::BINARY)
    # File header
    out << "BM"
    out << [file_size].pack("V")
    out << [0, 0].pack("vv")
    out << [54].pack("V") # Pixel offset

    # Info header
    out << [40].pack("V")
    out << [width].pack("V")
    h_val = top_down ? -height : height
    out << [h_val].pack("l<")
    out << [1].pack("v")   # Planes
    out << [24].pack("v")  # Bits per pixel
    out << [0].pack("V")   # Compression
    out << [pixel_data_size].pack("V")
    out << [0].pack("l<")  # X ppm
    out << [0].pack("l<")  # Y ppm
    out << [0].pack("V")   # Colors used
    out << [0].pack("V")   # Colors important

    # Pixel data
    ordered = top_down ? rows : rows.reverse
    ordered.each do |row|
      row.each do |r, g, b|
        out << b.chr << g.chr << r.chr # BGR
      end
      padding.times { out << "\x00" }
    end

    File.binwrite(path, out)
  end

  def write_32bit_bmp(path, width, height, rows)
    pixel_data_size = width * 4 * height
    file_size = 14 + 40 + pixel_data_size

    out = String.new(encoding: Encoding::BINARY)
    out << "BM"
    out << [file_size].pack("V")
    out << [0, 0].pack("vv")
    out << [54].pack("V")

    out << [40].pack("V")
    out << [width].pack("V")
    out << [height].pack("l<")
    out << [1].pack("v")
    out << [32].pack("v")
    out << [0].pack("V") # BI_RGB
    out << [pixel_data_size].pack("V")
    out << [0].pack("l<")
    out << [0].pack("l<")
    out << [0].pack("V")
    out << [0].pack("V")

    rows.reverse.each do |row|
      row.each do |r, g, b|
        out << [b, g, r, 255].pack("CCCC") # BGRA
      end
    end

    File.binwrite(path, out)
  end

  def write_indexed_bmp(path, width, height, bit_depth, palette, indices)
    num_colors = palette.size
    case bit_depth
    when 8
      row_bytes = width
    when 4
      row_bytes = (width + 1) / 2
    when 1
      row_bytes = (width + 7) / 8
    end
    stride = (row_bytes + 3) & ~3
    padding = stride - row_bytes
    pixel_data_size = stride * height
    palette_size = num_colors * 4
    pixel_offset = 14 + 40 + palette_size
    file_size = pixel_offset + pixel_data_size

    out = String.new(encoding: Encoding::BINARY)
    out << "BM"
    out << [file_size].pack("V")
    out << [0, 0].pack("vv")
    out << [pixel_offset].pack("V")

    out << [40].pack("V")
    out << [width].pack("V")
    out << [height].pack("l<")
    out << [1].pack("v")
    out << [bit_depth].pack("v")
    out << [0].pack("V") # BI_RGB
    out << [pixel_data_size].pack("V")
    out << [0].pack("l<")
    out << [0].pack("l<")
    out << [num_colors].pack("V")
    out << [0].pack("V")

    # Palette (BGRA)
    palette.each do |r, g, b|
      out << b.chr << g.chr << r.chr << "\x00"
    end

    # Pixel data (bottom-to-top)
    indices.reverse.each do |row|
      case bit_depth
      when 8
        row.each { |idx| out << idx.chr }
      when 4
        row.each_slice(2) do |pair|
          high = pair[0]
          low = pair[1] || 0
          out << ((high << 4) | low).chr
        end
      when 1
        row.each_slice(8) do |bits|
          byte = 0
          bits.each_with_index { |bit, i| byte |= (bit << (7 - i)) }
          out << byte.chr
        end
      end
      padding.times { out << "\x00" }
    end

    File.binwrite(path, out)
  end

  def write_rle8_bmp(path, width, height, palette, rle_data)
    num_colors = palette.size
    palette_size = num_colors * 4
    pixel_offset = 14 + 40 + palette_size
    file_size = pixel_offset + rle_data.bytesize

    out = String.new(encoding: Encoding::BINARY)
    out << "BM"
    out << [file_size].pack("V")
    out << [0, 0].pack("vv")
    out << [pixel_offset].pack("V")

    out << [40].pack("V")
    out << [width].pack("V")
    out << [height].pack("l<")
    out << [1].pack("v")
    out << [8].pack("v")
    out << [1].pack("V") # BI_RLE8
    out << [rle_data.bytesize].pack("V")
    out << [0].pack("l<")
    out << [0].pack("l<")
    out << [num_colors].pack("V")
    out << [0].pack("V")

    palette.each do |r, g, b|
      out << b.chr << g.chr << r.chr << "\x00"
    end

    out << rle_data
    File.binwrite(path, out)
  end
end
