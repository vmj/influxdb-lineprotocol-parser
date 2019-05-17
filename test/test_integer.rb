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

class IntegerTest < Minitest::Test
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
      "m f=-1u 1\n",
      "m f1=+1i,f2=0i,f3=2i,f4=3i,f5=4i,f6=5i\n",
      "m f1=67i,f2=789i,f3=8901i,f4=9i\n"
  ].join('').freeze
  EXPECTED = [
      point(:m, {f: 1}),
      point(:m, {f: -1}, timestamp: 1),
      point(:m, {f1: 1, f2: 0, f3: 2, f4: 3, f5: 4, f6: 5}),
      point(:m, {f1: 67, f2: 789, f3: 8901, f4: 9})
  ]

  def test_integer
    p = InfluxDB::LineProtocol::Parser.new
    assert_equal EXPECTED, p.each_point(SOURCE)
  end
end
