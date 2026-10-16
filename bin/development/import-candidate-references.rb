require 'json'
$stdout.sync = true
c = ActiveRecord::Base.connection
abort 'Candidate database only' unless Rails.env.development? && c.current_database == 'inaturalist_survey_candidate_20261014'
abort 'Candidate indexes only' unless ENV['INAT_ES_INDEX_PREFIX'] == 'survey_candidate_20261014'
abort 'Taxonomy must be complete' unless Taxon.count == 1668467
p = Rails.root.parent.join('resources/inaturalist/2026-10-14')
[ControlledTerm, Place].each do |model|
  model.__elasticsearch__.create_index! unless model.__elasticsearch__.index_exists?
end
json = JSON.parse(File.read(p.join('controlled-terms.json')))
terms = {}
links = []
json.fetch('results').each do |attr|
  terms[attr.fetch('id')] = attr
  attr.fetch('values').each do |value|
    terms[value.fetch('id')] = value.merge('is_value' => true)
    links << [attr.fetch('id'),value.fetch('id')]
  end
end
ControlledTerm.transaction do
  terms.each do |id,data|
    term = ControlledTerm.find_or_initialize_by(id: id)
    raise 'UUID conflict' if term.persisted? && term.uuid != data.fetch('uuid')
    term.assign_attributes(data.slice('uuid','ontology_uri','uri','is_value','multivalued','blocking').merge('active'=>true))
    term.labels.build(label: data.fetch('label'), locale: 'en') if term.labels.empty?
    term.save!
    {'taxon_ids'=>false, 'excepted_taxon_ids'=>true}.each do |key,exception|
      (data[key] || []).each do |taxon_id|
        Taxon.find(taxon_id) # exact production ID; never substitute a name match
        term.controlled_term_taxa.find_or_create_by!(taxon_id: taxon_id, exception: exception)
      end
    end
  end
  links.each do |attr,value|
    ControlledTermValue.find_or_create_by!(controlled_attribute_id: attr, controlled_value_id: value)
  end
  c.execute("SELECT setval('controlled_terms_id_seq', (SELECT max(id) FROM controlled_terms), true)")
end
raise 'Term count mismatch' unless ControlledTerm.count == terms.size
raise 'Term link count mismatch' unless ControlledTermValue.count == links.uniq.size
puts "Imported #{terms.size} terms with #{links.uniq.size} attribute/value links"
# Use upstream shape conversion, normal model validation, geometry callbacks and checklists.
# Unlike the upstream batch wrapper, fail on any invalid record rather than skipping it.
source = Source.find_or_create_by!(title: 'Natural Earth Admin 0 - Countries') do |s|
  s.in_text = 'Natural Earth'
  s.citation = 'Natural Earth Admin 0 - Countries, 1:50m; downloaded October 14, 2026.'
  s.url = 'https://www.naturalearthdata.com/downloads/50m-cultural-vectors/50m-admin-0-countries-2/'
end
shapefile = p.join('initialization/countries/ne_50m_admin_0_countries.shp')
count = 0
Place.transaction do
  RGeo::Shapefile::Reader.open(shapefile.to_s) do |reader|
    reader.each do |shape|
      name = shape.attributes['NAME']
      place = Place.find_by(source_id: source.id, source_name: name)
      unless place
        place = Place.new_from_shape(shape, name_column: 'NAME',
          place_type: Place::PLACE_TYPE_CODES['Country'], admin_level: Place::COUNTRY_LEVEL,
          source: source)
        place.source_filename = shapefile.basename.to_s
        place.source_name = name
        # Full candidate search indexing is a separate step. Avoid index callbacks
        # that ask the not-yet-running candidate API for observation counts.
        place.skip_indexing = true
        place.save!
        geometry = place.place_geometry
        geometry.source = source
        geometry.source_filename = shapefile.basename.to_s
        geometry.source_name = name
        geometry.save!
      end
      raise 'Missing geometry or checklist' unless place.place_geometry && place.check_list
      count += 1
      puts "Country #{count}: #{name}" if count % 25 == 0
    end
  end
end
raise 'Country count mismatch' unless Place.where(source_id: source.id).count == count
raise 'Invalid geometries' unless c.select_value('SELECT count(*) FROM place_geometries WHERE NOT ST_IsValid(geom) OR ST_IsEmpty(geom) OR ST_SRID(geom) <> 0 OR ST_XMin(geom) < -180 OR ST_XMax(geom) > 180 OR ST_YMin(geom) < -90 OR ST_YMax(geom) > 90').to_i.zero?
puts "Imported #{count} country places with validated geometry and checklists"
