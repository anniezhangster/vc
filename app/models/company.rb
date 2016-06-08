class Company < ActiveRecord::Base
  include Concerns::Cacheable

  has_many :votes

  validates :name, presence: true
  validates :trello_id, presence: true, uniqueness: true

  scope :pitch, -> { where('pitch_on IS NOT NULL') }

  def deadline
    super || pitch_on + 2.days if pitch_on.present?
  end

  def pitched?
    pitch_on.present? && pitch_on < Time.now
  end

  def past_deadline?
    pitched? && deadline < Time.now
  end

  def quorum?
    cached { pitch_on.present? && votes.valid(pitch_on).count >= User.quorum(pitch_on) }
  end

  def funded?
    cached { quorum? && votes.yes.count > votes.no.count }
  end

  def stats
    cached do
      {
        yes_votes: votes.yes.count,
        no_votes: votes.no.count,
        averages: Vote.metrics(votes)
      }
    end
  end

  def notify_team!
    VoteMailer.email_and_slack!(:funding_decision_email, nil, self)
  end

  def warn_team!(missing_users, time_remaining)
    VoteMailer.email_and_slack!(:vote_warning_team_email, nil, missing_users, self, time_remaining.to_i)
  end

  def self.sync!(disable_notifications: false)
    Importers::Trello.new.sync! do |card_data|
      company = Company.where(trello_id: card_data[:trello_id]).first_or_create
      company.assign_attributes card_data
      company.decision_at ||= Time.now if disable_notifications && company.pitch_on == nil
      company.save! if company.changed?
    end
  end
end
