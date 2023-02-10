module RestrictedAccess
  class << self
    attr_reader :allowed_ips

    def allow?(request)
      request.local? || allowed_ips.include?(request.ip)
    end

    def allow_ip(ip)
      (@allowed_ips ||= []) << ip
    end
  end

  class RouteConstraint
    def matches?(request)
      RestrictedAccess.allow?(request)
    end
  end
end
