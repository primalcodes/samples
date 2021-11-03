require 'resolv'

module Services

  # ValidBotService Determines if incoming bot request is valid.
  # Values passed to api application from front end in pre-defined header in the following format:
  # "SuperBot|127.0.0.1"
  # Intention is to give full payload access to:
  # * SuperBot: Web content scraping service
  # * Googlebot: Google (SEO purposes) googlebot.com or google.com
  class ValidBotService
    VALID_BOT_NAMES = %w[SuperBot Googlebot].freeze
    VALID_BOT_DOMAINS = %w[superbot.com googlebot.com google.com].freeze

    def initialize(scraper_header)
      scraper = scraper_header.to_s.split('|')
      @scraper_name = scraper[0]
      @scraper_ip = scraper[1]
    end

    def call
      valid_bot?
    rescue StandardError => e
      Honeybadger.notify(error_class: 'ValidBotService', error_message: e.message)
      false
    end

    private

    attr_reader :scraper_name, :scraper_ip

    def valid_bot?
      return false if scraper_name.blank? || scraper_ip.blank?

      return false unless VALID_BOT_NAMES.include?(scraper_name)

      known_ip_cached = Rails.cache.read("VALID_BOT_#{scraper_ip}")
      return true if known_ip_cached

      valid_bot_domain?
    end

    def valid_bot_domain?
      resolves_to = Resolv.getname(scraper_ip).to_s.split('.')
      return false unless resolves_to.length >= 2

      bot_domain = resolves_to[-2..-1].join('.')
      if VALID_BOT_DOMAINS.include?(bot_domain)
        Rails.cache.write("VALID_BOT_#{scraper_ip}", bot_domain)
        return true
      end

      false
    end
  end
end
