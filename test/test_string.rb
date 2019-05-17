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

class StringTest < Minitest::Test
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
      %q[m f=""],
      %q[m f="foo" 1],
      %q[m f1="\"\"",f2=" ",f3=","],
      "\n"
  ].join("\n").freeze
  EXPECTED = [
      point(:m, {f: ""}),
      point(:m, {f: "foo"}, timestamp: 1),
      point(:m, {f1: %q[""], f2: " ", f3: ","})
  ]

  def test_string
    p = InfluxDB::LineProtocol::Parser.new
    assert_equal EXPECTED, p.each_point(SOURCE)
  end
end
