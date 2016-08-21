module Http::Crunchbase
  class Organization
    include HTTParty
    base_uri 'https://api.crunchbase.com/v/3/organizations'
    format :json
    headers 'Content-Type': 'application/json'
    default_params user_key: ENV['CB_API_KEY']

    def initialize(company)
      @company = company
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

    def self.api_get(path, query = {}, multi = true)
      data = get(path, query: query).parsed_response['data']
      multi ? data['items'] : data
    end

    def get_in(*path, multi: false)
      return nil unless found?
      current = search
      current = current[path.shift] while path.present?
      multi ? current['items'] : current
    rescue JSON::ParserError # when we hit rate limiting
      multi ? [] : nil
    end

    def found?
      search.present?
    end

    def search
      @search ||= begin
        data = fetch_data
        if @company.crunchbase_id.present?
          data
        elsif data.present?
          self.class.api_get("/#{data['properties']['permalink']}", {}, false)
        end
      end
    end

    def fetch_data
      if @company.crunchbase_id.present?
        return self.class.api_get("/#{@company.crunchbase_id}", {}, false)
      end
      data = self.class.api_get("/", domain_name: @company.domain).first
      return data if data.present?
      by_name = self.class.api_get("/", name: @company.name)
      by_name.find do |company_data|
        investors = self.class.api_get("/#{company_data['properties']['permalink']}/investors")
        investors&.find { |inv| inv['properties']['name'] == 'Dorm Room Fund' }.present?
      end
    end
  end
end