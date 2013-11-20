
class IndexStatementExtractor
  def extract(filepath)
    table_indices = extract_statements(filepath)
    puts
    puts 'DROP statements:'
    puts
    indices_to_drops(table_indices).each do |stmt|
      puts stmt
    end
    puts
    puts 'CREATE statements:'
    puts
    indices_to_creates(table_indices).each do |stmt|
      puts stmt
    end
  end

  private
  def indices_to_drops(table_indices)
    statements = []
    table_indices.each do |table, data|
      data.each do |t|
        t =~ /.*KEY\s+\`(\S+)\`.*/
        index = $1
        statements << "DROP INDEX `#{index}` ON #{table};"
      end
    end
    statements
  end
  def indices_to_creates(table_indices)
    statements = []
    table_indices.each do |table, data|
      statements << '' << "ALTER TABLE #{table}" if data.count > 0
      data.each do |t|
        t =~ /\s*(([A-Z][A-Z\ ])*\ KEY)\s+\`(\S+)\`\s+\((.*)\)/
        statements << "ADD #{$1} \`#{$3}\` (#{$4}),".gsub('KEY', 'INDEX').gsub(/\s+/, ' ')
      end
      statements[-1][-1] = ';' if data.count > 0
    end
    statements
  end
  def extract_statements(filepath)
    table_datas = {}
    current_table = nil
    File.open(filepath, 'r').each_line do |line|
      if line =~ /CREATE TABLE `(.*)` \(/
        current_table = $1
      elsif line =~ /\) ENGINE=/
        current_table = nil
      else
        if current_table
          table_datas[current_table] ||= []
          table_datas[current_table] << line if line.include?('KEY') && !line.include?('PRIMARY')
        end
      end
    end
    table_datas
  end
end

if __FILE__ == $0
  extractor = IndexStatementExtractor.new
  extractor.extract(ARGV[0])
end
