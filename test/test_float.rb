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

class FloatTest < Minitest::Test
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
      "m f=1\n",
      "m f=23 1\n",
      "m f1=.4,f2=.56,f3=7.8,f4=90.12,f5=+3,f6=+45\n",
      "m f1=-6,f2=-78,f3=+9.0,f4=+12.34,f5=-5.6,f6=-78.90\n",
      "m f1=1e2,f2=3E45,f3=6e-7,f4=8E+9\n"
  ].join('').freeze
  EXPECTED = [
      point(:m, {f: 1.0}),
      point(:m, {f: 23.0}, timestamp: 1),
      point(:m, {f1: 0.4, f2: 0.56, f3: 7.8, f4: 90.12, f5: 3.0, f6: 45.0}),
      point(:m, {f1: -6.0, f2: -78.0, f3: 9.0, f4: 12.34, f5: -5.6, f6: -78.9}),
      point(:m, {f1: 100.0, f2: 3e45, f3: 6e-7, f4: 8e9})
  ]

  def test_float
    p = InfluxDB::LineProtocol::Parser.new
    assert_equal EXPECTED, p.each_point(SOURCE)
  end
end
