require 'minitest/autorun'
require 'mta_settings'

class MtaSettingsTest < Minitest::Test
  def settings(env)
    MtaSettings.from_env(env)
  end

  def url_settings(url)
    MtaSettings.from_url(url)
  end

  def test_blank
    assert_nil url_settings(nil)
    assert_nil url_settings('')
  end

  def test_smtp
    adapter, settings = *url_settings('smtps://a:b@smtp.gmail.com:587/example.com?authentication=cram_md5')
    assert_equal :smtp, adapter
    assert_equal 'smtp.gmail.com', settings[:address]
    assert_equal 587,              settings[:port]
    assert_equal 'cram_md5',       settings[:authentication]
    assert_equal true,             settings[:ssl]
    assert_equal true,             settings[:enable_starttls_auto]
    assert_equal 'a',              settings[:user_name]
    assert_equal 'b',              settings[:password]
    assert_equal 'example.com',    settings[:domain]
  end

  def test_sendmail
    assert_equal [:sendmail, {location: '/usr/sbin/sendmail', arguments: '-i -t'}],
      url_settings('sendmail:///')
    assert_equal [:sendmail, {location: '/bin/exim', arguments: '-x -y'}],
      url_settings('sendmail:///bin/exim?arguments=-x+-y')
  end

  def test_file
    assert_equal [:file, {location: '/tmp'}], url_settings('file:///tmp')
    assert_equal [:file, {location: 'tmp'}], url_settings('file:tmp')
  end

  def test_test
    assert_equal [:test, nil], url_settings('test:')
  end

  def test_sendgrid
    base = {
      'SENDGRID_USERNAME' => 'foo',
      'SENDGRID_PASSWORD' => 'bar'
    }
    adapter, settings = settings(base)
    assert_equal :smtp, adapter
    assert_equal 'smtp.sendgrid.net',     settings[:address]
    assert_equal 587,                     settings[:port]
    assert_equal :plain,                  settings[:authentication]
    assert_equal 'foo',                   settings[:user_name]
    assert_equal 'bar',                   settings[:password]
    assert_equal 'localhost.localdomain', settings[:domain]

    adapter, settings = settings(base.merge('MTA_DOMAIN' => 'example.com'))
    assert_equal 'example.com', settings[:domain]

    adapter, settings = settings(base.merge('MTA_URL' => 'sendmail:///'))
    assert_equal :sendmail, adapter
  end

  def test_mandrill
    base = {
      'MANDRILL_USERNAME' => 'foo',
      'MANDRILL_APIKEY' => 'bar'
    }
    adapter, settings = settings(base)
    assert_equal :smtp, adapter
    assert_equal 'smtp.mandrillapp.com',  settings[:address]
    assert_equal 587,                     settings[:port]
    assert_equal :plain,                  settings[:authentication]
    assert_equal 'foo',                   settings[:user_name]
    assert_equal 'bar',                   settings[:password]
    assert_equal 'localhost.localdomain', settings[:domain]
  end

  def test_postmark
    base = {
      'POSTMARK_SMTP_SERVER' => 'server',
      'POSTMARK_API_TOKEN' => 'bar'
    }
    adapter, settings = settings(base)
    assert_equal :smtp, adapter
    assert_equal 'server',                settings[:address]
    assert_equal 25,                      settings[:port]
    assert_equal :cram_md5,               settings[:authentication]
    assert_equal 'bar',                   settings[:user_name]
    assert_equal 'bar',                   settings[:password]
    assert_equal 'localhost.localdomain', settings[:domain]
  end

  def test_mailgun
    base = {
      'MAILGUN_SMTP_SERVER' => 'server',
      'MAILGUN_SMTP_PORT' => '587',
      'MAILGUN_SMTP_LOGIN' => 'foo',
      'MAILGUN_SMTP_PASSWORD' => 'bar'
    }
    adapter, settings = settings(base)
    assert_equal :smtp, adapter
    assert_equal 'server',                settings[:address]
    assert_equal '587',                   settings[:port]
    assert_equal :plain,                  settings[:authentication]
    assert_equal 'foo',                   settings[:user_name]
    assert_equal 'bar',                   settings[:password]
    assert_equal 'localhost.localdomain', settings[:domain]
  end

  def test_mailtrap
    base = {
      'MAILTRAP_API_TOKEN' => 'supertoken',
    }
    Net::HTTP.stub(:get, "[{\"id\":1,\"company_id\":1,\"name\":\"Demo inbox\",\"username\":\"super_username\",\"password\":\"super_password\",\"max_size\":50,\"status\":\"active\",\"email_username\":\"email_username\",\"email_username_enabled\":false,\"domain\":\"smtp.mailtrap.io\",\"email_domain\":\"inbox.mailtrap.io\",\"emails_count\":0,\"emails_unread_count\":0,\"last_message_sent_at_timestamp\":null,\"smtp_ports\":[25,465,2525],\"pop3_ports\":[1100,9950],\"has_inbox_address\":false}]" ) do
      adapter, settings = settings(base)
      assert_equal :smtp, adapter
      assert_equal 'smtp.mailtrap.io', settings[:address]
      assert_equal 25,                 settings[:port]
      assert_equal :plain,             settings[:authentication]
      assert_equal 'super_username',   settings[:user_name]
      assert_equal 'super_password',   settings[:password]
      assert_equal 'smtp.mailtrap.io', settings[:domain]
    end
  end
end
