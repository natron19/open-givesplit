class CreateParts < ActiveRecord::Migration[8.1]
  def change
    create_table :parts, id: :uuid do |t|
      t.references :parts_plan, type: :uuid, null: false, foreign_key: true
      t.integer :position,       null: false
      t.string  :kind,           null: false
      t.string  :name,           null: false
      t.decimal :amount,         precision: 12, scale: 2
      t.boolean :price_is_guess, null: false, default: false
      t.decimal :quantity,       precision: 10, scale: 2
      t.string  :unit
      t.text    :why_it_matters

      t.timestamps null: false
    end
    add_index :parts, %i[parts_plan_id position], unique: true
  end
end
