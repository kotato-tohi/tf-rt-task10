require 'spec_helper'

describe package('nginx') do
  it { should be_installed }
 end

 describe service('nginx') do
  it { should be_running}
  it { should be_enabled}
end

describe port(80) do
  it { should be_listening }
end

describe file("/usr/share/nginx/html/index.html") do
  it { should exist }
end

describe command('curl http://localhost -o /dev/null -w "%{http_code}\n" -s' ) do
  its(:stdout) { should match /^200$/ }
end