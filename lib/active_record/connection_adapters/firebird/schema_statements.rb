module ActiveRecord::ConnectionAdapters::Firebird::SchemaStatements

  def tables(_name = nil)
    @connection.table_names
  end

  def views
    @connection.view_names
  end

private

  def column_definitions(table_name)
    @connection.columns(table_name)
  end

  def new_column_from_field(table_name, field)
    type_metadata = fetch_type_metadata(field["sql_type"], field)
    ActiveRecord::ConnectionAdapters::Firebird::FbColumn.new(field["name"], field["default"], type_metadata, field["nullable"], table_name, nil, nil, nil, field)
  end

  def fetch_type_metadata(sql_type, extra = "")
    if extra['domain'] == ActiveRecord::ConnectionAdapters::FirebirdAdapter.boolean_domain[:name]
      cast_type = lookup_cast_type("boolean")
    else
      cast_type = lookup_cast_type(sql_type)
    end
    ActiveRecord::ConnectionAdapters::Firebird::SqlTypeMetadata.new(sql_type: sql_type, precision: extra[:precision], scale: extra[:scale], limit: extra[:length], field: extra)
  end

end
