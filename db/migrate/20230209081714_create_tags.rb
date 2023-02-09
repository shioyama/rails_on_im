class CreateTags < ActiveRecord::Migration[7.0]
  def change
    create_table :tags do |t|
      t.string :name
      t.references :taggable, polymorphic: true, null: false

      t.timestamps
    end
  end
end
