require 'uri'
require 'cgi'
require 'net/http'
require 'json'
require 'active_support/core_ext/object/blank'
require 'active_support/lazy_load_hooks'

module MtaSettings
  LOCALHOST = 'localhost.localdomain'

  def self.from_url(url)
    return if url.blank?
    # Use MTA_URL=: to short circuit configuration
    return [nil, nil] if url == ':'
    # Use MTA_URL=test: to use the test method without changing settings
    return [$1.tr('+-.', '___').to_sym, nil] if url =~ /\A^([\w+-.]+):\z/
    uri = URI.parse(url.to_s)

    settings = {
      :user_name => (CGI.unescape(uri.user) if uri.user),
      :password => (CGI.unescape(uri.password) if uri.password),
      :address => uri.host,
      :port => uri.port,
      :location => (uri.path if uri.path != '/'),
    }.reject do |k, v|
      v.nil?
    end

    if !settings[:location] && uri.opaque =~ /^[^?]/
      settings[:location] = CGI.unescape(uri.opaque.split('?').first)
    end

    CGI.parse(uri.query || uri.opaque.to_s.split('?')[1].to_s).each do |k, v|
      settings[k.to_sym] = v.join("\n")[/.+/m]
    end

    adapter = uri.scheme.downcase.tr('+-.', '___').to_sym
    case adapter
    when :sendmail, :exim
      settings[:location] ||= "/usr/sbin/#{adapter}"
      settings[:arguments] ||= '-i -t'

    when :file
      settings[:location] ||=
        if defined?(Rails.root)
          "#{Rails.root}/tmp/mails"
        else
          "#{Dir.tmpdir}/mails"
        end

    when :smtp, :smtps
      settings[:ssl] = (adapter == :smtps)
      adapter = :smtp
      settings[:enable_starttls_auto] = true
      settings[:authentication] ||= :plain if settings[:user_name]
      settings[:domain] ||=
        (settings.delete(:location) || LOCALHOST).sub(/^\//, '')

    end

    [adapter, settings]
  end

  def self.from_env(env = ENV)
    domain = env['MTA_DOMAIN'] || LOCALHOST
    if url = env[env['MTA_PROVIDER'].presence || 'MTA_URL'].presence
      method, settings = from_url(url)
      if method == :smtp && settings[:domain] == LOCALHOST
        settings[:domain] = domain
      end
      [method, settings]
    elsif env['SENDGRID_USERNAME'].present?
      [:smtp, {
        :address              => "smtp.sendgrid.net",
        :port                 => 587,
        :authentication       => :plain,
        :enable_starttls_auto => true,
        :user_name            => env['SENDGRID_USERNAME'],
        :password             => env['SENDGRID_PASSWORD'],
        :domain               => domain,
      }]
    elsif env['MANDRILL_APIKEY'].present?
      [:smtp, {
        :address              => "smtp.mandrillapp.com",
        :port                 => 587,
        :authentication       => :plain,
        :enable_starttls_auto => true,
        :user_name            => env['MANDRILL_USERNAME'],
        :password             => env['MANDRILL_APIKEY'],
        :domain               => domain,
      }]
    elsif env['POSTMARK_API_TOKEN'].present?
      [:smtp, {
        :address              => env['POSTMARK_SMTP_SERVER'] || 'smtp.postmarkapp.com',
        :port                 => 25,
        :authentication       => :cram_md5,
        :enable_starttls_auto => true,
        :user_name            => env['POSTMARK_API_TOKEN'],
        :password             => env['POSTMARK_API_TOKEN'],
        :domain               => domain,
      }]
    elsif env['MAILGUN_SMTP_LOGIN'].present?
      [:smtp, {
        :address              => env['MAILGUN_SMTP_SERVER'] || 'smtp.mailgun.org',
        :port                 => env['MAILGUN_SMTP_PORT'] || '25',
        :authentication       => :plain,
        :enable_starttls_auto => true,
        :user_name            => env['MAILGUN_SMTP_LOGIN'],
        :password             => env['MAILGUN_SMTP_PASSWORD'],
        :domain               => domain,
      }]
    elsif env['MAILTRAP_API_TOKEN'].present?
      response = Net::HTTP.get(URI.parse("https://mailtrap.io/api/v1/inboxes.json?api_token=#{env['MAILTRAP_API_TOKEN']}"))
      inboxes = JSON.parse(response)
      inbox = inboxes.detect { |i| i['id'] == env['MAILTRAP_INBOX_ID'].to_i } || inboxes.first
      [:smtp, {
        :address              => inbox['domain'],
        :port                 => inbox['smtp_ports'].last,
        :authentication       => :cram_md5,
        :user_name            => inbox['username'],
        :password             => inbox['password'],
        :domain               => inbox['domain'],
        :enable_starttls_auto => true
      }]
    end
  end

  module ActionMailerExtensions
    def mta_settings
      [delivery_method, send("#{delivery_method}_settings")] if delivery_method
    end

    def mta_settings=(arg)
      self.delivery_method, settings =
        *case arg
        when nil, ""
          [nil, nil]
        when String, URI
          MtaSettings.from_url(arg)
        when Array
          arg
        when Symbol
          [arg, {}]
        when Hash
          arg = arg.dup
          [arg.delete(:adapter) || arg.delete(:transport), arg]
        when ENV
          MtaSettings.from_env(arg)
        else
          raise ArgumentError, "Unsupported MTA settings #{arg.inspect}"
        end
      return unless delivery_method && settings
      accessor = :"#{delivery_method}_settings"
      class_attribute(accessor) unless respond_to?(accessor)
      send(:"#{accessor}=", settings)
      if settings[:from]
        default :from => settings[:from]
      elsif !default.has_key?(:from) &&
          ![nil, LOCALHOST].include?(settings[:domain])
        default :from => "noreply@#{settings[:domain]}"
      elsif !default.has_key?(:from) &&
          settings[:user_name] =~ /\A\S+@\S+\.\w+\z/
        default :from => settings[:user_name]
      end
    end
  end
end

ActiveSupport.on_load(:action_mailer) do
  extend MtaSettings::ActionMailerExtensions
end
