# frozen_string_literal: true

require_relative "pura/bmp/version"
require_relative "pura/bmp/image"
require_relative "pura/bmp/decoder"
require_relative "pura/bmp/encoder"

module Pura
  module Bmp
    def self.decode(input)
      Decoder.decode(input)
    end

    def self.encode(image, output_path)
      Encoder.encode(image, output_path)
    end
  end
end
