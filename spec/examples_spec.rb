describe "Examples" do
  ROOT_DIR = "#{File.dirname(__FILE__)}/.."
  it "generates correct indices for photo sharing schema" do
    expected_output = File.open("#{ROOT_DIR}/example/schema_output.txt", "rb").read
    output = `ruby #{ROOT_DIR}/generate_index_statements.rb #{ROOT_DIR}/example/schema.sql`
    expect(output).to eql(expected_output)
  end
end