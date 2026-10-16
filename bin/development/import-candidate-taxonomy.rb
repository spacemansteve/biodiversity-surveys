# Run through Rails runner with DATABASE_URL and INAT_ES_INDEX_PREFIX set to the candidate.
require 'json'
root = Rails.root.parent
input = root.join('resources/inaturalist/2026-10-14/initialization')
c = ActiveRecord::Base.connection
abort 'Candidate database only' unless Rails.env.development? && c.current_database == 'inaturalist_survey_candidate_20261014'
abort 'Candidate indexes only' unless ENV['INAT_ES_INDEX_PREFIX'] == 'survey_candidate_20261014'
abort 'Target must be empty' unless Taxon.count.zero? && TaxonName.count.zero?
Taxon.__elasticsearch__.create_index! unless Taxon.__elasticsearch__.index_exists?
load Rails.root.join('tools/load_sources.rb')
source = Source.find_by!(title: 'iNaturalist')
# Exercise actual validations and callbacks for a complete ancestor chain, then roll back.
model_results = []
Taxon.transaction do
  File.foreach(input.join('taxa-copy.tsv')) do |line|
    fields = line.chomp.split("\t")
    next unless [48460,1,2,355675,3].include?(fields[0].to_i)
    model_results << fields
  end
  model_results.sort_by! { |f| f[1] == '\N' ? 0 : f[1].split('/').size }
  model_results.each do |f|
    t = Taxon.create!(id: f[0].to_i, ancestry: f[1] == '\N' ? nil : f[1],
      rank_level: f[2].to_f, rank: f[3], name: f[4], is_active: f[5] == 'true',
      is_iconic: f[6] == 'true', source: source)
    raise 'Scientific-name callback mismatch' unless t.scientific_name.name == t.name
    actual = t.iconic_taxon_id
    expected = f[7] == '\N' ? nil : f[7].to_i
    raise "Iconic callback mismatch for #{t.id}: #{actual} != #{expected}" unless actual == expected
  end
  raise ActiveRecord::Rollback
end
puts "Model/callback probe passed for #{model_results.size} taxa"
# Restore authoritative exported records into an empty database. This does not
# alter model validators. It retains historical source rows that today's create
# validators would reject; missing curation metadata is not fabricated.
Taxon.transaction do
  c.execute <<~SQL
    CREATE TABLE public.survey_taxa_import (
      id integer PRIMARY KEY, ancestry varchar(255), rank_level double precision,
      rank varchar(255) NOT NULL, name varchar(255) NOT NULL,
      is_active boolean NOT NULL, is_iconic boolean NOT NULL, iconic_taxon_id integer
    )
  SQL
  c.raw_connection.copy_data('COPY survey_taxa_import FROM STDIN') do
    File.open(input.join('taxa-copy.tsv'), 'rb') do |f|
      while (chunk = f.read(1024*1024))
        c.raw_connection.put_copy_data(chunk)
      end
    end
  end
  raise 'Unexpected source count' unless c.select_value('SELECT count(*) FROM survey_taxa_import').to_i == 1668467
  c.execute <<~SQL
    INSERT INTO taxa (id, ancestry, rank_level, rank, name, is_active, is_iconic,
                      iconic_taxon_id, source_id, created_at, updated_at)
    SELECT id, ancestry, rank_level, rank, name, is_active, is_iconic,
           iconic_taxon_id, #{source.id}, now(), now() FROM survey_taxa_import;
    INSERT INTO taxon_names (taxon_id, name, is_valid, lexicon, parameterized_lexicon,
                            source_id, position, created_at, updated_at)
    SELECT id, name, true, 'Scientific Names', 'scientific-names',
           source_id, 0, created_at, updated_at FROM taxa;
    SELECT setval('taxa_id_seq', (SELECT max(id) FROM taxa), true);
    SELECT setval('taxon_names_id_seq', (SELECT max(id) FROM taxon_names), true);
  SQL
  mismatch = c.select_value(<<~SQL).to_i
    SELECT count(*) FROM survey_taxa_import s FULL JOIN taxa t ON t.id=s.id
    WHERE s.id IS NULL OR t.id IS NULL OR
    (s.ancestry,s.rank_level,s.rank,s.name,s.is_active,s.is_iconic,s.iconic_taxon_id)
    IS DISTINCT FROM
    (t.ancestry,t.rank_level,t.rank,t.name,t.is_active,t.is_iconic,t.iconic_taxon_id)
  SQL
  raise 'Import differs from source' unless mismatch.zero?
  raise 'Missing scientific names' unless TaxonName.count == Taxon.count
end
c.execute('ANALYZE taxa; ANALYZE taxon_names;')
puts "Imported #{Taxon.count} taxa and #{TaxonName.count} scientific names"
