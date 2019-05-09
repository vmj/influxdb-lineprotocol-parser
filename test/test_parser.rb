require 'minitest/autorun'
require 'influxdb/lineprotocol/parser'

class ParserTest < Minitest::Test
  def test_yield
    p = InfluxDBExt::LineProtocol::Parser.new
    ok = false
    p.each_point("") { |point|
      ok = true
    }
    assert_equal true, ok
  end

  def test_return
    p = InfluxDBExt::LineProtocol::Parser.new
    assert_equal [], p.each_point("")
  end
end
