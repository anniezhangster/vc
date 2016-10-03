module Http::Crunchbase
  class Organization
    extend Concerns::Cacheable

    INVALID_KEY = '_invalid_magic_cb_org_key'

    include HTTParty
    base_uri 'https://api.crunchbase.com/v/3/organizations'
    format :json
    headers 'Content-Type': 'application/json'
    default_params user_key: ENV['CB_API_KEY']

    def initialize(company, timeout = nil)
      @company = company
      @timeout = timeout
    end

    def permalink
      get_in 'properties', 'permalink'
    end

    def description
      get_in 'properties', 'short_description'
    end

    def url
      get_in 'properties', 'homepage_url'
    end

    def investors
      get_in 'relationships', 'investors', multi: true
    end

    def has_investor?(name)
      investors&.find { |inv| inv['properties']['name'] == name }.present?
    end

    def total_funding
      get_in 'properties', 'total_funding_usd'
    end

    private

    def self.api_get(raw_path, query = {}, multi = true)
      path = URI.encode raw_path
      data = key_cached(query.merge(path: path)) do
        get(path, query: query).parsed_response['data']
      end
      multi ? data && data['items'] : data
    end

    def self.base_cache_key
      "http/crunchbase/organizations"
    end

    def get_in_raw(path, multi)
      return nil unless found?
      current = search
      current = current[path.shift] while path.present?
      multi ? current['items'] : current
    end

    def get_in(*path, multi: false)
      if @timeout.present?
        Timeout::timeout(@timeout) { get_in_raw(path, multi) }
      else
        get_in_raw(path, multi)
      end
    rescue Timeout::Error, JSON::ParserError # when we hit rate limiting
      multi ? [] : nil
    end

    def found?
      search.present?
    end

    def search
      @search ||= begin
        data = fetch_data
        if @company.crunchbase_id.present? && @company.crunchbase_id != INVALID_KEY
          data
        elsif data.present?
          self.class.api_get("/#{data['properties']['permalink']}", {}, false)
        end
      end
    end

    def fetch_from_name
      by_name = self.class.api_get("/", name: @company.name)
      if (
        by_name.size == 1 &&
        by_name.first['properties']['primary_role'] == 'company' &&
        Levenshtein.distance(by_name.first['properties']['name'].downcase, @company.name.downcase) <= 3
      )
        return by_name.first
      end

      if by_name.size <= 3
        parameterized_name = @company.name.gsub(' ', '').parameterize
        from_name = self.class.api_get("/#{parameterized_name}", {}, false)
        from_name_check = self.class.api_get("/#{parameterized_name}-2", {}, false)
        return from_name if from_name.present? && from_name_check.blank?
      end

      by_name.find do |company_data|
        investors = self.class.api_get("/#{company_data['properties']['permalink']}/investors")
        investors&.find { |inv| inv['properties']['name'] == 'Dorm Room Fund' }.present?
      end
    end

    def fetch_data
      if @company.crunchbase_id.present? && @company.crunchbase_id != INVALID_KEY
        return self.class.api_get("/#{@company.crunchbase_id}", {}, false)
      end
      if @company.domain.present?
        data = self.class.api_get("/", domain_name: @company.domain).first
        return data if data.present?
      end
      fetch_from_name
    end
  end
end
