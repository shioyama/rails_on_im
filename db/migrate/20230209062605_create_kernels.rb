class CreateKernels < ActiveRecord::Migration[7.0]
  def change
    create_table :kernels do |t|
      t.string :foo

      t.timestamps
    end
  end
end
