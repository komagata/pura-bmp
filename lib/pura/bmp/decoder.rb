# frozen_string_literal: true

module Pura
  module Bmp
    class DecodeError < StandardError; end

    class Decoder
      # Compression types
      BI_RGB  = 0
      BI_RLE8 = 1
      BI_RLE4 = 2
      BI_BITFIELDS = 3

      def self.decode(input)
        data = if input.is_a?(String) && !input.include?("\x00") && input.bytesize < 4096 && File.exist?(input)
                 File.binread(input)
               else
                 input.b
               end
        new(data).decode
      end

      def initialize(data)
        @data = data
        @pos = 0
      end

      def decode
        # File header (14 bytes)
        magic = read_bytes(2)
        raise DecodeError, "Not a BMP file (missing BM signature)" unless magic == "BM"

        _file_size = read_uint32_le
        _reserved1 = read_uint16_le
        _reserved2 = read_uint16_le
        pixel_offset = read_uint32_le

        # Info header
        header_size = read_uint32_le
        raise DecodeError, "Unsupported BMP header size: #{header_size}" unless header_size >= 40

        width = read_int32_le
        height = read_int32_le
        _planes = read_uint16_le
        bit_depth = read_uint16_le
        compression = read_uint32_le
        _image_size = read_uint32_le
        _x_ppm = read_int32_le
        _y_ppm = read_int32_le
        colors_used = read_uint32_le
        _colors_important = read_uint32_le

        # Handle negative height (top-down storage)
        top_down = height.negative?
        height = height.abs

        raise DecodeError, "Invalid dimensions: #{width}x#{height}" if width <= 0 || height <= 0

        # Read additional header bytes if header is larger than 40
        extra_header = header_size - 40
        bitfield_masks = nil

        if compression == BI_BITFIELDS && extra_header >= 12
          r_mask = read_uint32_le
          g_mask = read_uint32_le
          b_mask = read_uint32_le
          extra_header -= 12
          bitfield_masks = { r: r_mask, g: g_mask, b: b_mask }
        end

        skip_bytes(extra_header) if extra_header.positive?

        # Read color palette for indexed images
        palette = nil
        if bit_depth <= 8
          num_colors = colors_used.positive? ? colors_used : (1 << bit_depth)
          palette = read_palette(num_colors)
        end

        # Seek to pixel data
        @pos = pixel_offset

        # Decode pixel data
        pixels = case bit_depth
                 when 24
                   decode_24bit(width, height, top_down)
                 when 32
                   decode_32bit(width, height, top_down, bitfield_masks)
                 when 8
                   if compression == BI_RLE8
                     decode_rle8(width, height, top_down, palette)
                   else
                     decode_8bit(width, height, top_down, palette)
                   end
                 when 4
                   decode_4bit(width, height, top_down, palette)
                 when 1
                   decode_1bit(width, height, top_down, palette)
                 else
                   raise DecodeError, "Unsupported bit depth: #{bit_depth}"
                 end

        Image.new(width, height, pixels)
      end

      private

      def read_bytes(n)
        raise DecodeError, "Unexpected end of data" if @pos + n > @data.bytesize

        result = @data.byteslice(@pos, n)
        @pos += n
        result
      end

      def read_uint16_le
        bytes = read_bytes(2)
        bytes.unpack1("v")
      end

      def read_uint32_le
        bytes = read_bytes(4)
        bytes.unpack1("V")
      end

      def read_int32_le
        bytes = read_bytes(4)
        bytes.unpack1("l<")
      end

      def skip_bytes(n)
        @pos += n
      end

      def read_palette(num_colors)
        palette = Array.new(num_colors)
        num_colors.times do |i|
          b = @data.getbyte(@pos)
          g = @data.getbyte(@pos + 1)
          r = @data.getbyte(@pos + 2)
          _a = @data.getbyte(@pos + 3)
          @pos += 4
          palette[i] = [r, g, b]
        end
        palette
      end

      def decode_24bit(width, height, top_down)
        stride = ((width * 3) + 3) & ~3 # Row size padded to 4-byte boundary
        out = String.new(encoding: Encoding::BINARY, capacity: width * height * 3)
        rows = []

        height.times do
          row = String.new(encoding: Encoding::BINARY, capacity: width * 3)
          width.times do
            b = @data.getbyte(@pos)
            g = @data.getbyte(@pos + 1)
            r = @data.getbyte(@pos + 2)
            @pos += 3
            row << r.chr << g.chr << b.chr
          end
          # Skip padding bytes
          padding = stride - (width * 3)
          @pos += padding
          rows << row
        end

        # BMP stores rows bottom-to-top (unless top-down)
        rows.reverse! unless top_down
        rows.each { |r| out << r }
        out
      end

      def decode_32bit(width, height, top_down, bitfield_masks)
        out = String.new(encoding: Encoding::BINARY, capacity: width * height * 3)
        rows = []

        # Default masks for standard 32-bit BGRA
        if bitfield_masks
          r_mask = bitfield_masks[:r]
          g_mask = bitfield_masks[:g]
          b_mask = bitfield_masks[:b]
          r_shift = mask_shift(r_mask)
          g_shift = mask_shift(g_mask)
          b_shift = mask_shift(b_mask)
          r_max = mask_max(r_mask)
          g_max = mask_max(g_mask)
          b_max = mask_max(b_mask)
        end

        height.times do
          row = String.new(encoding: Encoding::BINARY, capacity: width * 3)
          width.times do
            if bitfield_masks
              val = @data.byteslice(@pos, 4).unpack1("V")
              @pos += 4
              r = r_max.positive? ? ((val & r_mask) >> r_shift) * 255 / r_max : 0
              g = g_max.positive? ? ((val & g_mask) >> g_shift) * 255 / g_max : 0
              b = b_max.positive? ? ((val & b_mask) >> b_shift) * 255 / b_max : 0
            else
              b = @data.getbyte(@pos)
              g = @data.getbyte(@pos + 1)
              r = @data.getbyte(@pos + 2)
              # skip alpha byte
              @pos += 4
            end
            row << r.chr << g.chr << b.chr
          end
          rows << row
        end

        rows.reverse! unless top_down
        rows.each { |r| out << r }
        out
      end

      def decode_8bit(width, height, top_down, palette)
        raise DecodeError, "Missing palette for 8-bit image" unless palette

        stride = (width + 3) & ~3 # Row size padded to 4-byte boundary
        out = String.new(encoding: Encoding::BINARY, capacity: width * height * 3)
        rows = []

        height.times do
          row = String.new(encoding: Encoding::BINARY, capacity: width * 3)
          width.times do
            idx = @data.getbyte(@pos)
            @pos += 1
            r, g, b = palette[idx] || [0, 0, 0]
            row << r.chr << g.chr << b.chr
          end
          padding = stride - width
          @pos += padding
          rows << row
        end

        rows.reverse! unless top_down
        rows.each { |r| out << r }
        out
      end

      def decode_rle8(width, height, top_down, palette)
        raise DecodeError, "Missing palette for RLE8 image" unless palette

        # Initialize pixel buffer to black
        pixel_buf = Array.new(width * height * 3, 0)
        x = 0
        y = 0

        while @pos < @data.bytesize
          count = @data.getbyte(@pos)
          value = @data.getbyte(@pos + 1)
          @pos += 2

          if count.positive?
            # Encoded run: repeat value count times
            count.times do
              if x < width && y < height
                r, g, b = palette[value] || [0, 0, 0]
                offset = ((y * width) + x) * 3
                pixel_buf[offset] = r
                pixel_buf[offset + 1] = g
                pixel_buf[offset + 2] = b
              end
              x += 1
            end
          else
            case value
            when 0 # End of line
              x = 0
              y += 1
            when 1 # End of bitmap
              break
            when 2 # Delta
              dx = @data.getbyte(@pos)
              dy = @data.getbyte(@pos + 1)
              @pos += 2
              x += dx
              y += dy
            else
              # Absolute mode: read 'value' literal pixels
              value.times do
                idx = @data.getbyte(@pos)
                @pos += 1
                if x < width && y < height
                  r, g, b = palette[idx] || [0, 0, 0]
                  offset = ((y * width) + x) * 3
                  pixel_buf[offset] = r
                  pixel_buf[offset + 1] = g
                  pixel_buf[offset + 2] = b
                end
                x += 1
              end
              # Absolute runs are padded to word boundary
              @pos += 1 if value.odd?
            end
          end
        end

        # Build output: RLE stores rows bottom-to-top by default
        out = String.new(encoding: Encoding::BINARY, capacity: width * height * 3)
        if top_down
          height.times do |row|
            offset = row * width * 3
            width.times do |col|
              off = offset + (col * 3)
              out << pixel_buf[off].chr << pixel_buf[off + 1].chr << pixel_buf[off + 2].chr
            end
          end
        else
          (height - 1).downto(0) do |row|
            offset = row * width * 3
            width.times do |col|
              off = offset + (col * 3)
              out << pixel_buf[off].chr << pixel_buf[off + 1].chr << pixel_buf[off + 2].chr
            end
          end
        end

        out
      end

      def decode_4bit(width, height, top_down, palette)
        raise DecodeError, "Missing palette for 4-bit image" unless palette

        row_bytes = (width + 1) / 2
        stride = (row_bytes + 3) & ~3
        out = String.new(encoding: Encoding::BINARY, capacity: width * height * 3)
        rows = []

        height.times do
          row = String.new(encoding: Encoding::BINARY, capacity: width * 3)
          x = 0
          row_bytes.times do
            byte = @data.getbyte(@pos)
            @pos += 1

            # High nibble first
            if x < width
              idx = (byte >> 4) & 0x0F
              r, g, b = palette[idx] || [0, 0, 0]
              row << r.chr << g.chr << b.chr
              x += 1
            end

            # Low nibble
            next unless x < width

            idx = byte & 0x0F
            r, g, b = palette[idx] || [0, 0, 0]
            row << r.chr << g.chr << b.chr
            x += 1
          end
          padding = stride - row_bytes
          @pos += padding
          rows << row
        end

        rows.reverse! unless top_down
        rows.each { |r| out << r }
        out
      end

      def decode_1bit(width, height, top_down, palette)
        raise DecodeError, "Missing palette for 1-bit image" unless palette

        row_bytes = (width + 7) / 8
        stride = (row_bytes + 3) & ~3
        out = String.new(encoding: Encoding::BINARY, capacity: width * height * 3)
        rows = []

        height.times do
          row = String.new(encoding: Encoding::BINARY, capacity: width * 3)
          x = 0
          row_bytes.times do
            byte = @data.getbyte(@pos)
            @pos += 1

            8.times do |bit|
              break if x >= width

              idx = (byte >> (7 - bit)) & 1
              r, g, b = palette[idx] || [0, 0, 0]
              row << r.chr << g.chr << b.chr
              x += 1
            end
          end
          padding = stride - row_bytes
          @pos += padding
          rows << row
        end

        rows.reverse! unless top_down
        rows.each { |r| out << r }
        out
      end

      def mask_shift(mask)
        return 0 if mask.zero?

        shift = 0
        shift += 1 while (mask >> shift).nobits?(1)
        shift
      end

      def mask_max(mask)
        return 0 if mask.zero?

        mask >> mask_shift(mask)
      end
    end
  end
end
