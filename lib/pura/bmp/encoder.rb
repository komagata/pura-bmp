# frozen_string_literal: true

module Pura
  module Bmp
    class Encoder
      def self.encode(image, output_path)
        encoder = new(image)
        data = encoder.encode
        File.binwrite(output_path, data)
        data.bytesize
      end

      def initialize(image)
        @image = image
      end

      def encode
        width = @image.width
        height = @image.height
        pixels = @image.pixels

        stride = ((width * 3) + 3) & ~3 # Row size padded to 4-byte boundary
        padding = stride - (width * 3)
        pixel_data_size = stride * height
        file_size = 14 + 40 + pixel_data_size # File header + info header + pixel data
        pixel_offset = 14 + 40

        out = String.new(encoding: Encoding::BINARY, capacity: file_size)

        # File header (14 bytes)
        out << "BM"
        out << [file_size].pack("V")
        out << [0, 0].pack("vv") # Reserved
        out << [pixel_offset].pack("V")

        # Info header (BITMAPINFOHEADER, 40 bytes)
        out << [40].pack("V")           # Header size
        out << [width].pack("V")        # Width
        out << [height].pack("l<")      # Height (positive = bottom-up)
        out << [1].pack("v")            # Planes
        out << [24].pack("v")           # Bit depth
        out << [0].pack("V")            # Compression (BI_RGB)
        out << [pixel_data_size].pack("V") # Image size
        out << [2835].pack("l<")        # X pixels per meter (~72 DPI)
        out << [2835].pack("l<")        # Y pixels per meter (~72 DPI)
        out << [0].pack("V")            # Colors used
        out << [0].pack("V")            # Colors important

        # Pixel data (bottom-to-top, BGR order)
        pad_bytes = "\x00".b * padding
        (height - 1).downto(0) do |y|
          row_offset = y * width * 3
          width.times do |x|
            off = row_offset + (x * 3)
            r = pixels.getbyte(off)
            g = pixels.getbyte(off + 1)
            b = pixels.getbyte(off + 2)
            out << b.chr << g.chr << r.chr # BGR order
          end
          out << pad_bytes if padding.positive?
        end

        out
      end
    end
  end
end
