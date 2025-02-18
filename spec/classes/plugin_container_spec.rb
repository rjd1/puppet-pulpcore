require 'spec_helper'

describe 'pulpcore::plugin::container' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      context "with default params" do
        let(:pre_condition) { 'include pulpcore' }

        it 'configures the plugin' do
          is_expected.to compile.with_all_deps
          is_expected.to contain_pulpcore__plugin('container')
            .that_subscribes_to('Class[Pulpcore::Install]')
            .that_notifies(['Class[Pulpcore::Database]', 'Class[Pulpcore::Service]'])
          is_expected.to contain_package('pulpcore-plugin(container)')
          is_expected.to contain_concat__fragment('plugin-container')
            .with_content("\n# container plugin settings\nTOKEN_AUTH_DISABLED=True\nFLATPAK_INDEX=True")
          is_expected.to contain_pulpcore__apache__fragment('plugin-container')
          is_expected.not_to contain_apache__vhost__fragment('pulpcore-http-plugin-container')
          is_expected.to contain_apache__vhost__fragment('pulpcore-https-plugin-container')
            .with_vhost('pulpcore-https')
            .with_priority('10')
            .with_content(<<APACHE_CONFIG)

  <Location "/pulpcore_registry">
    RequestHeader unset REMOTE-USER
    RequestHeader unset REMOTE_USER
    ProxyPass unix:///run/pulpcore-api.sock|http://pulpcore-api
    ProxyPassReverse unix:///run/pulpcore-api.sock|http://pulpcore-api
  </Location>

  ProxyPass /pulp/container/ unix:///run/pulpcore-content.sock|http://pulpcore-content/pulp/container/
  ProxyPassReverse /pulp/container/ unix:///run/pulpcore-content.sock|http://pulpcore-content/pulp/container/
APACHE_CONFIG
        end
      end

      context 'with API client auth common names' do
        let(:pre_condition) do
          <<~PUPPET
          class {'pulpcore':
            api_client_auth_cn_map => {'foreman.example.com' => 'admin'}
          }
          PUPPET
        end
        it 'configures the plugin' do
          is_expected.to compile.with_all_deps
          is_expected.to contain_apache__vhost__fragment('pulpcore-https-plugin-container')
            .with_vhost('pulpcore-https')
            .with_priority('10')
            .with_content(<<APACHE_CONFIG)

  <Location "/pulpcore_registry">
    RequestHeader unset REMOTE-USER
    RequestHeader unset REMOTE_USER
    RequestHeader set REMOTE-USER "admin" "expr=%{tolower:%{SSL_CLIENT_S_DN_CN}} == 'foreman.example.com'"
    ProxyPass unix:///run/pulpcore-api.sock|http://pulpcore-api
    ProxyPassReverse unix:///run/pulpcore-api.sock|http://pulpcore-api
  </Location>

  ProxyPass /pulp/container/ unix:///run/pulpcore-content.sock|http://pulpcore-content/pulp/container/
  ProxyPassReverse /pulp/container/ unix:///run/pulpcore-content.sock|http://pulpcore-content/pulp/container/
APACHE_CONFIG
        end
      end
    end
  end
end
