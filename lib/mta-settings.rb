require 'mta_settings'

ActiveSupport.on_load(:action_mailer) do
  self.mta_settings =
    if ENV['RAILS_ENV'] == 'test'
      :test
    else
      ENV
    end
end
