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

class Whitespace0Test < Minitest::Test
  LINES = [
      "# This comment line is ignored. 👍\n",
      "   \n",
      "\t\t\t\n",
      "\0\0\0\n",
      "  \t\t\0\0# Comments can be preceded by whitespace\n",
      "\n",
      "  , m f=1i\n", # -> missing measurement error, and the rest of the line is ignored
  ]
  VALID_LINE = "cpu a=1i\n".freeze
  EXPECTED = {series: "cpu".freeze, values: {"a".freeze => 1}.freeze}.freeze

  def test_whitespace0
    p = InfluxDB::LineProtocol::Parser.new(log_level: :fatal)
    LINES.each do |line|
      assert_equal([], p.each_point(line))
    end
    assert_equal [EXPECTED], p.each_point(VALID_LINE)
  end

  def test_whitespace0_incremental
    p = InfluxDB::LineProtocol::Parser.new(log_level: :fatal)
    LINES.each do |line|
      line.each_char do |single_char_string|
        assert_equal([], p.each_point(single_char_string))
      end
    end
    VALID_LINE.each_char do |single_char_string|
      if single_char_string == "\n"
        assert_equal([EXPECTED], p.each_point(single_char_string))
      else
        assert_equal([], p.each_point(single_char_string))
      end
    end
  end

  def test_whitespace0_batch
    p = InfluxDB::LineProtocol::Parser.new(log_level: :fatal)
    assert_equal([EXPECTED], p.each_point(LINES.join('') + VALID_LINE))
  end

  def test_whitespace0_bytes
    p = InfluxDB::LineProtocol::Parser.new(log_level: :fatal)
    LINES.join('').each_byte do |byte|
      assert_equal([], p.each_point(byte))
    end
    VALID_LINE.each_byte do |byte|
      if byte == 10
        assert_equal([EXPECTED], p.each_point(byte))
      else
        assert_equal([], p.each_point(byte))
      end
    end
  end
end
