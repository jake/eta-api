class CreateDirections < ActiveRecord::Migration
  def change
    create_table :directions do |t|
      t.string :token
      t.string :travel_mode
      t.string :origin
      t.string :destination

      t.timestamps
    end

    add_index :directions, :token, unique: true
  end
end
