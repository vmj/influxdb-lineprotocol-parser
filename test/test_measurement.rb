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

# incompatibilities:
#  * backslash at the end (measurement 3): InfluxDB can't parse that
#  * backslash at the end (measurement 4): InfluxDB parses that but tags become part of the measurement name
#  * comma (measurements 5-8): I should unescape
class MeasurementTest < Minitest::Test
  def self.test(name, src, default, compat)
    src = (src + "\n").freeze
    define_method("test_#{name}") do
      actual = InfluxDB::LineProtocol::Parser.new.each_point(src)
      assert_equal default, actual[0][:series]
    end
    unless compat.nil?
      define_method("test_#{name}_compat") do
        actual = InfluxDB::LineProtocol::Parser.new(escapes: :compat).each_point(src)
        assert_equal compat, actual[0][:series]
      end
    end
  end

  # BACKSLASH
  test "measurement1", %q[\measurement1 ok=true],%q[\measurement1],%q[\measurement1]
  test "measurement2", %q[measur\ement1 ok=true],%q[measur\ement1],%q[measur\ement1]
  test "measurement3", "measurement3\x5C\x5C ok=true","measurement3\x5C",nil
  test "measurement4", "measurement4\x5C\x5C,tag=foo ok=true","measurement4\x5C",nil

  # COMMA
  test "measurement5",%q[\,measurement5 ok=true], ',measurement5', ',measurement5'
  test "measurement6",%q[measur\,ement6 ok=true], 'measur,ement6', 'measur,ement6'
  test "measurement7",%q[measurement7\, ok=true], 'measurement7,', 'measurement7,'
  test "measurement8",%q[measurement8\,,tag=foo ok=true], 'measurement8,', 'measurement8,'

  # EQUALS
  test "measurement9","=measurement9 ok=true", '=measurement9', '=measurement9'
  test "measurement10","measur=ement10 ok=true", 'measur=ement10', 'measur=ement10'
  test "measurement11","measurement11= ok=true", 'measurement11=', 'measurement11='
  test "measurement12","measurement12=,tag=foo ok=true", 'measurement12=','measurement12='

  # HASH
  test "measurement13",%q[\#measurement13 ok=true], '#measurement13', "\\#measurement13"
  test "measurement14","measur#ement14 ok=true", 'measur#ement14', 'measur#ement14'
  test "measurement15","measurement15# ok=true", 'measurement15#', 'measurement15#'
  test "measurement16","measurement16#,tag=foo ok=true", 'measurement16#', 'measurement16#'

  # NEWLINE
  test "measurement17","\\\nmeasurement17 ok=true", "\nmeasurement17", "\\\nmeasurement17"
  test "measurement18","measur\\\nement18 ok=true", "measur\nement18", "measur\\\nement18"
  test "measurement19","measurement19\\\n ok=true", "measurement19\n", "measurement19\\\n"
  test "measurement20","measurement20\\\n,tag=foo ok=true", "measurement20\n", "measurement20\\\n"

  # NULL
  test "measurement21","\\\0measurement21 ok=true", "\0measurement21", "\\\0measurement21"
  test "measurement22","measur\0ement22 ok=true", "measur\0ement22", "measur\0ement22"
  test "measurement23","measurement23\0 ok=true", "measurement23\0", "measurement23\0"
  test "measurement24","measurement24\0,tag=foo ok=true", "measurement24\0", "measurement24\0"

  # SPACE
  test "measurement25",%q[\ measurement25 ok=true]," measurement25"," measurement25"
  test "measurement26",%q[measur\ ement26 ok=true],"measur ement26","measur ement26"
  test "measurement27",%q[measurement27\  ok=true],"measurement27 ","measurement27 "
  test "measurement28",%q[measurement28\ ,tag=foo ok=true],"measurement28 ","measurement28 "

  # TAB
  test "measurement29","\\\tmeasurement29 ok=true","\tmeasurement29","\\\tmeasurement29"
  test "measurement30","measur\tement30 ok=true","measur\tement30","measur\tement30"
  test "measurement31","measurement31\t ok=true","measurement31\t","measurement31\t"
  test "measurement32","measurement32\t,tag=foo ok=true","measurement32\t","measurement32\t"
end
