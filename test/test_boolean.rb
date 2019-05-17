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

class BooleanTest < Minitest::Test
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
      "m f=t\n",
      "m f=f 1\n",
      "m f1=T,f2=F,f3=true,f4=false,f5=True,f6=False\n"
  ].join('').freeze
  EXPECTED = [
      point(:m, {f: true}),
      point(:m, {f: false}, timestamp: 1),
      point(:m, {f1: true, f2: false, f3: true, f4: false, f5: true, f6: false})
  ]

  def test_boolean
    p = InfluxDB::LineProtocol::Parser.new
    assert_equal EXPECTED, p.each_point(SOURCE)
  end
end
