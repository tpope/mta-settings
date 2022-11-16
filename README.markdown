# MTA Settings for Ruby

The `mta-settings` gem enables transparent MTA (mail transport agent)
configuration from the environment for both [ActionMailer][] and [Mail][],
based on either an explicit `MTA_URL` variable or popular conventions for
Sendgrid, Mandrill, Postmark, and Mailgun (as provided by Heroku addons, for
example).

[ActionMailer]: https://github.com/rails/rails/tree/master/actionmailer
[Mail]: https://github.com/mikel/mail

## Installation

Add this line to your application's Gemfile:

    gem 'mta-settings'

### ActionMailer

If `mta-settings` is required (which Bundler does automatically by default),
ActionMailer configuration is fully automatic.  With Rails, be aware that
`config.action_mailer` assignments will take precedence, so you might want to
strip those out of your apps `config/environments/` files.

### Mail

    Mail.defaults do
      delivery_method *MtaSettings.from_env
      # delivery_method *MtaSettings.from_url(ENV['MTA_URL'])
    end

## Usage

Configuration will happen based on the presence of the following environment
variables, in order of decreasing precedence:

* `MTA_PROVIDER`: points to another environment variable containing an MTA URL
* `MTA_URL`: See below
* `SENDGRID_USERNAME`: Sendgrid
* `MANDRILL_APIKEY`: Mandrill
* `POSTMARK_API_TOKEN`: Postmark
* `MAILGUN_SMTP_LOGIN`: Mailgun
* `MAILTRAP_API_TOKEN`: Mailtrap (for development).
  Also set `MAILTRAP_INBOX_ID` when using an account with multiple inboxes.

If no supported environment variable is found, the configuration is left
blank.  This enables easy defaulting:

    ActionMailer::Base.delivery_method ||= :letter_opener

### MTA URLs

The scheme of an MTA URL is used to set the delivery method.  The user,
password, host, port, and path portions are used to populate the `user_name`,
`address`, `port`, and `location` settings of the chosen delivery method.
Query parameters are then merged in.

* The `sendmail` and `file` adapters both respect the ActionMailer `location`
  defaults, so you can just give `sendmail:///` or `file:///`.
* If a path is given in an `smtp` URL, it will be used as `domain` rather than
  `location` (minus the leading slash).
* If `domain` is set, the default from address will be set to `noreply` at
  that domain.

Here's an example for Gmail:

    smtp://username%40gmail.com:password@smtp.gmail.com:587/

Using an MTA URL is highly recommended even when your SMTP provider is
supported out of the box.  MTA URLs are much easier to copy between
environments or try out locally for debugging.
