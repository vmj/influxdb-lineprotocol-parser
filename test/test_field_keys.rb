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

# incompatibilities not fixed by compat mode:
#  * backslash at the end of field key (backslash 3): InfluxDB can't parse that
# incompatibilities fixed by additional escaping:
#  * unescaped comma in field key (comma 1-3): InfluxDB can't parse that, but escaping them works
#  * unescaped space in field key (space 1-3): InfluxDB can't parse that, but escaping them works
# incompatibilities fixed by compat mode:
#  * embedded newlines (newline 1-3): InfluxDB takes the escaping backslashes literally
#  * leading null (null1): InfluxDB takes the escaping backslash literally
#  * leading tab (tab1): InfluxDB takes the escaping backslash literally
class FieldKeyTest < Minitest::Test
  def self.test(name, src, default, compat)
    src = (src + "\n").freeze
    define_method("test_#{name}") do
      actual = InfluxDB::LineProtocol::Parser.new.each_point(src)
      assert_equal default, actual[0][:values].first[0]
    end
    unless compat.nil?
      define_method("test_#{name}_compat") do
        actual = InfluxDB::LineProtocol::Parser.new(escapes: :compat).each_point(src)
        assert_equal compat, actual[0][:values].first[0]
      end
    end
  end

  # BACKSLASH
  test "backslash1", %q[backslash \f1=t], %q[\f1], %q[\f1]
  test "backslash2", %q[backslash f\1=t], %q[f\1], %q[f\1]
  test "backslash3", "backslash f1\x5C\x5C=t", "f1\x5C", nil

  # COMMA
  test "comma1", "comma ,f1=t", ",f1", nil
  test "comma2", "comma f,1=t", "f,1", nil
  test "comma3", "comma f1,=t", "f1,", nil
  test "comma1_lenient", %q[comma \,f1=t], ",f1", ",f1"
  test "comma2_lenient", %q[comma f\,1=t], "f,1", "f,1"
  test "comma3_lenient", %q[comma f1\,=t], "f1,", "f1,"

  # EQUALS
  test "equals1", %q[equals \=f1=t], "=f1", "=f1"
  test "equals2", %q[equals f\=1=t], "f=1", "f=1"
  test "equals3", %q[equals f1\==t], "f1=", "f1="

  # HASH
  test "hash1", "hash #f1=t", "#f1", "#f1"
  test "hash2", "hash f#1=t", "f#1", "f#1"
  test "hash3", "hash f1#=t", "f1#", "f1#"

  # NEWLINE
  test "newline1", "newline \\\nf1=t", "\nf1", "\\\nf1"
  test "newline2", "newline f\\\n1=t", "f\n1", "f\\\n1"
  test "newline3", "newline f1\\\n=t", "f1\n", "f1\\\n"

  # NULL
  test "null1", "null \\\0f1=t", "\0f1", "\\\0f1"
  test "null2", "null f\0001=t", "f\0001", "f\0001"
  test "null3", "null f1\0=t", "f1\0", "f1\0"

  # SPACE
  test "space1", "space \\ f1=t", " f1", nil
  test "space2", "space f 1=t", "f 1", nil
  test "space3", "space f1 =t", "f1 ", nil
  test "space1_lenient", %q[space \ f1=t], " f1", " f1"
  test "space2_lenient", %q[space f\ 1=t], "f 1", "f 1"
  test "space3_lenient", %q[space f1\ =t], "f1 ", "f1 "

  # TAB
  test "tab1", "tab \\\tf1=t", "\tf1", "\\\tf1"
  test "tab2", "tab f\t1=t", "f\t1", "f\t1"
  test "tab3", "tab f1\t=t", "f1\t", "f1\t"
end
