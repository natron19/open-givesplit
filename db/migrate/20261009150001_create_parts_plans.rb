class CreatePartsPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :parts_plans, id: :uuid do |t|
      t.references :need, type: :uuid, null: false, foreign_key: true
      t.string   :status, null: false, default: "pending"
      t.text     :gemini_raw
      t.string   :failure_reason
      t.datetime :generated_at

      t.string :project_name
      t.text   :description
      t.jsonb  :questions_for_owner, null: false, default: []

      t.timestamps null: false
    end
    add_index :parts_plans, :status
  end
end
