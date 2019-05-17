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
require 'minitest/autorun'
require 'influxdb/lineprotocol/parser'

class Whitespace2Test < Minitest::Test
  LINES = [
      "m f=t 1\n".freeze,
      "m f=t    1\n".freeze,
      "m f=t \t\t\t1\n".freeze,
      "m f=t \0\0\0001\n".freeze,
      "m f=t  \t\0 \t\0001\n".freeze,
  ].freeze
  EXPECTED = {series: "m".freeze, values: {"f".freeze => true}.freeze, timestamp: 1}.freeze

  def test_whitespace2
    p = InfluxDB::LineProtocol::Parser.new
    points = []
    LINES.each do |line|
      p.each_point(line) {|point|
        points << point
        assert_equal EXPECTED, point
      }
    end
    assert_equal LINES.size, points.size
  end

  def test_whitespace2_incremental
    p = InfluxDB::LineProtocol::Parser.new
    LINES.each do |line|
      line.each_char do |single_char_string|
        if single_char_string == "\n"
          assert_equal([EXPECTED], p.each_point(single_char_string))
        else
          assert_equal([], p.each_point(single_char_string))
        end
      end
    end
  end

  def test_whitespace2_batch
    p = InfluxDB::LineProtocol::Parser.new
    assert_equal([EXPECTED] * LINES.size, p.each_point(LINES.join('').freeze))
  end

  def test_whitespace2_bytes
    p = InfluxDB::LineProtocol::Parser.new
    LINES.join('').each_byte do |byte|
      if byte == 10
        assert_equal([EXPECTED], p.each_point(byte))
      else
        assert_equal([], p.each_point(byte))
      end
    end
  end
end
