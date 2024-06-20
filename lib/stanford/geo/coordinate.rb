# frozen_string_literal: true

module Stanford
  module Geo
    ##
    # Geospatial coordinate parsing
    class Coordinate
      COORD_TO_DECIMAL_REGEX = Regexp.union(
        /(?<dir>[NESW])\s*(?<deg>\d+)[°⁰º](?:(?<min>\d+)[ʹ'])?(?:(?<sec>\d+)[ʺ"])?/,
        /^\s*(?<dir>[NESW])\s*(?<deg>\d+(?:[.]\d+)?)\s*$/
      )

      attr_reader :bounds

      # @param [String] point coordinate point in degrees notation
      # @return [Float] converted value in decimal notation
      def self.coord_to_decimal(point)
        match = COORD_TO_DECIMAL_REGEX.match(point)
        return Float::INFINITY unless match

        dec = match["deg"].to_f
        dec += match["min"].to_f / 60
        dec += match["sec"].to_f / 60 / 60
        dec = -1 * dec if match["dir"] == "W" || match["dir"] == "S"
        dec
      end

      # @param [String] val Coordinates value
      # @return [String] cleaned value (strips parens and period), or the original value
      def self.cleaner_coordinate(value)
        matches = value.match(/^\(?([^)]+)\)?\.?$/)
        matches ? matches[1] : value
      end

      def self.parse_bounds(value)
        matches = cleaner_coordinate(value).match %r{\A(?<lat>[EW].+-+.+)\s*/\s*(?<lng>[NS].+-+.+)\Z}
        return { min_x: nil, min_y: nil, max_x: nil, max_y: nil } unless matches

        min_x, max_x = matches["lat"].split(/-+/).map { |x| coord_to_decimal(x) }.minmax
        min_y, max_y = matches["lng"].split(/-+/).map { |y| coord_to_decimal(y) }.minmax
        { min_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y }
      end

      def self.parse(value)
        new(**parse_bounds(value))
      end

      def initialize(min_x:, min_y:, max_x:, max_y:)
        @bounds = begin
          { min_x: Float(min_x), min_y: Float(min_y), max_x: Float(max_x), max_y: Float(max_y) }
        rescue TypeError, ArgumentError
          {}
        end
      end

      # @return [String] the coordinate in WKT/CQL ENVELOPE representation
      def as_envelope
        return unless valid?

        "ENVELOPE(#{bounds[:min_x]}, #{bounds[:max_x]}, #{bounds[:max_y]}, #{bounds[:min_y]})"
      end

      # @return [String] the coordinate in Solr 4.x+ bbox-format representation
      def as_bbox
        return unless valid?

        "#{bounds[:min_x]} #{bounds[:min_y]} #{bounds[:max_x]} #{bounds[:max_y]}"
      end

      # @return [Boolean] true iff the coordinates are geographically valid
      def valid?
        return false if bounds.empty?

        range_x = -180.0..180.0
        range_y = -90.0..90.0

        range_x.include?(bounds[:min_x]) &&
          range_x.include?(bounds[:max_x]) &&
          range_y.include?(bounds[:min_y]) &&
          range_y.include?(bounds[:max_y])
      end
    end
  end
end
