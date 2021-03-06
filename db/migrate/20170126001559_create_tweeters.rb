class CreateTweeters < ActiveRecord::Migration[5.0]
  def change
    create_table :tweeters do |t|
      t.string :username, null: false, blank: false
      t.belongs_to :company, index: true, null: false, blank: false

      t.timestamps

      t.index :username, unique: true
    end
  end
end
