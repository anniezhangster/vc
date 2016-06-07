module Importers
  class Trello
    SEPARATOR = '-'

    def sync!
      ::Trello::Board.find(ENV['TRELLO_BOARD']).cards.each do |card|
        yield parse(card)
      end
    end

    private

    class DateTimeNotFound < StandardError
      def log!(card)
        usernames = card.members.map { |mem| mem.email.split('@').first }
        LoggedError.log! :datetime_not_found, card, usernames, card.list.name, card.name, card.url
      end
    end

    def parse(card)
      parsed = { trello_id: card.id, name: card.name }
      begin
        parsed.merge! parse_pitch_on(card) if card.list_id == ENV['TRELLO_LIST']
      rescue DateTimeNotFound => dtnf
        dtnf.log! card
      end
      parsed
    end

    def parse_pitch_on(card)
      name, datestring = split_name card
      index = datestring.index /\d/
      raise DateTimeNotFound, name unless index.present?
      date = Chronic.parse(datestring[index..-1])
      raise DateTimeNotFound, name unless date.present?
      { pitch_on: date, name: name }
    end

    def split_name(card)
      raise DateTimeNotFound, card.name unless card.name.include?(SEPARATOR)
      *nameparts, datestring = card.name.split(SEPARATOR)
      name = nameparts.join(SEPARATOR).strip
      [name, datestring]
    end
  end
end