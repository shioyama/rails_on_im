# frozen_string_literal: true

Rails.configuration.to_prepare do
  RestrictedAccess.allow_ip("123.456.789.012")
end
