class CreateNeeds < ActiveRecord::Migration[8.1]
  def change
    create_table :needs, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.text   :need_text,         null: false
      t.string :kinds,             null: false, array: true, default: []
      t.string :currency,          null: false, default: "USD"
      t.text   :community_context
      t.string :rough_budget

      t.timestamps null: false
    end
  end
end
