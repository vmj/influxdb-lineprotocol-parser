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

class ParserTest < Minitest::Test
  def self.point(series, values, tags: nil, timestamp: nil)
    p = {series: series.to_s.freeze, values: values.map {|k, v| [k.to_s.freeze, v.freeze]}.to_h.freeze}
    unless tags.nil?
      p[:tags] = tags.map {|k, v| [k.to_s.freeze, v.to_s.freeze]}.to_h.freeze
    end
    unless timestamp.nil?
      p[:timestamp] = timestamp.freeze
    end
    p.freeze
  end

  SOURCE = [
      "m f=1i\n",
      "m,t=a f=2i\n",
      "m,t1=b,t2=c f1=3i,f2=4i\n",
      "m f=5i 123\n"
  ].join('').freeze
  EXPECTED = [
      point(:m, {f: 1}),
      point(:m, {f: 2}, tags: {t: :a}),
      point(:m, {f1: 3, f2: 4}, tags: {t1: :b, t2: :c}),
      point(:m, {f: 5}, timestamp: 123),
  ]

  def test_yield
    p = InfluxDB::LineProtocol::Parser.new
    actual = []
    p.each_point(SOURCE) { |parsed|
      actual << parsed
    }
    assert_equal EXPECTED, actual
  end

  def test_return
    p = InfluxDB::LineProtocol::Parser.new
    assert_equal EXPECTED, p.each_point(SOURCE)
  end

  def test_incremental
    p = InfluxDB::LineProtocol::Parser.new
    i = 0
    SOURCE.each_char do |single_char_string|
      if single_char_string == "\n"
        assert_equal([EXPECTED[i]], p.each_point(single_char_string))
        i += 1
      else
        assert_equal([], p.each_point(single_char_string))
      end
    end
  end

  def test_bytes
    p = InfluxDB::LineProtocol::Parser.new
    i = 0
    SOURCE.each_byte do |byte|
      if byte == 10
        assert_equal([EXPECTED[i]], p.each_point(byte))
        i += 1
      else
        assert_equal([], p.each_point(byte))
      end
    end
  end
end
