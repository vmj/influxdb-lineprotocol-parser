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
  def test_yield
    p = InfluxDBExt::LineProtocol::Parser.new
    actual = nil
    expected = {series: "m".freeze, values: {"f".freeze => 1}}
    p.each_point("m f=1i\n".freeze) { |parsed|
      actual = parsed
    }
    assert_equal expected, actual
  end

  def test_return
    p = InfluxDBExt::LineProtocol::Parser.new
    expected = {series: "m".freeze, values: {"f".freeze => 1}}
    assert_equal [expected], p.each_point("m f=1i\n".freeze)
  end
end
