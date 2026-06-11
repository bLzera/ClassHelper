class AddAlternateLinkToAssignments < ActiveRecord::Migration[7.2]
  def change
    add_column :assignments, :alternate_link, :string, limit: 1024
  end
end
