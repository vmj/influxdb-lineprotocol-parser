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
#  * backslash at the end of tag key (backslash 3): InfluxDB can't parse that
#  * backslash at the end of tag value (measurement 4): InfluxDB can't parse that, either
#  * unescaped comma in tag key (comma 1-3): InfluxDB can't parse that, but escaping them works
#  * unescaped equals in tag value (equals 1-3): Strangely InfluxDB handles the first one but no the rest, but escaping them works
#  * unescaped space in tag key (space 1-3): InfluxDB can't parse that, but escaping them works
# incompatibilities fixed by compat mode:
#  * embedded newlines (newline 1-3): InfluxDB takes the escaping backslashes literally
class TagsTest < Minitest::Test
  def self.test_key(name, src, default, compat)
    src = (src + "\n").freeze
    define_method("test_key_#{name}") do
      actual = InfluxDB::LineProtocol::Parser.new.each_point(src)
      assert_equal default, actual[0][:tags].first[0]
    end
    unless compat.nil?
      define_method("test_key_#{name}_compat") do
        actual = InfluxDB::LineProtocol::Parser.new(escapes: :compat).each_point(src)
        assert_equal compat, actual[0][:tags].first[0]
      end
    end
  end
  def self.test_val(name, src, default, compat)
    src = (src + "\n").freeze
    define_method("test_val_#{name}") do
      actual = InfluxDB::LineProtocol::Parser.new.each_point(src)
      assert_equal default, actual[0][:tags].first[1]
    end
    unless compat.nil?
      define_method("test_val_#{name}_compat") do
        actual = InfluxDB::LineProtocol::Parser.new(escapes: :compat).each_point(src)
        assert_equal compat, actual[0][:tags].first[1]
      end
    end
  end

  # BACKSLASH
  test_key "backslash1", %q[backslash,\tag=foo ok=true], %q[\tag], %q[\tag]
  test_key "backslash2", %q[backslash,ta\g=foo ok=true], %q[ta\g], %q[ta\g]
  test_key "backslash3", "backslash,tag\x5C\x5C=foo ok=true", "tag\x5C", nil

  test_val "backslash1", %q[backslash,tag=\foo ok=true], %q[\foo], %q[\foo]
  test_val "backslash2", %q[backslash,tag=fo\o ok=true], %q[fo\o], %q[fo\o]
  test_val "backslash3", "backslash,tag=foo\x5C\x5C ok=true", "foo\x5C", nil

  # COMMA
  test_key "comma1", "comma,,tag=foo ok=false", ",tag", nil
  test_key "comma2", "comma,ta,g=foo ok=false", "ta,g", nil
  test_key "comma3", "comma,tag,=foo ok=false", "tag,", nil
  test_key "comma1_lenient", %q[comma,\,tag=foo ok=false], ",tag", ",tag"
  test_key "comma2_lenient", %q[comma,ta\,g=foo ok=false], "ta,g", "ta,g"
  test_key "comma3_lenient", %q[comma,tag\,=foo ok=false], "tag,", "tag,"

  test_val "comma1", %q[comma,tag=\,foo ok=true], ",foo", ",foo"
  test_val "comma2", %q[comma,tag=fo\,o ok=true], "fo,o", "fo,o"
  test_val "comma3", %q[comma,tag=foo\, ok=true], "foo,", "foo,"

  # EQUALS
  test_key "equals1", %q[equals,\=tag=foo ok=true], "=tag", "=tag"
  test_key "equals2", %q[equals,ta\=g=foo ok=true], "ta=g", "ta=g"
  test_key "equals3", %q[equals,tag\==foo ok=true], "tag=", "tag="

  test_val "equals1", "equals,tag==foo ok=true", "=foo", "=foo"
  test_val "equals2", "equals,tag=fo=o ok=true", "fo=o", nil
  test_val "equals3", "equals,tag=foo= ok=true", "foo=", nil
  test_val "equals1_lenient", %q[equals,tag=\=foo ok=true], "=foo", "=foo"
  test_val "equals2_lenient", %q[equals,tag=fo\=o ok=true], "fo=o", "fo=o"
  test_val "equals3_lenient", %q[equals,tag=foo\= ok=true], "foo=", "foo="

  # HASH
  test_key "hash1", "hash,#tag=foo ok=false", "#tag", "#tag"
  test_key "hash2", "hash,ta#g=foo ok=false", "ta#g", "ta#g"
  test_key "hash3", "hash,tag#=foo ok=false", "tag#", "tag#"

  test_val "hash1", "hash,tag=#foo ok=true", "#foo", "#foo"
  test_val "hash2", "hash,tag=fo#o ok=true", "fo#o", "fo#o"
  test_val "hash3", "hash,tag=foo# ok=true", "foo#", "foo#"

  # NEWLINE
  test_key "newline1", "newline,\\\ntag=foo ok=false", "\ntag", "\\\ntag"
  test_key "newline2", "newline,ta\\\ng=foo ok=false", "ta\ng", "ta\\\ng"
  test_key "newline3", "newline,tag\\\n=foo ok=false", "tag\n", "tag\\\n"

  test_val "newline1", "newline,tag=\\\nfoo ok=true", "\nfoo", "\\\nfoo"
  test_val "newline2", "newline,tag=fo\\\no ok=true", "fo\no", "fo\\\no"
  test_val "newline3", "newline,tag=foo\\\n ok=true", "foo\n", "foo\\\n"

  # NULL
  test_key "null1", "null,\0tag=foo ok=false", "\0tag", "\0tag"
  test_key "null2", "null,ta\0g=foo ok=false", "ta\0g", "ta\0g"
  test_key "null3", "null,tag\0=foo ok=false", "tag\0", "tag\0"

  test_val "null1", "null,tag=\0foo ok=true", "\0foo", "\0foo"
  test_val "null2", "null,tag=fo\0o ok=true", "fo\0o", "fo\0o"
  test_val "null3", "null,tag=foo\0 ok=true", "foo\0", "foo\0"

  # SPACE
  test_key "space1", "space, tag=foo ok=false", " tag", nil
  test_key "space2", "space,ta g=foo ok=false", "ta g", nil
  test_key "space3", "space,tag =foo ok=false", "tag ", nil
  test_key "space1_lenient", %q[space,\ tag=foo ok=false], " tag", " tag"
  test_key "space2_lenient", %q[space,ta\ g=foo ok=false], "ta g", "ta g"
  test_key "space3_lenient", %q[space,tag\ =foo ok=false], "tag ", "tag "

  test_val "space1", %q[space,tag=\ foo ok=true], " foo", " foo"
  test_val "space2", %q[space,tag=fo\ o ok=true], "fo o", "fo o"
  test_val "space3", %q[space,tag=foo\  ok=true], "foo ", "foo "

  # TAB
  test_key "tab1", "tab,\ttag=foo ok=false", "\ttag", "\ttag"
  test_key "tab2", "tab,ta\tg=foo ok=false", "ta\tg", "ta\tg"
  test_key "tab3", "tab,tag\t=foo ok=false", "tag\t", "tag\t"

  test_val "tab1", "tab,tag=\tfoo ok=true", "\tfoo", "\tfoo"
  test_val "tab2", "tab,tag=fo\to ok=true", "fo\to", "fo\to"
  test_val "tab3", "tab,tag=foo\t ok=true", "foo\t", "foo\t"
end
