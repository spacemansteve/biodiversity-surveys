require 'json'
c=ActiveRecord::Base.connection
abort 'Candidate only' unless c.current_database == 'inaturalist_survey_candidate_20261014' && ENV['INAT_ES_INDEX_PREFIX']=='survey_candidate_20261014'
checks={}
checks[:source_mismatches]=c.select_value(<<~SQL).to_i
 SELECT count(*) FROM survey_taxa_import s FULL JOIN taxa t ON t.id=s.id
 WHERE s.id IS NULL OR t.id IS NULL OR
 (s.ancestry,s.rank_level,s.rank,s.name,s.is_active,s.is_iconic,s.iconic_taxon_id)
 IS DISTINCT FROM
 (t.ancestry,t.rank_level,t.rank,t.name,t.is_active,t.is_iconic,t.iconic_taxon_id)
SQL
checks[:missing_scientific_names]=c.select_value(<<~SQL).to_i
 SELECT count(*) FROM taxa t WHERE NOT EXISTS (
 SELECT 1 FROM taxon_names n WHERE n.taxon_id=t.id AND n.name=t.name
 AND n.lexicon='Scientific Names' AND n.parameterized_lexicon='scientific-names' AND n.is_valid)
SQL
checks[:orphan_names]=c.select_value('SELECT count(*) FROM taxon_names n LEFT JOIN taxa t ON n.taxon_id=t.id WHERE t.id IS NULL').to_i
checks[:orphan_term_restrictions]=c.select_value('SELECT count(*) FROM controlled_term_taxa r LEFT JOIN taxa t ON r.taxon_id=t.id LEFT JOIN controlled_terms ct ON r.controlled_term_id=ct.id WHERE t.id IS NULL OR ct.id IS NULL').to_i
checks[:invalid_geometries]=c.select_value('SELECT count(*) FROM place_geometries WHERE geom IS NULL OR NOT ST_IsValid(geom) OR ST_IsEmpty(geom) OR ST_SRID(geom) <> 0 OR ST_XMin(geom) < -180 OR ST_XMax(geom) > 180 OR ST_YMin(geom) < -90 OR ST_YMax(geom) > 90').to_i
checks[:places_missing_geometry_or_checklist]=c.select_value('SELECT count(*) FROM places p LEFT JOIN place_geometries g ON g.place_id=p.id LEFT JOIN lists l ON l.id=p.check_list_id WHERE g.id IS NULL OR l.id IS NULL').to_i
raise checks.inspect unless checks.values.all?(&:zero?)
reference = JSON.parse(File.read(Rails.root.parent.join('resources/inaturalist/2026-10-14/controlled-terms.json')))
reference.fetch('results').each do |attribute|
  ([attribute] + attribute.fetch('values')).each do |data|
    term = ControlledTerm.find(data.fetch('id'))
    raise 'Term UUID or label mismatch' unless term.uuid == data.fetch('uuid') && term.labels.exists?(label: data.fetch('label'), locale: 'en')
    {'taxon_ids'=>false, 'excepted_taxon_ids'=>true}.each do |key, exception|
      raise 'Term restrictions differ' unless term.controlled_term_taxa.where(exception: exception).pluck(:taxon_id).sort == (data[key] || []).sort
    end
  end
  raise 'Term value links differ' unless ControlledTerm.find(attribute.fetch('id')).values.pluck(:id).sort == attribute.fetch('values').map { |v| v.fetch('id') }.sort
end
%w[taxa taxon_names controlled_terms].each do |table|
 raise "Sequence below max for #{table}" unless c.select_value("SELECT last_value FROM #{table}_id_seq").to_i >= c.select_value("SELECT max(id) FROM #{table}").to_i
end
raise 'Life identity' unless Taxon.find(48460).name=='Life'
raise 'Animalia identity' unless Taxon.find(1).name=='Animalia'
[1,3,47126,47158].each do |id|
 t=Taxon.find(id)
 raise "Invalid model #{id}: #{t.errors.full_messages}" unless t.valid?
 raise 'Name mismatch' unless t.scientific_name.name==t.name
 raise 'Ancestry lookup mismatch' unless t.ancestors.pluck(:id).sort==t.ancestry.split('/').map(&:to_i).sort
end
counts={}
%w[taxa taxon_names controlled_terms controlled_term_values controlled_term_labels controlled_term_taxa places place_geometries sources users observations delayed_jobs].each do |table|
 counts[table]=c.select_value("SELECT count(*) FROM #{table}").to_i
end
report={database:c.current_database,es_prefix:ENV['INAT_ES_INDEX_PREFIX'],counts:counts,checks:checks,
active_taxa:Taxon.where(is_active:true).count,inactive_taxa:Taxon.where(is_active:false).count,
iconic_taxa:Taxon.where(is_iconic:true).count,
full_search_index_built:false,application_switched:false}
File.write(Rails.root.parent.join('resources/inaturalist/2026-10-14/initialization/result.json'),JSON.pretty_generate(report)+"\n")
puts JSON.pretty_generate(report)
