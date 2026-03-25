# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/pura-bmp"

class TestEncoder < Minitest::Test
  TMP_DIR = File.join(__dir__, "tmp")

  def setup
    FileUtils.mkdir_p(TMP_DIR)
  end

  def teardown
    Dir.glob(File.join(TMP_DIR, "*")).each { |f| File.delete(f) }
    FileUtils.rm_f(TMP_DIR)
  end

  def test_encode_creates_valid_bmp
    image = create_red_image(8, 8)
    path = File.join(TMP_DIR, "test_output.bmp")
    size = Pura::Bmp.encode(image, path)
    assert size.positive?
    assert File.exist?(path)

    # Verify BMP signature
    data = File.binread(path)
    assert_equal "BM", data.byteslice(0, 2)
  end

  def test_encode_decode_roundtrip
    image = create_gradient_image(16, 16)
    path = File.join(TMP_DIR, "roundtrip.bmp")
    Pura::Bmp.encode(image, path)

    decoded = Pura::Bmp.decode(path)
    assert_equal 16, decoded.width
    assert_equal 16, decoded.height
    assert_equal image.pixels, decoded.pixels
  end

  def test_encode_decode_roundtrip_solid_colors
    [[255, 0, 0], [0, 255, 0], [0, 0, 255], [255, 255, 255], [0, 0, 0]].each do |color|
      pixels = color.pack("C3").b * (8 * 8)
      image = Pura::Bmp::Image.new(8, 8, pixels)
      path = File.join(TMP_DIR, "solid_#{color.join("_")}.bmp")
      Pura::Bmp.encode(image, path)

      decoded = Pura::Bmp.decode(path)
      r, g, b = decoded.pixel_at(4, 4)
      assert_equal color[0], r, "Red mismatch for #{color}"
      assert_equal color[1], g, "Green mismatch for #{color}"
      assert_equal color[2], b, "Blue mismatch for #{color}"
    end
  end

  def test_encode_preserves_pixel_data_exactly
    pixels = String.new(encoding: Encoding::BINARY)
    256.times do |i|
      pixels << [i, (i * 2) & 0xFF, (i * 3) & 0xFF].pack("C3")
    end
    image = Pura::Bmp::Image.new(16, 16, pixels)
    path = File.join(TMP_DIR, "exact_pixels.bmp")
    Pura::Bmp.encode(image, path)

    decoded = Pura::Bmp.decode(path)
    assert_equal pixels, decoded.pixels
  end

  def test_encode_various_sizes
    [[1, 1], [3, 5], [100, 1], [1, 100], [64, 64]].each do |w, h|
      pixels = "\x80\x80\x80".b * (w * h)
      image = Pura::Bmp::Image.new(w, h, pixels)
      path = File.join(TMP_DIR, "size_#{w}x#{h}.bmp")
      Pura::Bmp.encode(image, path)

      decoded = Pura::Bmp.decode(path)
      assert_equal w, decoded.width
      assert_equal h, decoded.height
      assert_equal pixels, decoded.pixels
    end
  end

  def test_encode_from_image_class
    image = Pura::Bmp::Image.new(2, 2, "\xFF\x00\x00\x00\xFF\x00\x00\x00\xFF\xFF\xFF\xFF".b)
    path = File.join(TMP_DIR, "from_image.bmp")
    Pura::Bmp.encode(image, path)

    decoded = Pura::Bmp.decode(path)
    assert_equal [255, 0, 0], decoded.pixel_at(0, 0)
    assert_equal [0, 255, 0], decoded.pixel_at(1, 0)
    assert_equal [0, 0, 255], decoded.pixel_at(0, 1)
    assert_equal [255, 255, 255], decoded.pixel_at(1, 1)
  end

  def test_encode_file_structure
    image = create_red_image(4, 4)
    path = File.join(TMP_DIR, "structure.bmp")
    Pura::Bmp.encode(image, path)
    data = File.binread(path)

    # Check file header
    assert_equal "BM", data.byteslice(0, 2)
    file_size = data.byteslice(2, 4).unpack1("V")
    assert_equal data.bytesize, file_size

    pixel_offset = data.byteslice(10, 4).unpack1("V")
    assert_equal 54, pixel_offset

    # Check info header
    header_size = data.byteslice(14, 4).unpack1("V")
    assert_equal 40, header_size

    width = data.byteslice(18, 4).unpack1("V")
    assert_equal 4, width

    bit_depth = data.byteslice(28, 2).unpack1("v")
    assert_equal 24, bit_depth
  end

  private

  def create_red_image(w, h)
    pixels = "\xFF\x00\x00".b * (w * h)
    Pura::Bmp::Image.new(w, h, pixels)
  end

  def create_gradient_image(w, h)
    pixels = String.new(encoding: Encoding::BINARY, capacity: w * h * 3)
    h.times do |y|
      w.times do |x|
        r = (x * 255 / [w - 1, 1].max)
        g = (y * 255 / [h - 1, 1].max)
        b = 128
        pixels << r.chr << g.chr << b.chr
      end
    end
    Pura::Bmp::Image.new(w, h, pixels)
  end
end
