# coding: utf-8
# Copyright 2019 Mikko Värri <mikko@varri.fi>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'logger'

##
# Extension to InfluxDB module.
#
module InfluxDB
  ##
  # Line Protocol module.
  #
  module LineProtocol

    ##
    # Line Protocol parser.
    #
    class Parser
      def initialize(logger: nil, escapes: nil)
        if logger
          @log = logger
        else
          @log = ::Logger.new(STDERR)
          @log.level = :warn
        end
        case escapes
        when :compat
          @unescapes = InfluxDB::LineProtocol::CompatUnescapes.new
        else
          @unescapes = InfluxDB::LineProtocol::Unescapes.new
        end
        enter_whitespace0
      end

      ##
      # Parse the points from data.
      #
      # If block is given, yields each point in data.
      #
      # If block is not given, returns a list of points in data.
      #
      # The data can be a String, or a single Integer or an Array of Integers.
      # The Integers are assumed to be UTF-8 bytes.
      #
      def each_point(data)
        buf = bytes(data)
        i = 0
        len = buf.size

        points = block_given? ? nil : []

        while i < len
          i = self.send(@state, buf, i, len)
          if @state == :complete
            if block_given?
              yield @point
            else
              points << @point
            end
            enter_whitespace0
          end
        end

        points
      end

      private

      def enter_whitespace0
        @point = nil
        @state = :whitespace0
        @escaped = false
        @buf = nil
        @key = nil
      end

      UTF_8 = Encoding.find 'UTF-8'
      UTF_8_PACK_FORMAT = 'C*'.freeze

      # All the special bytes Line Protocol handles.
      # In UTF-8, these are all single byte characters.
      # Any multi-byte characters are just skipped as part of the tokens (measurement, tag key, tag value, ...).
      BACKSLASH = 92
      COMMA = 44
      EQUALS = 61
      HASH = 35
      NEWLINE = 10
      NULL = 0
      SPACE = 32
      TAB = 9

      # Start (and end) marker of a string field value (not special anywhere else)
      QUOTATION_MARK = 34

      # Start markers of a numeric field value (not special anywhere else)
      PLUS_SIGN = 43
      MINUS_SIGN = 45
      DECIMAL_POINT = 46
      DIGIT_ZERO = 48
      DIGIT_NINE = 57

      # Start markers of a Boolean field value (not special anywhere else)
      LATIN_CAPITAL_LETTER_F = 70
      LATIN_CAPITAL_LETTER_T = 84
      LATIN_SMALL_LETTER_F = 102
      LATIN_SMALL_LETTER_T = 116



      def whitespace0(buf, i, len)
        # whitespace consumes TAB, SPACE, and NULL.
        # This method consumes NEWLINE, HASH, and COMMA.
        # BACKSLASH and EQUAL (of the special bytes) are valid measurement starts; they are not consumed.
        i, c = whitespace(buf, i, len)
        case c
        when nil # just whitespace
          len
        when COMMA
          @log.error "whitespace0: missing measurement"
          @state = :invalid
          i + 1
        when HASH # comment
          @state = :comment
          i + 1
        when NEWLINE
          i + 1
        else
          # don't advance i because the byte belongs to measurement
          @state = :measurement
          i
        end
      end

      def measurement(buf, i, len)
        start = i
        while i < len
          if @escaped
            @escaped = false
            i += 1
          else
            c = buf[i]
            raise "unsupported input type" unless c.is_a? Integer
            case c
            when BACKSLASH
              @escaped = true
              i += 1
            when COMMA # start of tag set.
              @point = {series: decode(buf, start, i-1), tags: {}, values: {}}
              @state = :tag_key
              return i+1
            when NEWLINE
              @log.error("measurement: missing fields")
              @state = :invalid
              return i
            when SPACE # start of field set
              @point = {series: decode(buf, start, i-1), values: {}}
              @state = :whitespace1
              return i + 1
            else # part of measurement
              i += 1
            end
          end
        end
        if i == len && start < i
          @buf.nil? ? @buf = buf[start..i-1] : @buf += buf[start..i-1]
        end
        i
      end

      def tag_key(buf, i, len)
        start = i
        while i < len
          if @escaped
            @escaped = false
            i += 1
          else
            c = buf[i]
            raise "unsupported input type" unless c.is_a? Integer
            case c
            when BACKSLASH
              @escaped = true
              i += 1
            when EQUALS
              @key = decode(buf, start, i-1)
              if @key == ""
                @log.error("tag_key: empty key")
                @state = :invalid
                return i
              end
              @state = :tag_value
              return i+1
            when NEWLINE
              @log.error("tag key: newline")
              @state = :invalid
              return i
            else
              i += 1
            end
          end
        end
        if i == len && start < i
          @buf.nil? ? @buf = buf[start..i-1] : @buf += buf[start..i-1]
        end
        i
      end

      def tag_value(buf, i, len)
        start = i
        while i < len
          if @escaped
            @escaped = false
            i += 1
          else
            c = buf[i]
            raise "unsupported input type" unless c.is_a? Integer
            case c
            when BACKSLASH
              @escaped = true
              i += 1
            when COMMA
              @point[:tags][@key] = decode(buf, start, i-1)
              @key = nil
              @state = :tag_key
              return i+1
            when NEWLINE
              @log.error("tag value: newline")
              @state = :invalid
              return i
            when SPACE
              @point[:tags][@key] = decode(buf, start, i-1)
              @key = nil
              @state = :field_key
              i, _ = whitespace(buf, i + 1, len)
              return i
            else
              i += 1
            end
          end
        end
        if i == len && start < i
          @buf.nil? ? @buf = buf[start..i-1] : @buf += buf[start..i-1]
        end
        i
      end

      def whitespace1(buf, i, len)
        i, c = whitespace(buf, i, len)
        case c
        when nil
          len
        when NEWLINE
          @log.error("whitespace1: missing fields")
          @state = :invalid
          i
        else
          @state = :field_key
          i
        end
      end

      def field_key(buf, i, len)
        start = i
        while i < len
          if @escaped
            @escaped = false
            i += 1
          else
            c = buf[i]
            raise "unsupported input type" unless c.is_a? Integer
            case c
            when BACKSLASH
              @escaped = true
              i += 1
            when EQUALS
              @key = decode(buf, start, i-1)
              if @key == ""
                @log.error("field key: empty key")
                @state = :invalid
                return i
              end
              @state = :field_value
              return i+1
            when NEWLINE
              @log.error("field key: newline")
              @state = :invalid
              return i
            else
              i += 1
            end
          end
        end
        if i == len && start < i
          @buf.nil? ? @buf = buf[start..i-1] : @buf += buf[start..i-1]
        end
        i
      end

      def field_value(buf, i, len)
        if i == len
          return len
        end
        c = buf[i]
        raise "unsupported input type" unless c.is_a? Integer
        case c
        when LATIN_CAPITAL_LETTER_F, LATIN_CAPITAL_LETTER_T, LATIN_SMALL_LETTER_F, LATIN_SMALL_LETTER_T
          @state = :field_value_boolean
          i
        when DIGIT_ZERO..DIGIT_NINE, PLUS_SIGN, MINUS_SIGN, DECIMAL_POINT
          @state = :field_value_numeric
          i
        when QUOTATION_MARK
          @state = :field_value_string
          i + 1
        else
          @log.error("field value: invalid")
          @state = :invalid
          i
        end
      end

      def field_value_boolean(buf, i, len)
        start = i
        while i < len
          if @escaped
            @escaped = false
            i += 1
          else
            c = buf[i]
            raise "unsupported input type" unless c.is_a? Integer
            case c
            when BACKSLASH
              @escaped = true
              i += 1
            when COMMA
              value = decode(buf, start, i-1)
              if value.nil?
                @log.error("field value boolean: invalid boolean")
                @state = :invalid
                return i
              end
              @point[:values][@key] = value
              @key = nil
              @state = :field_key
              return i+1
            when NEWLINE
              value = decode(buf, start, i-1)
              if value.nil?
                @log.error("field value boolean: invalid boolean")
                enter_whitespace0
                return i + 1
              end
              @point[:values][@key] = value
              @key = nil
              @state = :complete
              return i+1
            when SPACE
              value = decode(buf, start, i-1)
              if value.nil?
                @log.error("field value boolean: invalid boolean")
                @state = :invalid
                return i
              end
              @point[:values][@key] = value
              @key = nil
              @state = :whitespace2
              return i
            else
              i += 1
            end
          end
        end
        if i == len && start < i
          @buf.nil? ? @buf = buf[start..i-1] : @buf += buf[start..i-1]
        end
        i
      end

      def field_value_numeric(buf, i, len)
        start = i
        while i < len
          if @escaped
            @escaped = false
            i += 1
          else
            c = buf[i]
            raise "unsupported input type" unless c.is_a? Integer
            case c
            when BACKSLASH
              @escaped = true
              i += 1
            when COMMA
              value = decode(buf, start, i-1)
              if value.nil?
                @log.error("field value numeric: invalid number")
                @state = :invalid
                return i
              end
              @point[:values][@key] = value
              @key = nil
              @state = :field_key
              return i+1
            when NEWLINE
              value = decode(buf, start, i-1)
              if value.nil?
                @log.error("field value numeric: invalid number")
                @state = :invalid
                return i
              end
              @point[:values][@key] = value
              @key = nil
              @state = :complete
              return i+1
            when SPACE
              value = decode(buf, start, i-1)
              if value.nil?
                @log.error("field value numeric: invalid number")
                @state = :invalid
                return invalid(buf, i, len)
              end
              @point[:values][@key] = value
              @key = nil
              @state = :whitespace2
              return i
            else
              i += 1
            end
          end
        end
        if i == len && start < i
          @buf.nil? ? @buf = buf[start..i-1] : @buf += buf[start..i-1]
        end
        i
      end

      def field_value_string(buf, i, len)
        start = i
        while i < len
          if @escaped
            @escaped = false
            i += 1
          else
            c = buf[i]
            raise "unsupported input type" unless c.is_a? Integer
            case c
            when BACKSLASH
              @escaped = true
              i += 1
            when QUOTATION_MARK
              value = decode(buf, start, i-1)
              if value.nil?
                @log.error("field value string: invalid string")
                @state = :invalid
                return i
              end
              @point[:values][@key] = value
              @key = nil
              @state = :field_value_string_end
              return i+1
            else
              i += 1
            end
          end
        end
        if i == len && start < i
          @buf.nil? ? @buf = buf[start..i-1] : @buf += buf[start..i-1]
        end
        i
      end

      def field_value_string_end(buf, i, len)
        if i < len
          c = buf[i]
          raise "unsupported input type" unless c.is_a? Integer
          case c
          when COMMA
            @state = :field_key
            i + 1
          when NEWLINE
            @state = :complete
            i + 1
          when SPACE
            @state = :whitespace2
            i
          else
            @state = :invalid
            i
          end
        else
          len
        end
      end

      def whitespace2(buf, i, len)
        i, c = whitespace(buf, i, len)
        case c
        when nil
          len
        when NEWLINE
          @log.error("whitespace2: missing timestamp")
          @state = :invalid
          i
        else
          @state = :timestamp
          i
        end
      end

      def timestamp(buf, i, len)
        start = i
        while i < len
          if @escaped
            @escaped = false
            i += 1
          else
            c = buf[i]
            raise "unsupported input type" unless c.is_a? Integer
            case c
            when BACKSLASH
              @escaped = true
              i += 1
            when NEWLINE
              value = decode(buf, start, i-1)
              if value.nil?
                @log.error("timestamp: invalid timestamp")
                @state = :invalid
                return i
              end
              @point[:timestamp] = value
              @state = :complete
              return i + 1
            else
              i += 1
            end
          end
        end
        if i == len && start < i
          @buf.nil? ? @buf = buf[start..i-1] : @buf += buf[start..i-1]
        end
        i
      end

      def comment(buf, i, len)
        i = line_end(buf, i, len)
        if i < len
          enter_whitespace0
          i += 1
        end
        i
      end

      def invalid(buf, i, len)
        i = line_end(buf, i, len)
        if i < len
          enter_whitespace0
          i += 1
        end
        i
      end

      # Starting from position i,
      # returns the index of the newline.
      # Returns len if no such byte is found.
      def line_end(buf, i, len)
        while i < len
          c = buf[i]
          raise "unsupported input type" unless c.is_a? Integer
          if c == NEWLINE
            return i
          end
          i += 1
        end
        len
      end

      # Starting from position i,
      # return index of the first non-whitespace byte and the byte itself.
      # Return len and nil if no such byte is found.
      def whitespace(buf, i, len)
        while i < len
          c = buf[i]
          raise "unsupported input type" unless c.is_a? Integer
          if c != SPACE && c != TAB && c != NULL
            return [i, c]
          end
          i += 1
        end
        [len, nil]
      end

      def decode(buf, start, i)
        str = if @buf.nil?
                (start <= i) ? string(buf[start..i]) : ""
              else
                (start <= i) ? string(@buf + buf[start..i]) : string(@buf)
              end
        @buf = nil
        case @state
        when :measurement
          @unescapes.unescape(:measurement, str)
        when :tag_key
          @unescapes.unescape(:tag_key, str)
        when :tag_value
          @unescapes.unescape(:tag_value, str)
        when :field_key
          @unescapes.unescape(:field_key, str)
        when :field_value_boolean
          case str
          when 't', 'T', 'true', 'True'
            true
          when 'f', 'F', 'false', 'False'
            false
          else
            @log.error("invalid Boolean: #{str}")
            nil
          end
        when :field_value_numeric
          case str
          when /^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?$/
            str.to_f
          when /^[+-]?[0-9]+[ui]$/
            str.to_i
          else
            @log.error("invalid number: #{str}")
            nil
          end
        when :field_value_string
          @unescapes.unescape(:string, str)
        when :timestamp
          case str
          when /^-?[0-9]+$/
            str.to_i
          else
            @log.error("invalid timestamp: #{str}")
          end
        else
          raise "error: decode: invalid state"
        end
      end

      def bytes(data)
        case data
        when nil
          [].freeze
        when Integer
          [data].freeze
        when String
          data.encode(UTF_8).bytes.freeze
        when Array
          data
        end
      end

      def string(buf)
        buf.pack(UTF_8_PACK_FORMAT).force_encoding(UTF_8)
      end
    end # Parser

    class CompatUnescapes
      def unescape(field, str)
        case field
        when :measurement
          # escaped comma or space anywhere
          str.gsub(/\\([, ])/, '\\1')
        when :tag_key, :tag_value, :field_key
          # escaped comma, equals, or space anywhere
          str.gsub(/\\([,= ])/, '\\1')
        when :string
          # escaped quote anywhere
          str.gsub(/\\"/, '"')
        end
      end
    end

    class Unescapes
      def unescape(field, str)
        case field
        when :measurement
          # 1. escaped hash, null, or tab at the beginning
          # 2. escaped comma, space, or newline anywhere
          # 3. escaped backslash at the end
          str
              .sub(/^\\([#\0\t])/, '\\1')
              .gsub(/\\([, \n])/, '\\1')
              .sub(/\\\\$/, '\\')
        when :tag_key, :tag_value
          # 1. escaped comma, equals, newline, or space anywhere
          # 2. escaped backslash at the end
          str
              .gsub(/\\([,=\n ])/, '\\1')
              .sub(/\\\\$/, '\\')
        when :field_key
          # 1. escaped null or tab at beginning
          # 2. escaped comma, equals, newline, or space anywhere
          # 3. escaped backslash at the end
          str
              .sub(/^\\([\0\t])/, '\\1')
              .gsub(/\\([,=\n ])/, '\\1')
              .sub(/\\\\$/, '\\')
        when :string
          # escaped quote anywhere
          str.gsub(/\\"/, '"')
        end
      end
    end
  end
end
