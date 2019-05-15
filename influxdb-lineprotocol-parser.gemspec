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
Gem::Specification.new do |s|
  s.summary = 'InfluxDB line protocol parser'
  s.name = 'influxdb-lineprotocol-parser'
  s.version = '0.0.2'
  s.date = '2019-05-15'
  s.homepage = 'https://rubygems.org/gems/influxdb-lineprotocol-parser'
  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/vmj/influxdb-lineprotocol-parser/issues',
    'source_code_uri' => 'https://github.com/vmj/influxdb-lineprotocol-parser'
  }
  s.author = 'Mikko Värri'
  s.email = 'mikko@varri.fi'
  s.license = 'Apache-2.0'
  s.description = <<-EOF
Streaming parser for InfluxDB line protocol.
EOF
  s.files = [
    'lib/influxdb/lineprotocol/parser.rb'
  ]
  s.required_ruby_version = Gem::Requirement.new(">= 2.3".freeze)
end
